/**
 * Phase 0 smoke: 1 SDK run + usage API delta (WorkosCursorSessionToken).
 * Never logs API key or session token.
 */
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const root = process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const resultsDir = path.join(root, "eval", "agentic", "results");
const outPath = path.join(resultsDir, "smoke-phase0-run1.json");

fs.mkdirSync(resultsDir, { recursive: true });

function psJson(cmd, { allowFail = false } = {}) {
  try {
    const out = execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    const line = out
      .split(/\r?\n/)
      .map((l) => l.trim())
      .find((l) => l.startsWith("{"));
    return line ? JSON.parse(line) : { ok: false, raw: out.slice(0, 300) };
  } catch (e) {
    const combined = String(e.stdout || "") + String(e.stderr || "") + String(e.message || e);
    const line = combined
      .split(/\r?\n/)
      .map((l) => l.trim())
      .find((l) => l.startsWith("{"));
    if (line) {
      try {
        return JSON.parse(line);
      } catch {
        /* fall through */
      }
    }
    if (allowFail) return { ok: false, error: combined.slice(0, 300) };
    return { ok: false, error: combined.slice(0, 300) };
  }
}

function readJsonFile(p) {
  let raw = fs.readFileSync(p, "utf8");
  if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
  return JSON.parse(raw);
}

function readBaseline() {
  const p = path.join(root, "state", "memory", "octo-cluster", "usage-baseline.json");
  if (fs.existsSync(p)) return readJsonFile(p);
  return { started_at_ms: Date.now() - 5000 };
}

function stampBaseline(ticket) {
  const stamp = path.join(root, "eval", "metrics", "stamp-usage-baseline.ps1");
  execSync(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${stamp}" -Ticket "${ticket}" -Profile octo-cluster`,
    { stdio: "inherit" }
  );
  return readBaseline();
}

function usageSince(sinceMs) {
  const usage = path.join(root, "eval", "metrics", "cursor-usage.ps1");
  return psJson(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${usage}" -SinceMs ${sinceMs}`
  );
}

function sessionProbe() {
  const probe = path.join(root, "eval", "metrics", "cursor-session.ps1");
  if (!fs.existsSync(probe)) return { ok: false, error: "cursor-session.ps1 missing" };
  return psJson(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${probe}" -Json -Redact`
  );
}

if (!process.env.CURSOR_API_KEY) {
  console.error("BLOCKED: CURSOR_API_KEY not set");
  process.exit(2);
}

const ticket = "smoke-phase0-run1";
console.log("\n=== Phase 0 smoke: run 1 ===\n");

const session = sessionProbe();
console.log(
  "session_token:",
  session.ok ? "present" : "missing",
  session.source || session.error || ""
);

const baselineBefore = usageSince(0);
console.log(
  "usage_probe:",
  baselineBefore.ok ? `events=${baselineBefore.events}` : baselineBefore.error || "failed"
);

console.log("\n[1/4] stamp baseline...");
const baseline = stampBaseline(ticket);
const sinceMs = Number(baseline.started_at_ms || Date.now());
console.log("since_ms:", sinceMs);

const prompt =
  "SMOKE-PHASE0: Reply with exactly one short English sentence confirming you received this smoke test. Do not edit any files. Do not use tools unless required.";

console.log("\n[2/4] Agent.prompt (settingSources=[] default)...");
const t0 = Date.now();
let agent = { status: "error", assistant_chars: 0, run_duration_ms: 0 };
try {
  const result = await Agent.prompt(prompt, {
    apiKey: process.env.CURSOR_API_KEY,
    model: { id: model },
    local: { cwd: root, settingSources: [] },
  });
  const text = typeof result.result === "string" ? result.result : JSON.stringify(result.result ?? "");
  agent = {
    status: result.status || "unknown",
    assistant_chars: text.length,
    run_duration_ms: Date.now() - t0,
    run_id: result.id ?? null,
  };
  console.log("agent_status:", agent.status, "assistant_chars:", agent.assistant_chars);
} catch (e) {
  agent = {
    status: "error",
    error: String(e.message || e).slice(0, 200),
    run_duration_ms: Date.now() - t0,
  };
  console.error("agent_error:", agent.error);
}

// brief pause for dashboard ingestion
await new Promise((r) => setTimeout(r, 3000));

console.log("\n[3/4] usage delta since baseline...");
const usageAfter = usageSince(sinceMs);

console.log("\n[4/4] summary");
const report = {
  ticket,
  model,
  since_ms: sinceMs,
  session_ok: !!session.ok,
  session_source: session.source ?? null,
  agent,
  usage_delta: usageAfter,
  tokens_attributed: usageAfter.ok && (usageAfter.tokens_total ?? 0) > 0,
  conclusion:
    usageAfter.ok && (usageAfter.tokens_total ?? 0) > 0
      ? "SDK run appears in dashboard usage API"
      : "SDK run NOT attributed via WorkosCursorSessionToken (use assistant_chars fallback)",
};
console.log(JSON.stringify(report, null, 2));
fs.writeFileSync(outPath, JSON.stringify(report, null, 2));
console.log("\nWrote", outPath);
process.exit(agent.status === "finished" ? 0 : agent.status === "error" ? 1 : 0);
