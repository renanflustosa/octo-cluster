import { accessSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** Resolve Bun executable (Windows: ~/.bun/bin/bun.exe when not on PATH). */
export function resolveBunExecutable(): string {
  const fromEnv = process.env.BUN_EXE?.trim();
  if (fromEnv) {
    try {
      accessSync(fromEnv);
      return fromEnv;
    } catch {
      /* fall through */
    }
  }

  const home = homedir();
  const candidates = [
    join(home, ".bun", "bin", "bun.exe"),
    join(home, ".bun", "bin", "bun"),
    join(process.env.LOCALAPPDATA ?? "", "bun", "bin", "bun.exe"),
  ];

  for (const path of candidates) {
    if (!path) continue;
    try {
      accessSync(path);
      return path;
    } catch {
      /* try next */
    }
  }

  return "bun";
}
