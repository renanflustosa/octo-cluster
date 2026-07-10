/**
 * Shared BD checker: marker in allowlisted file + no NEW dirty paths vs baseline.
 * Usage: node bd-check.mjs <root> <cardId> <marker> <allowlistRel> [baselinePorcelainPath]
 * Prints JSON: { pass, reason, dirty_extra }
 */
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const [root, cardId, marker, allowlistRel, baselinePath] = process.argv.slice(2);
if (!root || !cardId || !marker || !allowlistRel) {
  console.log(
    JSON.stringify({
      pass: false,
      reason: "usage: bd-check.mjs <root> <card> <marker> <allowlistRel> [baseline]",
    })
  );
  process.exit(2);
}

function parsePorcelain(text) {
  return text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l) =>
      l
        .replace(/^\?\?\s+/, "")
        .replace(/^[ MADRCU?!]{1,2}\s+/, "")
        .replace(/\\/g, "/")
    )
    .filter(Boolean);
}

function ignorePath(p) {
  return (
    p === "contexts/runtime/platform.local.json" ||
    p === ".cursor" ||
    p.startsWith(".cursor/") ||
    p.startsWith("eval/agentic/results/") ||
    p.startsWith("state/")
  );
}

const allowNorm = allowlistRel.replace(/\\/g, "/");
const targetAbs = path.join(root, ...allowNorm.split("/"));
let pass = true;
const reasons = [];

if (!fs.existsSync(targetAbs)) {
  pass = false;
  reasons.push("target_missing");
} else {
  const text = fs.readFileSync(targetAbs, "utf8");
  if (!text.includes(marker)) {
    pass = false;
    reasons.push("marker_missing");
  }
}

let baseline = new Set();
if (baselinePath && fs.existsSync(baselinePath)) {
  baseline = new Set(parsePorcelain(fs.readFileSync(baselinePath, "utf8")).filter((p) => !ignorePath(p)));
}

let dirtyExtra = [];
try {
  const out = execSync(`git -C "${root}" status --porcelain`, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  const now = parsePorcelain(out).filter((p) => !ignorePath(p));
  dirtyExtra = now.filter((p) => p !== allowNorm && !baseline.has(p));
  if (dirtyExtra.length) {
    pass = false;
    reasons.push("extra_dirty");
  }
} catch {
  reasons.push("git_status_failed");
}

const result = {
  pass,
  card: cardId,
  reason: reasons.join(",") || "ok",
  dirty_extra: dirtyExtra,
};
console.log(JSON.stringify(result));
process.exit(pass ? 0 : 1);
