import { readFileSync } from "node:fs";

const MAX_LINES = 40;
const MAX_CHARS = 1200;

function readInput(path?: string): string {
  if (path && path !== "-") {
    return readFileSync(path, "utf8");
  }
  return readFileSync(0, "utf8");
}

const inputPath = process.argv[2] ?? "-";
const raw = readInput(inputPath);
const lines = raw.replace(/\r\n/g, "\n").split("\n");

const errorPatterns = [
  /error\s+TS\d+/i,
  /\bTS\d{4}\b/,
  /SyntaxError:/i,
  /TypeError:/i,
  /ReferenceError:/i,
  /FAILED/i,
  /✖/,
  /AssertionError/i,
  /ELIFECYCLE/i,
  /EADDRINUSE/i,
];

let firstErrorIdx = -1;
for (let i = 0; i < lines.length; i++) {
  if (errorPatterns.some((p) => p.test(lines[i]))) {
    firstErrorIdx = i;
    break;
  }
}

const warnings = new Map<string, number>();
for (const line of lines) {
  if (/warn/i.test(line)) {
    const key = line.trim().slice(0, 120);
    warnings.set(key, (warnings.get(key) ?? 0) + 1);
  }
}

const out: string[] = [];
out.push(firstErrorIdx >= 0 ? "Build/test failed" : "Log summary");
out.push(`Total lines: ${lines.length}`);

if (firstErrorIdx >= 0) {
  const window = lines.slice(firstErrorIdx, firstErrorIdx + 12);
  const deduped: string[] = [];
  const seen = new Set<string>();
  for (const line of window) {
    const key = line.trim();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    deduped.push(line);
    if (deduped.length >= 8) break;
  }

  out.push("\nRoot cause:");
  out.push(...deduped);

  const fileMatch = window.join("\n").match(/([\w./\\-]+\.(?:ts|tsx|js|jsx)):(\d+)/);
  if (fileMatch) {
    out.push(`\nFile: ${fileMatch[1]}:${fileMatch[2]}`);
  }
}

if (warnings.size > 0) {
  const collapsed = [...warnings.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([msg, count]) => (count > 1 ? `${msg} (×${count})` : msg));
  out.push("\nWarnings (collapsed):");
  out.push(...collapsed);
}

const omitted = Math.max(0, lines.length - (firstErrorIdx >= 0 ? 12 : 0));
if (omitted > 0) {
  out.push(`\nOmitted: ${omitted} unrelated lines`);
}

let summary = out.join("\n");
if (summary.length > MAX_CHARS) {
  summary = `${summary.slice(0, MAX_CHARS)}\n…[truncated]`;
}

const summaryLines = summary.split("\n").slice(0, MAX_LINES);
console.log(summaryLines.join("\n"));
