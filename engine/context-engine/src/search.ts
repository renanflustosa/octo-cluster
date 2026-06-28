import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import * as lancedb from "@lancedb/lancedb";
import { chunkMarkdown } from "./lib/chunk.ts";
import { embedText, keywordScore } from "./lib/embed.ts";
import { bm25Search } from "./lib/fts.ts";
import {
  contextDir,
  ftsPath,
  memoryRoot,
  overviewPath,
  parseTarget,
  ticketsDir,
  vectorPath,
} from "./lib/paths.ts";
import { rerank } from "./lib/rerank.ts";
import type { ChunkKind } from "./lib/types.ts";

const TOP_K = 20;
const MAX_CHUNKS = 5;

function queryFromArgv(argv: string[]): string {
  const qIdx = argv.indexOf("--query");
  if (qIdx >= 0 && argv[qIdx + 1]) return argv[qIdx + 1]!;
  const { profile } = parseTarget(argv);
  const pos = argv.indexOf(profile);
  if (pos >= 0 && argv[pos + 1] && !argv[pos + 1]!.startsWith("--")) {
    return argv.slice(pos + 1).filter((a) => !a.startsWith("--")).join(" ");
  }
  return "";
}

function parseFilters(argv: string[]) {
  let kind: ChunkKind | undefined;
  let repo: string | undefined;
  let moduleFilter: string | undefined;
  let hybrid = true;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--kind" && argv[i + 1]) kind = argv[++i] as ChunkKind;
    else if (a === "--repo" && argv[i + 1]) repo = argv[++i];
    else if (a === "--module" && argv[i + 1]) moduleFilter = argv[++i];
    else if (a === "--vector-only") hybrid = false;
    else if (a === "--hybrid") hybrid = true;
  }

  return { kind, repo, moduleFilter, hybrid };
}

async function keywordFallback(
  profile: string,
  query: string,
  moduleFilter?: string,
) {
  const root = memoryRoot(profile);
  const candidates: Array<{ source: string; text: string; score: number; kind: string; repo: string; module: string }> = [];

  async function scanFile(path: string, rel: string) {
    const text = await readFile(path, "utf8");
    for (const chunk of chunkMarkdown(rel, text)) {
      if (moduleFilter && chunk.module && !chunk.module.includes(moduleFilter)) continue;
      const score = keywordScore(query, chunk.text);
      if (score > 0) {
        candidates.push({
          source: rel,
          text: chunk.text,
          score,
          kind: "memory",
          repo: profile,
          module: chunk.module ?? "",
        });
      }
    }
  }

  try {
    await scanFile(overviewPath(profile), "overview.md");
  } catch {
    /* skip */
  }

  for (const [dir, prefix] of [
    [contextDir(profile), "context"] as const,
    [ticketsDir(profile), "tickets"] as const,
  ]) {
    try {
      const files = await readdir(dir, { recursive: true });
      for (const f of files) {
        if (typeof f !== "string" || !/\.(md|mdc|json)$/i.test(f)) continue;
        const rel = `${prefix}/${f}`.replace(/\\/g, "/");
        await scanFile(join(root, rel), rel);
      }
    } catch {
      /* skip */
    }
  }

  return candidates
    .sort((a, b) => b.score - a.score)
    .slice(0, TOP_K)
    .map((c) => ({
      source: c.source,
      text: c.text,
      kind: c.kind,
      repo: c.repo,
      module: c.module,
      _distance: 1 - c.score,
      _vectorScore: 1 - c.score,
      _bm25Score: c.score,
    }));
}

const { profile } = parseTarget(process.argv);
const query = queryFromArgv(process.argv);
const { kind, repo, moduleFilter, hybrid } = parseFilters(process.argv);

if (!query) {
  console.error('Usage: search <profile> --query "terms" [--kind memory|docs|code] [--repo] [--module] [--hybrid|--vector-only]');
  process.exit(1);
}

type Result = {
  id?: string;
  source: string;
  text: string;
  kind?: string;
  repo?: string;
  module?: string;
  _distance: number;
  _vectorScore?: number;
  _bm25Score?: number;
  _fused?: number;
};

let candidates: Result[] = [];

