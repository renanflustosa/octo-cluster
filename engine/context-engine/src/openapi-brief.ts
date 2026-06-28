import { writeFile, mkdir } from "node:fs/promises";
import { apiSummaryPath, contextDir, parseTarget } from "./lib/paths.ts";

const { profile } = parseTarget(process.argv);

let url = "http://localhost:3000/doc";
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === "--url") url = process.argv[++i] ?? url;
}

const res = await fetch(url);
if (!res.ok) {
  console.error(`Failed to fetch ${url}: ${res.status}`);
  process.exit(1);
}

const doc = (await res.json()) as {
  paths?: Record<string, Record<string, { summary?: string; operationId?: string }>>;
};

const rows: string[] = [
  `# ${profile} — API summary (L1)`,
  "",
  `_Generated: ${new Date().toISOString().slice(0, 10)} from ${url}_`,
  "",
];

const paths = Object.entries(doc.paths ?? {}).sort(([a], [b]) => a.localeCompare(b));
for (const [route, methods] of paths) {
  for (const [method, meta] of Object.entries(methods)) {
    if (method === "parameters") continue;
    const label = meta.summary ?? meta.operationId ?? "";
    rows.push(`- **${method.toUpperCase()}** \`${route}\`${label ? ` — ${label}` : ""}`);
  }
}

if (rows.length <= 4) rows.push("- (no paths found)");

const body = `${rows.join("\n")}\n`;
const outPath = apiSummaryPath(profile);
await mkdir(contextDir(profile), { recursive: true });
await writeFile(outPath, body, "utf8");
console.log(outPath);
console.log(body);
