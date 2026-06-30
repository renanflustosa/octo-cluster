import { accessSync, readFileSync } from "node:fs";
import { join, normalize } from "node:path";
import { octoClusterRoot } from "./paths.ts";

export type IndexRepository = {
  name: string;
  path_env: string;
  subdir?: string;
  /** When false, skip indexing and resolution (e.g. secrets vault). Default true. */
  index?: boolean;
};

export type ExecutionContextConfig = {
  id?: string;
  docs_root?: string;
  ship_repositories?: string[];
  index_repositories?: IndexRepository[];
  workspace_root_env?: string;
  secrets_vault_env?: string;
};

export function contextIdFromProfile(profile: string): string {
  return profile === "octo-cluster" ? "platform" : profile;
}

function readContextFile(ctxId: string): ExecutionContextConfig | null {
  const dir = join(octoClusterRoot(), "contexts");
  for (const fileName of [`${ctxId}.local.json`, `${ctxId}.json`]) {
    try {
      const raw = readFileSync(join(dir, fileName), "utf8");
      return JSON.parse(raw) as ExecutionContextConfig;
    } catch {
      /* try next */
    }
  }
  return null;
}

export function loadExecutionContext(profile: string): ExecutionContextConfig | null {
  return readContextFile(contextIdFromProfile(profile));
}

export function resolveEnvPath(envKey: string): string | null {
  const val = process.env[envKey]?.replace(/[\\/]+$/, "");
  return val || null;
}

export function resolveRepositoryRoot(
  repoName: string,
  profile: string,
): { name: string; root: string } | null {
  const ws = octoClusterRoot();
  const ctx = loadExecutionContext(profile);

  if (repoName === "octo-cluster") {
    return { name: repoName, root: ws };
  }

  const indexed = ctx?.index_repositories?.find((r) => r.name === repoName);
  if (indexed) {
    if (indexed.index === false) return null;
    const base = resolveEnvPath(indexed.path_env);
    if (!base) return null;
    const root = normalize(indexed.subdir ? join(base, indexed.subdir) : base);
    try {
      accessSync(root);
      return { name: repoName, root };
    } catch {
      return null;
    }
  }

  if (ctx?.secrets_vault_env) {
    const vaultName = ctx.secrets_vault_env.replace(/_ROOT$|_PATH$/i, "").toLowerCase().replace(/_/g, "-");
    if (repoName === vaultName || repoName.endsWith("-vault")) {
      return null;
    }
  }

  const sibling = join(ws, "..", repoName);
  try {
    accessSync(sibling);
    return { name: repoName, root: normalize(sibling) };
  } catch {
    return null;
  }
}

export function resolveActiveProfile(explicit?: string): string {
  if (explicit) return explicit;
  return process.env.CONTEXT_ENGINE_PROFILE ?? process.env.AI_EXECUTION_CONTEXT ?? "platform";
}

export function resolveWorkspaceRoot(profile: string): string {
  const ctx = loadExecutionContext(profile);
  const envKey = ctx?.workspace_root_env;
  if (envKey) {
    const fromEnv = resolveEnvPath(envKey);
    if (fromEnv) return fromEnv;
    throw new Error(
      `Missing env ${envKey} for profile "${profile}" (set in workspace file or shell)`,
    );
  }
  throw new Error(
    `No workspace_root_env in contexts/${contextIdFromProfile(profile)}.json for profile "${profile}"`,
  );
}

/** True when profile has code repos to index and an MFE module map in business docs. */
export function hasCodeIndex(profile: string): boolean {
  const ctx = loadExecutionContext(profile);
  const codeRepos = (ctx?.index_repositories ?? []).filter(
    (r) => !r.name.endsWith("-docs") && r.index !== false,
  );
  if (!codeRepos.length) return false;
  try {
    const docsRoot = resolveBusinessDocsRoot(profile);
    accessSync(join(docsRoot, "mfe-module-map.json"));
    return true;
  } catch {
    return false;
  }
}

/** Business docs root from index_repositories, pack env, or context docs_root. */
export function resolveBusinessDocsRoot(profile: string): string {
  const ctx = loadExecutionContext(profile);
  const docsRepo = ctx?.index_repositories?.find((r) => r.name.endsWith("-docs"));
  if (docsRepo) {
    const base = resolveEnvPath(docsRepo.path_env);
    if (base) {
      return normalize(docsRepo.subdir ? join(base, docsRepo.subdir) : base);
    }
  }
  const packId = contextIdFromProfile(profile);
  const envKey = `${packId.toUpperCase().replace(/-/g, "_")}_DOCS_ROOT`;
  const fromEnv = process.env[envKey]?.replace(/[\\/]+$/, "");
  if (fromEnv) return fromEnv;
  if (ctx?.docs_root) {
    const rel = ctx.docs_root.replace(/[\\/]+$/, "");
    if (/^[a-zA-Z]:[\\/]/.test(rel) || rel.startsWith("/")) return rel;
    return normalize(join(octoClusterRoot(), rel));
  }
  return normalize(join(octoClusterRoot(), "domains", packId, "docs"));
}

export function resolveDocsRepoName(profile: string): string {
  const ctx = loadExecutionContext(profile);
  const docsRepo = ctx?.index_repositories?.find((r) => r.name.endsWith("-docs"));
  return docsRepo?.name ?? `${contextIdFromProfile(profile)}-docs`;
}
