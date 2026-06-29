import { copyFile, mkdir, readdir, stat } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { memoryRoot } from "./paths.ts";

async function exists(path: string): Promise<boolean> {
  return stat(path)
    .then(() => true)
    .catch(() => false);
}

/** Tracked bootstrap files shipped with context-engine (CI + fresh clone). */
export function fixtureProfileRoot(profile: string): string {
  const libDir = dirname(fileURLToPath(import.meta.url));
  return join(libDir, "..", "..", "fixtures", "profiles", profile);
}

async function copyMissingFiles(srcDir: string, destDir: string, created: string[]): Promise<void> {
  await mkdir(destDir, { recursive: true });
  for (const entry of await readdir(srcDir, { withFileTypes: true })) {
    const src = join(srcDir, entry.name);
    const dest = join(destDir, entry.name);
    if (entry.isDirectory()) {
      await copyMissingFiles(src, dest, created);
      continue;
    }
    if (await exists(dest)) continue;
    await copyFile(src, dest);
    created.push(dest);
  }
}

/**
 * Copy fixture profile into state/memory/<profile> when files are missing.
 * Never overwrites existing runtime memory (tickets, vectors, edits).
 */
export async function ensureProfileSeed(profile: string): Promise<{ created: string[] }> {
  const fixture = fixtureProfileRoot(profile);
  if (!(await exists(fixture))) {
    throw new Error(`No fixture profile "${profile}" at ${fixture}`);
  }

  const root = memoryRoot(profile);
  const created: string[] = [];
  await copyMissingFiles(fixture, root, created);
  return { created };
}
