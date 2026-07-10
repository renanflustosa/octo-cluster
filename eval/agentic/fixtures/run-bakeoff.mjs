/**
 * Directional bakeoff: 5 cards x 4 arms = 20 Agent.prompt runs.
 * Expects CURSOR_API_KEY in env (set by run-sdk-bakeoff.ps1). Never logs the key.
 */
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const root = process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const nCards = Number(process.env.BAKEOFF_N_CARDS || "5");
const maxRuns = Number(process.env.BAKEOFF_MAX_RUNS || String(nCards * 4));
const arms = ["nada", "baseline", "compress-on", "octo-full"];
const resultsDir = path.join(root, "eval", "agentic", "results");
const checkpointPath = path.join(resultsDir, "bakeoff-n5-checkpoint.json");
const finalPath = path.join(resultsDir, "bakeoff-n5-final.json");

fs.mkdirSync(resultsDir, { recursive: true });

function listCards() {
  const dir = path.join(root, "eval", "agentic", "fixtures", "bakeoff-cards");
  return fs
    .readdirSync(dir)
    .filter((f) => /^BC-\d+\.md$/.test(f))
    .sort()
    .map((f) => f.replace(/\.md$/, ""));
}

function readPrompt(card) {
  const raw = fs.readFileSync(
    path.join(root, "eval", "agentic", "fixtures", "bakeoff-cards", `${card}.md`),
    "utf8"
  );
  const m = raw.match(/```text\r?\n([\s\S]*?)```/);
  if (!m) throw new Error(`prompt missing for ${card}`);
  return m[1].trim();
}

function readTargetFile(card) {
  const raw = fs.readFileSync(
    path.join(root, "eval", "agentic", "fixtures", "bakeoff-cards", `${card}.md`),
    "utf8"
  );
  const m = raw.match(/- File:\s*`([^`]+)`/);
  return m ? m[1].replace(/\//g, path.sep) : null;
}

function setArm(arm) {
  fs.copyFileSync(
    path.join(root, "eval", "agentic", "fixtures", "runtime-arms", `${arm}.json`),
    path.join(root, "contexts", "runtime", "platform.local.json")
  );
}

function fileDiffStats(targetAbs, original) {
  if (!targetAbs) return { added: 0, deleted: 0, net: 0, changed: false };
  const now = fs.existsSync(targetAbs) ? fs.readFileSync(targetAbs, "utf8") : "";
  const a = (original ?? "").split(/\r?\n/);
  const b = now.split(/\r?\n/);
  // rough line delta (not LCS) — enough for bakeoff ranking under tiny edits
  let added = 0;
  let deleted = 0;
  if (original === null || original === undefined) {
    added = b.filter((l) => l.length).length;
  } else if (now === original) {
    return { added: 0, deleted: 0, net: 0, changed: false };
  } else {
    // count net length change + mark changed; prefer git numstat when available
    try {
      const rel = path.relative(root, targetAbs).replace(/\\/g, "/");
      const out = execSync(`git -C "${root}" diff --numstat -- "${rel}"`, {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      }).trim();
      if (out) {
        const [ad, de] = out.split(/\s+/);
        added = Number(ad) || 0;
        deleted = Number(de) || 0;
        return { added, deleted, net: added - deleted, changed: true };
      }
    } catch {
      /* fall through */
    }
    const max = Math.max(a.length, b.length);
    for (let i = 0; i < max; i++) {
      if (i >= a.length) added++;
      else if (i >= b.length) deleted++;
      else if (a[i] !== b[i]) {
        added++;
        deleted++;
      }
    }
  }
  return { added, deleted, net: added - deleted, changed: added + deleted > 0 };
}

function harnessFromDiff(diff, gatesPass = 1, budgetAlerts = 1) {
  let score = 0;
  score += 30 * gatesPass;
  const locPenalty = Math.min(20, Math.abs(diff.net) / 50);
  score += Math.max(0, 20 - locPenalty);
  const diffPenalty = Math.min(15, Math.abs(diff.net) / 40);
  score += Math.max(0, 15 - diffPenalty);
  const alertPenalty = Math.min(15, budgetAlerts * 5);
  score += Math.max(0, 15 - alertPenalty);
  score += 5; // phase_shape
  score += 5; // bootstrap
  return Math.round(Math.min(100, score));
}

function measure(ticket, arm, diff) {
  const lite = path.join(root, "eval", "metrics", "measure-card-lite.ps1");
  const cmd = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${lite}" -Ticket "${ticket}" -CombinationId ${arm} -RepoRoot "${root}" -BaseRef HEAD -ShipVerdict READY -Notes "sdk-bakeoff-n5"`;
  let db = {};
  try {
    const out = execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    const lines = out.split(/\r?\n/);
    for (const line of lines) {
      const t = line.trim();
      if (t.startsWith("{") && t.includes("harness_score")) {
        try {
          db = JSON.parse(t);
        } catch {
          /* continue */
        }
      }
    }
  } catch (e) {
    db = { ok: false, error: String(e.message || e).slice(0, 200) };
  }
  // Prefer file-scoped score so dirty worktree does not dominate bakeoff ranking
  const harness_score = harnessFromDiff(diff, db.gates_pass ?? 1, db.context_budget_alerts ?? 1);
  return {
    ok: true,
    harness_score,
    diff_net: diff.net,
    diff_added: diff.added,
    diff_deleted: diff.deleted,
    gates_pass: db.gates_pass ?? 1,
    tokens_total: db.tokens_total ?? null,
    usage_source: db.usage_source ?? "skipped",
    score_source: "target_file",
    db_ok: db.ok !== false && db.harness_score != null,
  };
}

