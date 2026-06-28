import { mkdir, writeFile } from "node:fs/promises";
import { memoryRoot, parseTarget, sessionSummaryPath } from "./lib/paths.ts";

const { profile } = parseTarget(process.argv);

const fields: Record<string, string> = {
  objective: "",
  files: "",
  completed: "",
  pending: "",
  constraints: "",
};

for (let i = 3; i < process.argv.length; i++) {
  const key = process.argv[i]?.replace(/^--/, "");
  const value = process.argv[i + 1];
  if (key && value && key in fields) {
    fields[key] = value;
    i++;
  }
}

const summary = `# Session summary (${profile})

_Generated: ${new Date().toISOString()}_ · paste into **new chat** only

## Current objective
${fields.objective || "—"}

## Files involved
${fields.files || "—"}

## Completed work
${fields.completed || "—"}

## Pending work
${fields.pending || "—"}

## Known constraints
${fields.constraints || "—"}
`;

const outPath = sessionSummaryPath(profile);
await mkdir(memoryRoot(profile), { recursive: true });
await writeFile(outPath, summary, "utf8");
console.log(`[${profile}] ${outPath}`);
