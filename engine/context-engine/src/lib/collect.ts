import { readdir, readFile, stat } from "node:fs/promises";
import { join, relative } from "node:path";
import {
  contextDir,
  memoryRoot,
  overviewPath,
  ticketsDir,
  IGNORE_DIRS,
} from "./paths.ts";

export async function collectMemoryFiles(profile: string): Promise<string[]> {
  const root = memoryRoot(profile);
  const files: string[] = [];

  async function tryFile(path: string) {
    try {
      await stat(path);
      files.push(path);
    } catch {
      /* missing */
    }
  }

  await tryFile(overviewPath(profile));

  for (const dir of [contextDir(profile), ticketsDir(profile)]) {
    try {
      await walk(dir, root, files);
    } catch {
      /* missing */
    }
  }

  return files;
}

async function walk(
  dir: string,
  memoryRootPath: string,
  files: string[],
): Promise<void> {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    const rel = relative(memoryRootPath, full).replace(/\\/g, "/");

    if (entry.isDirectory()) {
      if (IGNORE_DIRS.has(entry.name) || rel.startsWith("vector/")) continue;
      await walk(full, memoryRootPath, files);
      continue;
    }

    if (entry.isFile() && /\.(md|mdc|json)$/i.test(entry.name)) {
      files.push(full);
    }
  }
}

export function relSource(profile: string, absolutePath: string): string {
  const root = memoryRoot(profile);
  return relative(root, absolutePath).replace(/\\/g, "/");
}

export function moduleFromRel(relPath: string): string | undefined {
  const ticket = relPath.match(/^tickets\/([^/]+)\.md$/i);
  if (ticket) return ticket[1];
  const ctx = relPath.match(/^context\/([^/]+)\.md$/i);
  if (ctx) return ctx[1];
  return undefined;
}
