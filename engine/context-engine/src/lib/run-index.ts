import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import * as lancedb from "@lancedb/lancedb";
import {
  capCodeChunks,
  collectAllSources,
  fileToChunks,
} from "./collect-sources.ts";
import { contentHash, fileKey } from "./hash.ts";
import { embedText } from "./embed.ts";
import { rebuildFts } from "./fts.ts";
import { normalizeChunkRow, serializeChunkRows } from "./lance-rows.ts";
import { ftsPath, manifestPath, memoryRoot, parseTarget, vectorPath } from "./paths.ts";
import {
  emptyManifest,
  type ChunkKind,
  type ChunkRow,
  type IndexManifest,
} from "./types.ts";

export function parseIndexArgs(argv: string[]) {
  const { profile } = parseTarget(argv);
  let kind = "all";
  let mfe: string | undefined;
  let moduleFilter: string | undefined;
  let incremental = false;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--kind" && argv[i + 1]) {
      kind = argv[++i]!;
    } else if (a === "--mfe" && argv[i + 1]) {
      mfe = argv[++i];
    } else if (a === "--module" && argv[i + 1]) {
      moduleFilter = argv[++i];
    } else if (a === "--incremental") {
      incremental = true;
    } else if (a === "--full") {
      incremental = false;
    }
  }

  const kinds = new Set<ChunkKind>();
  if (kind === "all") {
    kinds.add("memory");
    kinds.add("docs");
    kinds.add("code");
  } else {
    for (const k of kind.split(",")) {
      const t = k.trim() as ChunkKind;
      if (t === "memory" || t === "docs" || t === "code") kinds.add(t);
    }
  }

  return { profile, kinds, mfe, moduleFilter, incremental };
}

async function loadManifest(path: string): Promise<IndexManifest> {
  try {
    const raw = JSON.parse(await readFile(path, "utf8")) as IndexManifest;
    if (raw.version === 2) return raw;
  } catch {
    /* fresh */
  }
  return emptyManifest();
}

async function loadExistingRows(dbPath: string): Promise<Map<string, ChunkRow>> {
  const map = new Map<string, ChunkRow>();
  try {
    const db = await lancedb.connect(dbPath);
    const tables = await db.tableNames();
    if (!tables.includes("chunks")) return map;
    const table = await db.openTable("chunks");
    const rows = (await table.query().limit(50_000).toArray()) as Record<string, unknown>[];
    for (const row of rows) {
      map.set(String(row.id), normalizeChunkRow(row));
    }
  } catch {
    /* empty */
  }
  return map;
}

export async function runIndex(argv: string[]): Promise<void> {
  const started = performance.now();
  const { profile, kinds, mfe, moduleFilter, incremental } = parseIndexArgs(argv);

  const sources = await collectAllSources(profile, { kinds, mfe, moduleFilter });
  if (sources.length === 0) {
    throw new Error(`No sources for kinds=${[...kinds].join(",")}`);
  }

  const manifestFile = manifestPath(profile);
  const existingManifest = incremental
    ? await loadManifest(manifestFile)
    : emptyManifest();
  const existingRows = incremental
    ? await loadExistingRows(vectorPath(profile))
    : new Map<string, ChunkRow>();

  const newRows: ChunkRow[] = [];
  const newManifest: IndexManifest = incremental
    ? structuredClone(existingManifest)
    : emptyManifest();

  let embedded = 0;
  let skipped = 0;

  for (const file of sources) {
    const key = fileKey(file.repo, file.source);
    const chunks = await fileToChunks(file);
    const combined = chunks.map((c) => c.text).join("\n");
    const hash = contentHash(combined);
    const prev = newManifest.files[key];

    if (incremental && prev && prev.hash === hash && prev.mtime === file.mtime) {
      const reused: ChunkRow[] = [];
      for (const cid of prev.chunkIds) {
        const row = existingRows.get(cid);
        if (row) reused.push(row);
      }
      if (reused.length === prev.chunkIds.length) {
        newRows.push(...reused);
        skipped += 1;
        continue;
      }
    }

    const chunkIds: string[] = [];
    for (const chunk of chunks) {
      const textHash = contentHash(chunk.text);
      const row: ChunkRow = {
        id: chunk.id,
        source: chunk.source,
        text: chunk.text,
        module: chunk.module ?? file.module,
        kind: file.kind,
        repo: file.repo,
        mtime: file.mtime,
        hash: textHash,
        vector: await embedText(chunk.text),
      };
      newRows.push(row);
      chunkIds.push(chunk.id);
      embedded += 1;
    }

    newManifest.files[key] = { hash, mtime: file.mtime, chunkIds };
  }

  if (incremental) {
    const activeKeys = new Set(sources.map((s) => fileKey(s.repo, s.source)));
    for (const [key, entry] of Object.entries(existingManifest.files)) {
      if (activeKeys.has(key)) continue;
      for (const cid of entry.chunkIds) {
        const row = existingRows.get(cid);
        if (row && !newRows.some((r) => r.id === cid)) newRows.push(row);
      }
    }
  }

  const capped = capCodeChunks(newRows);
  const serializable = serializeChunkRows(capped);
  if (serializable.length === 0) {
    throw new Error(
      `No chunks to index for kinds=${[...kinds].join(",")} â€” LanceDB empty or manifest stale; run with --full`,
    );
  }
  newManifest.stats = {
    memory: serializable.filter((r) => r.kind === "memory").length,
    docs: serializable.filter((r) => r.kind === "docs").length,
    code: serializable.filter((r) => r.kind === "code").length,
  };
  newManifest.updatedAt = new Date().toISOString();

  await mkdir(join(memoryRoot(profile), "vector"), { recursive: true });
  await writeFile(manifestFile, `${JSON.stringify(newManifest, null, 2)}\n`, "utf8");

  const dbPath = vectorPath(profile);
  const db = await lancedb.connect(dbPath);
  const names = await db.tableNames();
  if (names.includes("chunks")) await db.dropTable("chunks");
  await db.createTable("chunks", serializable);

  rebuildFts(ftsPath(profile), serializable);

  const elapsed = ((performance.now() - started) / 1000).toFixed(1);
  console.log(
    `[${profile}] Indexed ${serializable.length} chunks (${embedded} embedded, ${skipped} files skipped) in ${elapsed}s â†’ ${dbPath}`,
  );
  console.log(
    `  stats: memory=${newManifest.stats.memory} docs=${newManifest.stats.docs} code=${newManifest.stats.code}`,
  );
}
