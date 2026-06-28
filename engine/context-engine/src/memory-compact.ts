import { mkdir, readFile, writeFile, stat, readdir } from "node:fs/promises";
import { join } from "node:path";
import {
  carryForwardPath,
  contextDir,
  currentTaskPath,
  memoryRoot,
  overviewPath,
  parseTarget,
  projectSnapshotPath,
  taskDetailsPath,
  ticketsDir,
} from "./lib/paths.ts";

const LIMITS = {
  currentTaskTokens: 200,
  carryForwardLines: 10,
  projectSnapshotLines: 50,
  overviewLines: 80,
};

const REQUIRED_FIELDS = [
  "CARD",
  "CARD_TYPE",
  "MFE",
  "GOAL",
  "SCOPE",
  "RISKS",
  "NEXT",
] as const;

function estTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

function lineCount(text: string): number {
  return text.split("\n").filter((l) => l.trim()).length;
}

function parseTaskFields(raw: string): Record<string, string> {
  const fields: Record<string, string> = {};
  for (const line of raw.split("\n")) {
    const m = line.match(/^([A-Z_]+):\s*(.*)$/);
    if (m) fields[m[1]] = m[2].trim();
  }
  return fields;
}

function renderTask(fields: Record<string, string>): string {
  return REQUIRED_FIELDS.map((k) => `${k}: ${fields[k] ?? "—"}`).join("\n") + "\n";
}

async function trimCurrentTask(profile: string): Promise<string[]> {
  const path = currentTaskPath(profile);
  const actions: string[] = [];
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return actions;
  }

  const fields = parseTaskFields(raw);
  const extras = raw
    .split("\n")
    .filter((l) => !l.match(/^([A-Z_]+):/))
    .join("\n")
    .trim();

  let slim = renderTask(fields);
  if (estTokens(slim) > LIMITS.currentTaskTokens || extras) {
    const detailPath = taskDetailsPath(profile);
    const overflow = [extras, raw.includes("\n##") ? raw : ""]
      .filter(Boolean)
      .join("\n\n");
    if (overflow) {
      await mkdir(memoryRoot(profile), { recursive: true });
      await writeFile(
        detailPath,
        `# Task details (${profile})\n\n${overflow}\n`,
        "utf8",
      );
      actions.push(`moved overflow → task_details.md`);
    }
    slim = renderTask(fields);
    await writeFile(path, slim, "utf8");
    actions.push(`trimmed current_task.md (~${estTokens(slim)} tokens)`);
  }
  return actions;
}

async function trimCarryForward(profile: string): Promise<string[]> {
  const path = carryForwardPath(profile);
  const actions: string[] = [];
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return actions;
  }
  const lines = raw.split("\n").filter((l) => l.trim());
  if (lines.length <= LIMITS.carryForwardLines) return actions;

  const kept = lines.slice(0, LIMITS.carryForwardLines).join("\n") + "\n";
  await writeFile(path, kept, "utf8");
  actions.push(`carry-forward trimmed to ${LIMITS.carryForwardLines} lines`);
  return actions;
}

async function compressSnapshot(profile: string): Promise<string[]> {
  const path = projectSnapshotPath(profile);
  const actions: string[] = [];
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return actions;
  }
  const lines = raw.split("\n");
  if (lines.length <= LIMITS.projectSnapshotLines) return actions;

  const header = lines.slice(0, 5);
  const tail = lines.slice(-(LIMITS.projectSnapshotLines - 6));
  const compressed =
    [...header, "\n…[rolling compress — older entries dropped]\n", ...tail].join("\n") + "\n";
  await writeFile(path, compressed, "utf8");
  actions.push(`project_snapshot.md compressed to ~${LIMITS.projectSnapshotLines} lines`);
  return actions;
}

async function trimOverview(profile: string): Promise<string[]> {
  const path = overviewPath(profile);
  const actions: string[] = [];
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return actions;
  }
  const lines = raw.split("\n");
  if (lineCount(raw) <= LIMITS.overviewLines) return actions;

  const dir = ticketsDir(profile);
  await mkdir(dir, { recursive: true });
  const archive = `${dir}/overview-archive-${new Date().toISOString().slice(0, 10)}.md`;
  await writeFile(archive, raw, "utf8");
  const kept = lines.slice(0, LIMITS.overviewLines).join("\n") + "\n";
  await writeFile(path, kept, "utf8");
  actions.push(`overview archived excess → tickets/${archive.split(/[/\\]/).pop()}`);
  return actions;
}

/** Decay stale L1 context files not touched in 60d — OpenViking-inspired DIY tiering. */
async function decayStaleContext(profile: string): Promise<string[]> {
  const actions: string[] = [];
  const ctxPath = contextDir(profile);
  const maxAgeMs = 60 * 24 * 60 * 60 * 1000;
  const now = Date.now();

  let files: string[];
  try {
    files = await readdir(ctxPath);
  } catch {
    return actions;
  }

  for (const name of files) {
    if (!/\.md$/i.test(name) || name === "decisions.md") continue;
    const full = join(ctxPath, name);
    try {
      const st = await stat(full);
      if (now - st.mtimeMs < maxAgeMs) continue;
      const archiveDir = join(ticketsDir(profile), "context-archive");
      await mkdir(archiveDir, { recursive: true });
      const dest = join(archiveDir, name);
      const body = await readFile(full, "utf8");
      await writeFile(dest, body, "utf8");
      await writeFile(
        full,
        `# ${name.replace(/\.md$/i, "")} (archived — retrieve via sigla-context-search)\n\n_Stale L1 — see tickets/context-archive/${name}_\n`,
        "utf8",
      );
      actions.push(`decayed stale L1 → context-archive/${name}`);
    } catch {
      /* skip */
    }
  }
  return actions;
}

const { profile } = parseTarget(process.argv);
const allActions = [
  ...(await trimCurrentTask(profile)),
  ...(await trimCarryForward(profile)),
  ...(await compressSnapshot(profile)),
  ...(await trimOverview(profile)),
  ...(await decayStaleContext(profile)),
];

if (allActions.length === 0) {
  console.log(`[${profile}] memory compact: OK (within limits)`);
} else {
  console.log(`[${profile}] memory compact:`);
  for (const a of allActions) console.log(`  - ${a}`);
}
