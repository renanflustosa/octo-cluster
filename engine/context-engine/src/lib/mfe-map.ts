import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { mplanDocsRoot } from "./paths.ts";

export type MfeEntry = {
  api: string[];
  web: string[];
  docs: string[];
};

let cache: Record<string, MfeEntry> | null = null;

export async function loadMfeMap(): Promise<Record<string, MfeEntry>> {
  if (cache) return cache;
  const path = join(mplanDocsRoot(), "mfe-module-map.json");
  cache = JSON.parse(await readFile(path, "utf8")) as Record<string, MfeEntry>;
  return cache;
}

export async function resolveMfe(mfe: string): Promise<MfeEntry | undefined> {
  const map = await loadMfeMap();
  return map[mfe];
}

export function defaultWorkspaceRoot(): string {
  return process.env.SIGLA_WORKSPACE_ROOT ?? "C:/github/mplan-ingestion";
}
