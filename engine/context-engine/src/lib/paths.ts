import { basename, join } from "node:path";
import { homedir } from "node:os";
import { accessSync, readFileSync } from "node:fs";
import { resolveRepositoryRoot, contextIdFromProfile, loadExecutionContext } from "./execution-context.ts";

export const IGNORE_DIRS = new Set([
  "node_modules",
  "dist",
  "build",
  "coverage",
  "coverage-reports",
  ".next",
  "vendor",
  "@mf-types",
  ".git",
  "vector",
  ".cursor",
  "state",
  "generated",
  "eval",
  ".turbo",
  "out",
  "target",
  "__pycache__",
  ".venv",
  "migrations",
]);

function walkToInstallPs1(start: string): string | null {
  let here = start.replace(/[\\/]+$/, "");
  for (let depth = 0; depth < 32; depth++) {
    try {
      accessSync(join(here, "install.ps1"));
      return here;
    } catch {
      const parent = join(here, "..");
      const normalized = parent.replace(/[\\/]+$/, "");
      if (normalized === here) break;
      here = normalized;
    }
  }
  return null;
}

/** octo-cluster root (git source of truth). */
export function octoClusterRoot(): string {
  const fromEnv = process.env.OCTO_CLUSTER?.replace(/[\\/]+$/, "");
  if (fromEnv) {
    try {
      accessSync(join(fromEnv, "install.ps1"));
      return fromEnv;
    } catch {
      try {
        accessSync(fromEnv);
        return fromEnv;
      } catch {
        /* fall through */
      }
    }
  }

  const fromScript = walkToInstallPs1(join(import.meta.dir, "..", "..", ".."));
  if (fromScript) return fromScript;

  const cwd = process.cwd().replace(/[\\/]+$/, "");
  const fromCwd = walkToInstallPs1(cwd);
  if (fromCwd) return fromCwd;

  throw new Error(
    "OCTO_CLUSTER not resolved. Run install.ps1 from your clone root or set User-level OCTO_CLUSTER.",
  );
}

/** @deprecated use octoClusterRoot */
export function aiWorkspaceRoot(): string {
  return octoClusterRoot();
}

/** @deprecated use octoClusterRoot */
export function cursorHome(): string {
  return octoClusterRoot();
}

export function contextEngineRoot(): string {
  return join(octoClusterRoot(), "engine", "context-engine");
}

export function packDocsRoot(packId: string): string {
  const envKey = `${packId.toUpperCase().replace(/-/g, "_")}_DOCS_ROOT`;
  const fromEnv = process.env[envKey]?.replace(/[\\/]+$/, "");
  if (fromEnv) return fromEnv;

  const ctxId = contextIdFromProfile(packId);
  const ctx = loadExecutionContext(ctxId);
  if (ctx?.docs_root) {
    const rel = ctx.docs_root.replace(/[\\/]+$/, "");
    if (/^[a-zA-Z]:[\\/]/.test(rel) || rel.startsWith("/")) return rel;
    return join(octoClusterRoot(), rel);
  }

  return join(octoClusterRoot(), "domains", packId, "docs");
}

/** Repo folder name → memory profile (e.g. my-product-api). */
export function profileFromRepo(repoRoot: string): string {
  return basename(repoRoot.replace(/[\\/]+$/, ""));
}

export function memoryRoot(profile: string): string {
  return join(octoClusterRoot(), "state", "memory", profile);
}

export function contextDir(profile: string): string {
  return join(memoryRoot(profile), "context");
}

export function ticketsDir(profile: string): string {
  return join(memoryRoot(profile), "tickets");
}

export function vectorPath(profile: string): string {
  return join(memoryRoot(profile), "vector", "lancedb");
}

export function manifestPath(profile: string): string {
  return join(memoryRoot(profile), "vector", "manifest.json");
}

export function ftsPath(profile: string): string {
  return join(memoryRoot(profile), "vector", "fts.sqlite");
}

export function symbolsPath(profile: string): string {
  return join(memoryRoot(profile), "symbols.json");
}

export function overviewPath(profile: string): string {
  return join(memoryRoot(profile), "overview.md");
}

export function sessionSummaryPath(profile: string): string {
  return join(memoryRoot(profile), "session-summary.md");
}

export function modulesJsonPath(profile: string): string {
  return join(memoryRoot(profile), "modules.json");
}

export function decisionsPath(profile: string): string {
  return join(contextDir(profile), "decisions.md");
}

export function currentTaskPath(profile: string): string {
  return join(memoryRoot(profile), "current_task.md");
}

export function taskDetailsPath(profile: string): string {
  return join(memoryRoot(profile), "task_details.md");
}

export function projectSnapshotPath(profile: string): string {
  return join(memoryRoot(profile), "project_snapshot.md");
}

export function carryForwardPath(profile: string): string {
  return join(memoryRoot(profile), "carry-forward.md");
}

export function apiSummaryPath(profile: string): string {
  return join(contextDir(profile), "api-summary.md");
}


/** Ship repos from execution context JSON (platform profile -> contexts/platform.json). */
export function resolveShipRepositoryRoots(profile: string): Array<{ name: string; root: string }> {
  const ctxId = contextIdFromProfile(profile);
  let repos: string[] = [];

  try {
    const ctx = JSON.parse(readFileSync(join(octoClusterRoot(), "contexts", `${ctxId}.json`), "utf8")) as {
      ship_repositories?: string[];
    };
    repos = ctx.ship_repositories ?? [];
  } catch {
    /* fall through */
  }

  if (repos.length === 0) {
    repos = profile === "octo-cluster" ? ["octo-cluster"] : [profile];
  }

  const roots: Array<{ name: string; root: string }> = [];
  for (const name of repos) {
    const resolved = resolveRepositoryRoot(name, profile);
    if (resolved) roots.push(resolved);
  }

  return roots;
}
export type Target = { profile: string; repoRoot?: string };

/** First arg or --profile / --repo flags. */
export function parseTarget(argv: string[]): Target {
  let profile = "";
  let repoRoot: string | undefined;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--profile") {
      profile = argv[++i] ?? "";
    } else if (a === "--repo") {
      repoRoot = argv[++i];
    }
  }

  const positional = argv[2];
  if (!profile && positional && !positional.startsWith("--")) {
    if (positional.includes("\\") || positional.includes("/")) {
      repoRoot = positional;
      profile = profileFromRepo(positional);
    } else {
      profile = positional;
    }
  }

  if (!profile && repoRoot) profile = profileFromRepo(repoRoot);
  if (!profile) throw new Error("Missing profile or repo path");

  return { profile, repoRoot };
}
