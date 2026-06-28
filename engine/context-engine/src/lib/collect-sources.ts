import { readdir, stat } from "node:fs/promises";
import { join, relative } from "node:path";
import { collectMemoryFiles, moduleFromRel, relSource } from "./collect.ts";
import { chunkHtml, chunkPlainText } from "./chunk-html.ts";
import { chunkSourceCode } from "./chunk-code.ts";
import { chunkMarkdown } from "./chunk.ts";
import { resolveMfe, defaultWorkspaceRoot } from "./mfe-map.ts";
import { packDocsRoot, IGNORE_DIRS, resolveShipRepositoryRoots } from "./paths.ts";
import type { ChunkKind, SourceFile } from "./types.ts";

export type CollectOptions = {
  kinds: Set<ChunkKind>;
  mfe?: string;
  moduleFilter?: string;
};

const CODE_EXT = /\.(ts|tsx|js|jsx|srw|srd)$/i;
const PLATFORM_CODE_EXT = /\.(ts|tsx|js|jsx|go|py|ps1)$/i;
const MAX_PLATFORM_SOURCE_FILES = 80;
const PLATFORM_REPO_SCOPES: Record<string, string[]> = {
  "octo-cluster": [
    "domains/core/scripts",
    "domains/core/skills",
    "capabilities",
    "scripts",
    "engine/context-engine/src",
    "repo-policies",
  ],
};
const SKIP_PLATFORM = /(?:^|[\\/])\.cursor(?:[\\/]|$)|(?:^|[\\/])state(?:[\\/]|$)|(?:^|[\\/])\.git(?:[\\/]|$)/;
const SKIP_CODE = /\.(test|spec|integration)\.(ts|tsx|js|jsx)$/i;
const MAX_CODE_CHUNKS = 500;

async function walkFiles(
  dir: string,
  root: string,
  match: (rel: string) => boolean,
  out: string[],
  maxFiles?: number,
): Promise<void> {
  if (maxFiles !== undefined && out.length >= maxFiles) return;
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (maxFiles !== undefined && out.length >= maxFiles) return;
    const full = join(dir, entry.name);
    const rel = relative(root, full).replace(/\\/g, "/");
    if (entry.isDirectory()) {
      if (IGNORE_DIRS.has(entry.name)) continue;
      await walkFiles(full, root, match, out, maxFiles);
      continue;
    }
    if (entry.isFile() && match(rel)) {
      out.push(full);
      if (maxFiles !== undefined && out.length >= maxFiles) return;
    }
  }
}

export async function collectMemorySources(profile: string): Promise<SourceFile[]> {
  const files = await collectMemoryFiles(profile);
  const out: SourceFile[] = [];
  for (const file of files) {
    const st = await stat(file);
    out.push({
      absolutePath: file,
      source: relSource(profile, file),
      repo: profile,
      kind: "memory",
      module: moduleFromRel(relSource(profile, file)) ?? "",
      mtime: st.mtimeMs,
    });
  }
  return out;
}

export async function collectDocsSources(
  _profile: string,
  mfe?: string,
): Promise<SourceFile[]> {
  const docsRoot = packDocsRoot("mplan");
  const out: SourceFile[] = [];
  const docHints = mfe ? ((await resolveMfe(mfe))?.docs ?? []) : [];
  const paths: string[] = [];

  await walkFiles(
    join(docsRoot, "context"),
    docsRoot,
    (rel) => /\.md$/i.test(rel) && rel.startsWith("context/"),
    paths,
  );
  await walkFiles(
    join(docsRoot, "context", "matrices"),
    docsRoot,
    (rel) => /\.md$/i.test(rel),
    paths,
  );
  await walkFiles(
    join(docsRoot, "source"),
    docsRoot,
    (rel) => /\.html$/i.test(rel),
    paths,
  );

  for (const abs of paths) {
    const rel = relative(docsRoot, abs).replace(/\\/g, "/");
    const base = rel.split("/").pop() ?? "";
    if (
      rel.startsWith("context/") &&
      !rel.includes("matrices/") &&
      docHints.length &&
      !docHints.includes(base) &&
      base !== "00-INDEX.md" &&
      base !== "01-glossario-entidades.md"
    ) {
      continue;
    }
    const st = await stat(abs);
    out.push({
      absolutePath: abs,
      source: rel,
      repo: "mplan-docs",
      kind: "docs",
      module: base.replace(/\.(md|html)$/i, ""),
      mtime: st.mtimeMs,
    });
  }

  return out;
}