try {
  const db = await lancedb.connect(vectorPath(profile));
  const tables = await db.tableNames();
  if (tables.includes("chunks")) {
    const table = await db.openTable("chunks");
    const vector = await embedText(query);
    let search = table.vectorSearch(vector).limit(TOP_K);
    const filters: string[] = [];
    if (kind) filters.push(`kind = '${kind}'`);
    if (repo) filters.push(`repo = '${repo}'`);
    if (moduleFilter) filters.push(`module LIKE '%${moduleFilter}%'`);
    if (filters.length) search = search.where(filters.join(" AND "));
    const vectorHits = (await search.toArray()) as Array<Result & { id: string }>;

    const bm25Hits = hybrid
      ? bm25Search(ftsPath(profile), query, TOP_K, { kind, repo, module: moduleFilter })
      : [];

    const bm25Map = new Map(bm25Hits.map((h) => [h.chunk_id, h.bm25]));
    const bm25Vals = bm25Hits.map((h) => h.bm25);
    const bm25Min = bm25Vals.length ? Math.min(...bm25Vals) : 0;
    const bm25Max = bm25Vals.length ? Math.max(...bm25Vals) : 1;
    const bm25Span = bm25Max - bm25Min || 1;

    const byId = new Map<string, Result>();
    for (const row of vectorHits) {
      const dist = typeof row._distance === "number" ? row._distance : 1;
      const vectorScore = 1 - dist;
      const rawBm25 = row.id ? bm25Map.get(row.id) : undefined;
      const bm25Norm =
        rawBm25 !== undefined ? (rawBm25 - bm25Min) / bm25Span : 0;
      const fused = hybrid
        ? 0.7 * vectorScore + 0.3 * bm25Norm
        : vectorScore;
      byId.set(row.id ?? row.source, {
        ...row,
        _distance: dist,
        _vectorScore: vectorScore,
        _bm25Score: bm25Norm,
        _fused: fused,
      });
    }

    for (const hit of bm25Hits) {
      if (byId.has(hit.chunk_id)) continue;
      const row = vectorHits.find((r) => r.id === hit.chunk_id);
      if (row) continue;
    }

    candidates = [...byId.values()].sort(
      (a, b) => (b._fused ?? 0) - (a._fused ?? 0),
    );

    if (candidates.length < TOP_K && hybrid && bm25Hits.length) {
      const allRows = (await table.query().limit(5000).toArray()) as Array<
        Result & { id: string }
      >;
      for (const hit of bm25Hits) {
        if (byId.has(hit.chunk_id)) continue;
        const row = allRows.find((r) => r.id === hit.chunk_id);
        if (!row) continue;
        if (kind && row.kind !== kind) continue;
        if (repo && row.repo !== repo) continue;
        if (moduleFilter && row.module && !row.module.includes(moduleFilter)) continue;
        const bm25Norm = (hit.bm25 - bm25Min) / bm25Span;
        byId.set(hit.chunk_id, {
          ...row,
          _distance: 1,
          _vectorScore: 0,
          _bm25Score: bm25Norm,
          _fused: 0.3 * bm25Norm,
        });
      }
      candidates = [...byId.values()].sort(
        (a, b) => (b._fused ?? 0) - (a._fused ?? 0),
      );
    }
  }
} catch {
  /* fallback */
}

if (candidates.length === 0) {
  candidates = await keywordFallback(profile, query, moduleFilter);
}

if (candidates.length === 0) {
  console.log(`[${profile}] No chunks. Run: sigla-context-index.ps1 -Profile ${profile}`);
  process.exit(0);
}

const results = await rerank(query, candidates.slice(0, TOP_K), MAX_CHUNKS);

console.log(
  `# [${profile}] Context retrieval (${results.length}/${candidates.length} chunks, ${hybrid ? "hybrid+rerank" : "vector+rerank"})\n`,
);
for (const [i, row] of results.entries()) {
  const dist = typeof row._distance === "number" ? row._distance.toFixed(3) : "?";
  const rr = typeof row._rerank === "number" ? row._rerank.toFixed(3) : "n/a";
  const kindTag = row.kind ? `[${row.kind}]` : "";
  console.log(
    `## [${i + 1}] ${kindTag} ${row.source} (rerank=${rr}, dist=${dist})\n${row.text}\n`,
  );
}
