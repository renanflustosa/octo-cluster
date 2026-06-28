import { spawnSync } from "node:child_process";
import { relative } from "node:path";

const repoRoot = process.argv[2] ?? process.cwd();
const base = process.argv.includes("--base")
  ? process.argv[process.argv.indexOf("--base") + 1]
  : "develop";
const maxLines = Number(
  process.argv.includes("--max")
    ? process.argv[process.argv.indexOf("--max") + 1]
    : 300,
);

const diff = spawnSync(
  "git",
  ["diff", `${base}...HEAD`, "--unified=3", "--no-color"],
  { cwd: repoRoot, encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
);

if (diff.status !== 0 && !diff.stdout) {
  const unstaged = spawnSync(
    "git",
    ["diff", "--unified=3", "--no-color"],
    { cwd: repoRoot, encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
  );
  if (!unstaged.stdout?.trim()) {
    console.log("No diff available.");
    process.exit(0);
  }
  printDiff(unstaged.stdout, repoRoot, maxLines);
  process.exit(0);
}

printDiff(diff.stdout ?? "", repoRoot, maxLines);

function printDiff(text: string, root: string, limit: number) {
  const lines = text.split("\n");
  const files = new Set<string>();
  for (const line of lines) {
    const m = line.match(/^diff --git a\/(.+?) b\//);
    if (m) files.add(m[1]);
  }

  console.log(`# Diff context (${files.size} files, cap ${limit} lines)\n`);
  console.log(`Repo: ${root}`);
  console.log(`Files: ${[...files].slice(0, 10).join(", ")}${files.size > 10 ? "…" : ""}\n`);

  const clipped = lines.slice(0, limit).join("\n");
  console.log(clipped);
  if (lines.length > limit) {
    console.log(`\n…[${lines.length - limit} diff lines omitted — use Read on flagged hunks only]`);
  }
}