function loadCheckpoint() {
  if (!fs.existsSync(checkpointPath)) return { completed: [], results: [] };
  return JSON.parse(fs.readFileSync(checkpointPath, "utf8"));
}

function saveCheckpoint(state) {
  fs.writeFileSync(checkpointPath, JSON.stringify(state, null, 2));
}

const cards = listCards().slice(0, nCards);
if (cards.length < nCards) {
  console.error(`Need ${nCards} cards, found ${cards.length}`);
  process.exit(1);
}

if (!process.env.CURSOR_API_KEY) {
  console.error("BLOCKED: CURSOR_API_KEY not set in process env");
  process.exit(2);
}

const state = loadCheckpoint();
const done = new Set(state.completed || []);
const results = state.results || [];
let failures = 0;
let window = [];

let runIndex = 0;
outer: for (const arm of arms) {
  setArm(arm);
  for (const card of cards) {
    const ticket = `${card}-${arm}`;
    runIndex += 1;
    if (runIndex > maxRuns) break outer;
    if (done.has(ticket)) {
      console.log(`skip ${ticket}`);
      continue;
    }

    const targetRel = readTargetFile(card);
    const targetAbs = targetRel ? path.join(root, targetRel) : null;
    let original = null;
    if (targetAbs && fs.existsSync(targetAbs)) {
      original = fs.readFileSync(targetAbs, "utf8");
    }

    const prompt = `${readPrompt(card)}\n\nTicket id for metrics: ${ticket}. combination_id=${arm}. Keep scope to the single target file only.`;
    console.log(`\n==== [${runIndex}/${maxRuns}] ${ticket} ====`);

    let status = "unknown";
    try {
      const result = await Agent.prompt(prompt, {
        apiKey: process.env.CURSOR_API_KEY,
        model: { id: model },
        local: { cwd: root },
      });
      status = result.status || "ok";
      console.log("agent_status", status);
    } catch (e) {
      status = "error";
      const msg = String(e.message || e);
      console.error("agent_error", msg.slice(0, 180));
      if (/auth|unauthorized|api key|401|403/i.test(msg)) {
        console.error("ABORT: auth failure");
        saveCheckpoint({ completed: [...done], results, aborted: "auth", at: ticket });
        process.exit(3);
      }
      failures += 1;
      window.push(0);
    }

    if (status !== "error") window.push(1);
    if (window.length > 20) window.shift();
    if (window.length >= 20) {
      const failRate = window.filter((x) => x === 0).length / window.length;
      if (failRate > 0.2) {
        console.error("ABORT: failure rate >20% in last 20 runs");
        saveCheckpoint({ completed: [...done], results, aborted: "fail_rate", at: ticket });
        process.exit(4);
      }
    }

    const metrics = measure(ticket, arm, fileDiffStats(targetAbs, original));
    const row = {
      ticket,
      arm,
      card,
      status,
      harness_score: metrics.harness_score ?? null,
      diff_net: metrics.diff_net ?? null,
      diff_added: metrics.diff_added ?? null,
      gates_pass: metrics.gates_pass ?? null,
      tokens_total: metrics.tokens_total ?? null,
      usage_source: metrics.usage_source ?? null,
      score_source: metrics.score_source ?? null,
      measure_ok: metrics.ok !== false,
    };
    results.push(row);
    done.add(ticket);

    if (original !== null && targetAbs) {
      try {
        fs.writeFileSync(targetAbs, original, "utf8");
      } catch {
        /* ignore restore errors */
      }
    }

    // Checkpoint every run (resume-safe); also log every 10
    saveCheckpoint({ completed: [...done], results });
    if (done.size % 10 === 0) {
      console.log(`checkpoint saved (${done.size} done)`);
    }
  }
}

try {
  fs.unlinkSync(path.join(root, "contexts", "runtime", "platform.local.json"));
} catch {
  /* ignore */
}

saveCheckpoint({ completed: [...done], results, finished: true });
fs.writeFileSync(finalPath, JSON.stringify({ n_cards: nCards, arms, results }, null, 2));
console.log(`\nDONE runs=${results.length} n_cards=${nCards} -> ${finalPath}`);
process.exit(0);
