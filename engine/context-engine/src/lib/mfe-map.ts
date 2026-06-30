import { readFile } from "node:fs/promises";
import { join } from "node:path";
import {
  contextIdFromProfile,
  resolveActiveProfile,
  resolveBusinessDocsRoot,
  resolveWorkspaceRoot,
} from "./execution-context.ts";

export type MfeEntry = {
  api: string[];
  web: string[];
  docs: string[];
};

const cacheByProfile = new Map<string, Record<string, MfeEntry>>();

export async function loadMfeMap(profile?: string): Promise<Record<string, MfeEntry>> {
  const key = contextIdFromProfile(resolveActiveProfile(profile));
  const cached = cacheByProfile.get(key);
  if (cached) return cached;
  const docsRoot = resolveBusinessDocsRoot(key);
  const path = join(docsRoot, "mfe-module-map.json");
  const map = JSON.parse(await readFile(path, "utf8")) as Record<string, MfeEntry>;
  cacheByProfile.set(key, map);
  return map;
}

export async function resolveMfe(mfe: string, profile?: string): Promise<MfeEntry | undefined> {
  const map = await loadMfeMap(profile);
  return map[mfe];
}

export function defaultWorkspaceRoot(profile?: string): string {
  return resolveWorkspaceRoot(resolveActiveProfile(profile));
}