async function collectPlatformCodeSources(profile: string): Promise<SourceFile[]> {
  const out: SourceFile[] = [];
  const repos = resolveShipRepositoryRoots(profile);

  for (const { name, root } of repos) {
    const scopes = PLATFORM_REPO_SCOPES[name];
    const walkRoots = scopes?.length
      ? scopes.map((rel) => join(root, rel.replace(/\//g, "\\")))
      : [root];

    for (const walkRoot of walkRoots) {
      const paths: string[] = [];
      await walkFiles(
        walkRoot,
        walkRoot,
        (rel) =>
          PLATFORM_CODE_EXT.test(rel) &&
          !SKIP_CODE.test(rel) &&
          !SKIP_PLATFORM.test(rel),
        paths,
      );
      for (const abs of paths) {
        if (out.length >= MAX_PLATFORM_SOURCE_FILES) break;
        const st = await stat(abs);
        const rel = relative(walkRoot, abs).replace(/\\/g, "/");
        const scopeRel = relative(root, walkRoot).replace(/\\/g, "/");
        const source = scopeRel ? `${name}/${scopeRel}/${rel}` : `${name}/${rel}`;
        const module = rel.split("/")[0] ?? name;
        out.push({
          absolutePath: abs,
          source,
          repo: name,
          kind: "code",
          module,
          mtime: st.mtimeMs,
        });
      }
      if (out.length >= MAX_PLATFORM_SOURCE_FILES) break;
    }
    if (out.length >= MAX_PLATFORM_SOURCE_FILES) break;
  }

  if (out.length >= MAX_PLATFORM_SOURCE_FILES) {
    console.warn(
      `[platform] Capped code sources at ${MAX_PLATFORM_SOURCE_FILES} files (scoped index)`,
    );
  }

  return out;
}
export async function collectCodeSources(
  profile: string,
  mfe?: string,
  moduleFilter?: string,
): Promise<SourceFile[]> {
  if (profile === "octo-cluster" || profile === "platform") {
    return collectPlatformCodeSources(profile);
  }

  const ws = defaultWorkspaceRoot();
  const out: SourceFile[] = [];
  const entry = mfe ? await resolveMfe(mfe) : undefined;

  const apiModules = moduleFilter ? [moduleFilter] : (entry?.api ?? []);
  const apiRoot = join(ws, "sigla-api");

  for (const mod of apiModules) {
    const modDir = join(apiRoot, "src", "modules", mod);
    const paths: string[] = [];
    await walkFiles(
      modDir,
      apiRoot,
      (rel) => CODE_EXT.test(rel) && !SKIP_CODE.test(rel),
      paths,
    );
    for (const abs of paths) {
      const st = await stat(abs);
      out.push({
        absolutePath: abs,
        source: relative(apiRoot, abs).replace(/\\/g, "/"),
        repo: "sigla-api",
        kind: "code",
        module: mod,
        mtime: st.mtimeMs,
      });
    }
  }

  const webApps = entry?.web ?? [];
  const webRoot = join(ws, "sigla-web");
  for (const app of webApps) {
    const appDir = join(webRoot, "apps", app);
    const paths: string[] = [];
    await walkFiles(
      appDir,
      webRoot,
      (rel) => CODE_EXT.test(rel) && !SKIP_CODE.test(rel),
      paths,
    );
    for (const abs of paths) {
      const st = await stat(abs);
      out.push({
        absolutePath: abs,
        source: relative(webRoot, abs).replace(/\\/g, "/"),
        repo: "sigla-web",
        kind: "code",
        module: app,
        mtime: st.mtimeMs,
      });
    }
  }

  return out;
}

export async function collectAllSources(
  profile: string,
  opts: CollectOptions,
): Promise<SourceFile[]> {
  const out: SourceFile[] = [];
  if (opts.kinds.has("memory")) {
    out.push(...(await collectMemorySources(profile)));
  }
  if (opts.kinds.has("docs")) {
    out.push(...(await collectDocsSources(profile, opts.mfe)));
  }
  if (opts.kinds.has("code")) {
    out.push(...(await collectCodeSources(profile, opts.mfe, opts.moduleFilter)));
  }
  return out;
}

export async function fileToChunks(
  file: SourceFile,
): Promise<Array<{ id: string; source: string; text: string; module: string }>> {
  const content = await Bun.file(file.absolutePath).text();
  if (file.kind === "memory") {
    return chunkMarkdown(file.source, content, file.module || undefined);
  }
  if (file.kind === "docs") {
    if (file.absolutePath.endsWith(".html")) {
      return chunkHtml(file.source, content, file.module);
    }
    return chunkPlainText(file.source, content, file.module);
  }
  return chunkSourceCode(file.source, content, file.module);
}

export function capCodeChunks<T extends { kind: ChunkKind }>(
  rows: T[],
  max = MAX_CODE_CHUNKS,
): T[] {
  const code = rows.filter((r) => r.kind === "code");
  if (code.length <= max) return rows;
  const other = rows.filter((r) => r.kind !== "code");
  return [...other, ...code.slice(0, max)];
}
