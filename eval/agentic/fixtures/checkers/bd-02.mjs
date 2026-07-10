#!/usr/bin/env node
import { spawnSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";

const __dir = path.dirname(fileURLToPath(import.meta.url));
const root = process.argv[2] || process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const baseline = process.argv[3] || "";
const args = [
  path.join(__dir, "bd-check.mjs"),
  root,
  "BD-02",
  "BD-02-MARKER:prose-compress",
  "eval/agentic/fixtures/_targets/bd-02-target.md",
];
if (baseline) args.push(baseline);
const r = spawnSync(process.execPath, args, { encoding: "utf8" });
process.stdout.write(r.stdout || "");
process.stderr.write(r.stderr || "");
process.exit(r.status ?? 1);
