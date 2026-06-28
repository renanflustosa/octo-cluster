import { stat } from "node:fs/promises";
import { relative } from "node:path";

const BLOCKED = [
  "node_modules",
  "/dist/",
  "/build/",
  "/coverage",
  "/.next/",
  "/vendor/",
  "@mf-types",
  "/generated/",
];

const limits = {
  maxFiles: 3,
  maxLines: 300,
  maxChunks: 5,
  maxLogTokens: 200,
  maxTicketTokens: 300,
};

const paths = process.argv.slice(2);
if (paths.length === 0) {
  console.log(JSON.stringify({ ok: true, limits, checked: 0 }, null, 2));
  process.exit(0);
}

const violations: string[] = [];

if (paths.length > limits.maxFiles) {
  violations.push(`Too many paths (${paths.length} > ${limits.maxFiles})`);
}

for (const p of paths) {
  const norm = p.replace(/\\/g, "/");
  if (BLOCKED.some((b) => norm.includes(b))) {
    violations.push(`Blocked path: ${p}`);
  }
}

console.log(
  JSON.stringify(
    {
      ok: violations.length === 0,
      limits,
      violations,
      policy: "grep → semantic search → top-3 chunks → read ≤300 lines → edit",
    },
    null,
    2,
  ),
);

process.exit(violations.length === 0 ? 0 : 1);
