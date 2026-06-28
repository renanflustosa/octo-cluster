import { readFile } from "node:fs/promises";

const path = process.argv[2];
if (!path) {
  console.error("Usage: bun run src/map-file.ts <file.ts|tsx|js>");
  process.exit(1);
}

const src = await readFile(path, "utf8");
const lines = src.split(/\r?\n/);
const out: string[] = [`# map: ${path}`, ""];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i]!;
  const trimmed = line.trim();
  if (/^(export\s+)?(async\s+)?function\s+\w+/.test(trimmed)) {
    out.push(`${i + 1}: ${trimmed.replace(/\s*\{.*$/, " { … }")}`);
  } else if (/^(export\s+)?(abstract\s+)?class\s+\w+/.test(trimmed)) {
    out.push(`${i + 1}: ${trimmed.replace(/\s*\{.*$/, " { … }")}`);
  } else if (/^export\s+(type|interface)\s+\w+/.test(trimmed)) {
    out.push(`${i + 1}: ${trimmed}`);
  } else if (/^export\s+(const|let|var)\s+\w+/.test(trimmed)) {
    out.push(`${i + 1}: ${trimmed.slice(0, 120)}`);
  }
}

if (out.length <= 2) {
  out.push("(no exported symbols matched — use grep or Read with offset)");
}

console.log(out.join("\n"));
