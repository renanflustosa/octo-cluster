#Requires -Version 5.1
<#
.SYNOPSIS
  Best-effort: run 20 real local agents via Cursor SDK (needs CURSOR_API_KEY).

.NOTES
  Install: npm i -g @cursor/sdk   OR   npx --yes @cursor/sdk (if package exposes CLI — prefer node script)
  This script writes a Node runner and executes it when node + key are available.
#>
param(
    [string]$Model = 'composer-2.5'
)

$ErrorActionPreference = 'Stop'
$root = 'C:\octo-cluster'
if (-not $env:CURSOR_API_KEY) {
    Write-Host @'
BLOCKED: CURSOR_API_KEY not set.

Real 20-agent automation needs a Cursor API key:
  1) Create a key in the Cursor dashboard
  2) $env:CURSOR_API_KEY = "..."   (User env for persistence)
  3) Re-run: pwsh eval/agentic/fixtures/run-real-20-sdk.ps1

Until then use the manual path:
  docs: eval/agentic/fixtures/REAL-20-CHATS.md
  helper: pwsh eval/agentic/fixtures/prepare-bakeoff-chat.ps1 -Arm nada -Card BC-01
'@ -ForegroundColor Yellow
    exit 2
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Host 'node not found — required for @cursor/sdk runner' -ForegroundColor Red
    exit 1
}

$runnerDir = Join-Path $root 'eval\agentic\fixtures\_sdk-runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
Set-Location $runnerDir

if (-not (Test-Path 'node_modules\@cursor\sdk')) {
    Write-Host 'Installing @cursor/sdk locally...' -ForegroundColor Cyan
    npm init -y 2>$null | Out-Null
    npm install @cursor/sdk@latest --no-fund --no-audit
}

$js = @'
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const root = process.env.OCTO_CLUSTER || "C:\\\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const arms = ["nada", "baseline", "compress-on", "octo-full"];
const cards = ["BC-01", "BC-02", "BC-03", "BC-04", "BC-05"];

function readPrompt(card) {
  const raw = fs.readFileSync(path.join(root, "eval/agentic/fixtures/bakeoff-cards", `${card}.md`), "utf8");
  const m = raw.match(/```text\\r?\\n([\\s\\S]*?)```/);
  if (!m) throw new Error("prompt missing " + card);
  return m[1].trim();
}

function setArm(arm) {
  const src = path.join(root, "eval/agentic/fixtures/runtime-arms", `${arm}.json`);
  const dst = path.join(root, "contexts/runtime/platform.local.json");
  fs.copyFileSync(src, dst);
}

function measure(ticket, arm) {
  const cmd = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${path.join(root, "eval/metrics/measure-card-lite.ps1")}" -Ticket "${ticket}" -CombinationId ${arm} -RepoRoot "${root}" -BaseRef HEAD -ShipVerdict READY`;
  try { execSync(cmd, { stdio: "inherit" }); } catch (e) { console.error("measure failed", ticket, e.message); }
}

const results = [];
for (const arm of arms) {
  setArm(arm);
  for (const card of cards) {
    const ticket = `${card}-${arm}`;
    const prompt = readPrompt(card) + `\\n\\nTicket id for close/metrics: ${ticket}. combination_id=${arm}. Keep scope to the single target file.`;
    console.log("\\n====", ticket, "====");
    const result = await Agent.prompt(prompt, {
      apiKey: process.env.CURSOR_API_KEY,
      model: { id: model },
      local: { cwd: root },
    });
    console.log("status", result.status);
    measure(ticket, arm);
    results.push({ ticket, arm, status: result.status });
  }
}

fs.writeFileSync(path.join(root, "eval/agentic/results/2026-07-10-real-20-sdk.json"), JSON.stringify(results, null, 2));
console.log("done", results.length);
'@

# Fix escaping for actual JS file - write properly without double escapes
$jsClean = @'
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const root = process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const arms = ["nada", "baseline", "compress-on", "octo-full"];
const cards = ["BC-01", "BC-02", "BC-03", "BC-04", "BC-05"];

function readPrompt(card) {
  const raw = fs.readFileSync(path.join(root, "eval/agentic/fixtures/bakeoff-cards", `${card}.md`), "utf8");
  const m = raw.match(/```text\r?\n([\s\S]*?)```/);
  if (!m) throw new Error("prompt missing " + card);
  return m[1].trim();
}

function setArm(arm) {
  fs.copyFileSync(
    path.join(root, "eval/agentic/fixtures/runtime-arms", `${arm}.json`),
    path.join(root, "contexts/runtime/platform.local.json")
  );
}

function measure(ticket, arm) {
  const lite = path.join(root, "eval/metrics/measure-card-lite.ps1");
  const cmd = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${lite}" -Ticket "${ticket}" -CombinationId ${arm} -RepoRoot "${root}" -BaseRef HEAD -ShipVerdict READY`;
  try { execSync(cmd, { stdio: "inherit" }); } catch (e) { console.error("measure failed", ticket, e.message); }
}

const results = [];
for (const arm of arms) {
  setArm(arm);
  for (const card of cards) {
    const ticket = `${card}-${arm}`;
    const prompt = `${readPrompt(card)}\n\nTicket id for close/metrics: ${ticket}. combination_id=${arm}. Keep scope to the single target file.`;
    console.log("\n====", ticket, "====");
    const result = await Agent.prompt(prompt, {
      apiKey: process.env.CURSOR_API_KEY,
      model: { id: model },
      local: { cwd: root },
    });
    console.log("status", result.status);
    measure(ticket, arm);
    results.push({ ticket, arm, status: result.status });
  }
}

fs.mkdirSync(path.join(root, "eval/agentic/results"), { recursive: true });
fs.writeFileSync(path.join(root, "eval/agentic/results/real-20-sdk.json"), JSON.stringify(results, null, 2));
console.log("done", results.length);
'@

Set-Content -Path (Join-Path $runnerDir 'run-20.mjs') -Value $jsClean -Encoding UTF8
$env:OCTO_CLUSTER = $root
node (Join-Path $runnerDir 'run-20.mjs')
