import { appendFile, mkdir, readFile, writeFile, unlink } from "node:fs/promises";
import { join } from "node:path";
import {
  apiSummaryPath,
  contextDir,
  currentTaskPath,
  decisionsPath,
  memoryRoot,
  modulesJsonPath,
  parseTarget,
  projectSnapshotPath,
  ticketsDir,
} from "./lib/paths.ts";

type TicketInput = {
  ticket: string;
  goal?: string;
  files?: string[];
  decisions?: string[];
  apis?: string[];
  debt?: string[];
  future?: string[];
};

function parseLearnArgs(argv: string[]): { profile: string; input: TicketInput } {
  const { profile } = parseTarget(argv);
  const input: TicketInput = { ticket: "untitled" };

  for (let i = 2; i < argv.length; i++) {
    const flag = argv[i];
    const value = argv[i + 1];
    switch (flag) {
      case "--ticket":
        input.ticket = value;
        i++;
        break;
      case "--goal":
        input.goal = value;
        i++;
        break;
      case "--files":
        input.files = value.split(";").map((s) => s.trim()).filter(Boolean);
        i++;
        break;
      case "--decisions":
        input.decisions = value.split(";").map((s) => s.trim()).filter(Boolean);
        i++;
        break;
      case "--apis":
        input.apis = value.split(";").map((s) => s.trim()).filter(Boolean);
        i++;
        break;
      case "--debt":
        input.debt = value.split(";").map((s) => s.trim()).filter(Boolean);
        i++;
        break;
      case "--future":
        input.future = value.split(";").map((s) => s.trim()).filter(Boolean);
        i++;
        break;
      case "--json":
        Object.assign(input, JSON.parse(value));
        i++;
        break;
    }
  }

  return { profile, input };
}

function slug(ticket: string): string {
  return ticket.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function bulletList(items?: string[]): string {
  if (!items?.length) return "- none";
  return items.map((i) => `- ${i}`).join("\n");
}

function renderSummary(input: TicketInput): string {
  const date = new Date().toISOString().slice(0, 10);
  return `# ${input.ticket}

_Date: ${date}_ · _≤300 tokens_

## Goal
${input.goal ?? "—"}

## Files changed
${bulletList(input.files)}

## Decisions
${bulletList(input.decisions)}

## APIs affected
${bulletList(input.apis)}

## Technical debt
${bulletList(input.debt)}

## Future considerations
${bulletList(input.future)}
`;
}

async function updateDecisions(
  profile: string,
  ticket: string,
  decisions?: string[],
) {
  if (!decisions?.length) return;
  const path = decisionsPath(profile);
  const entry = `\n## ${ticket} (${new Date().toISOString().slice(0, 10)})\n${decisions.map((d) => `- ${d}`).join("\n")}\n`;
  await mkdir(contextDir(profile), { recursive: true });
  try {
    await appendFile(path, entry, "utf8");
  } catch {
    await writeFile(path, `# Decisions log (${profile})\n${entry}`, "utf8");
  }
}

async function updateProjectSnapshot(
  profile: string,
  ticket: string,
  input: TicketInput,
) {
  const path = projectSnapshotPath(profile);
  await mkdir(memoryRoot(profile), { recursive: true });

  const date = new Date().toISOString().slice(0, 10);
  const entry = [
    `### ${ticket} (${date})`,
    input.goal ? `- goal: ${input.goal}` : "",
    input.decisions?.length
      ? `- decisions: ${input.decisions.slice(0, 3).join("; ")}`
      : "",
    input.apis?.length ? `- apis: ${input.apis.slice(0, 3).join("; ")}` : "",
    input.files?.length ? `- files: ${input.files.slice(0, 5).join(", ")}` : "",
  ]
    .filter(Boolean)
    .join("\n");

  let body = "";
  try {
    body = await readFile(path, "utf8");
  } catch {
    body = `# Project snapshot (${profile})\n\n_Rolling window ≤50 lines — permanent log in context/decisions.md_\n\n`;
  }

  const lines = `${body.trim()}\n\n${entry}\n`.split("\n");
  const clipped = lines.slice(-50).join("\n") + "\n";
  await writeFile(path, clipped, "utf8");
}

async function updateModules(
  profile: string,
  ticket: string,
  files?: string[],
) {
  if (!files?.length) return;
  const path = modulesJsonPath(profile);
  await mkdir(memoryRoot(profile), { recursive: true });

  let graph: Record<string, { files: string[]; tickets: string[] }> = {};
  try {
    graph = JSON.parse(await readFile(path, "utf8"));
  } catch {
    graph = {};
  }

  for (const file of files) {
    const top = file.split(/[/\\]/)[0] ?? "misc";
    const key = top.replace(/^src$/, "core");
    if (!graph[key]) graph[key] = { files: [], tickets: [] };
    if (!graph[key].files.includes(file)) graph[key].files.push(file);
    if (!graph[key].tickets.includes(ticket)) graph[key].tickets.push(ticket);
  }

  await writeFile(path, `${JSON.stringify(graph, null, 2)}\n`, "utf8");
}

async function archiveCurrentTask(profile: string, ticketPath: string) {
  try {
    const task = await readFile(currentTaskPath(profile), "utf8");
    if (!task.trim()) return;
    await appendFile(
      ticketPath,
      `\n## current_task snapshot\n${task.trim()}\n`,
      "utf8",
    );
  } catch {
    /* no active task file */
  }
}

const { profile, input } = parseLearnArgs(process.argv);
const dir = ticketsDir(profile);
await mkdir(dir, { recursive: true });

const fileName = `${slug(input.ticket)}.md`;
const ticketPath = join(dir, fileName);
await writeFile(ticketPath, renderSummary(input), "utf8");
await archiveCurrentTask(profile, ticketPath);
await updateDecisions(profile, input.ticket, input.decisions);
await updateProjectSnapshot(profile, input.ticket, input);
await updateModules(profile, input.ticket, input.files);

if (input.apis?.length) {
  await mkdir(contextDir(profile), { recursive: true });
  const apiBody = `# API touchpoints (${input.ticket})\n\n${input.apis.map((a) => `- ${a}`).join("\n")}\n`;
  await writeFile(apiSummaryPath(profile), apiBody, "utf8");
}

try {
  await unlink(currentTaskPath(profile));
} catch {
  /* no active task */
}

console.log(`[${profile}] state/memory/${profile}/tickets/${fileName}`);
