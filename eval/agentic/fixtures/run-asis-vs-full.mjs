/**
 * Binary bakeoff: Cursor AS-IS vs Octo-Full — paired cards × 2 arms.
 * Primary metrics: harness_score + tokens_total (usage API via vault session).
 * Enforce: platform.local.json + .cursor swap + settingSources.
 * Order: ABAB per card (card outer loop). Never logs API key or session token.
 */
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { createHash } from "crypto";

const root = process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const phase = Number(process.env.BAKEOFF_PHASE || "3");
const sample = process.env.BAKEOFF_SAMPLE || "n3";
const pauseMs = Number(process.env.BAKEOFF_PAUSE_MS || "30000");
const interCardMs = Number(process.env.BAKEOFF_INTER_CARD_MS || "60000");
const armsEnv = (process.env.BAKEOFF_ARMS || "asis,full").split(",").map((s) => s.trim());
const resultsDir = path.join(root, "eval", "agentic", "results");
const checkpointPath = path.join(resultsDir, `bakeoff-asis-vs-full-${sample}-checkpoint.json`);
const finalPath = path.join(resultsDir, `bakeoff-asis-vs-full-${sample}-final.json`);
const cursorDir = path.join(root, ".cursor");
const cursorSnap = path.join(resultsDir, ".cursor-snapshot-asis-vs-full");
const emptyBundle = path.join(root, "eval", "agentic", "fixtures", "cursor-bundles", "empty");
const cardsDir = path.join(root, "eval", "agentic", "fixtures", "bakeoff-cards-v2");

if (!process.env.PERSONAL_VAULT) {
  /* resolved by cursor_session.py from env or sibling vault */
}

const ARM_CFG = {
  asis: {
    overlay: "nada",
    measureArm: "nada",
    settingSources: [],
    expectCombination: "nada",
    cursorMode: "empty",
  },
  full: {
    overlay: "octo-full",
    measureArm: "octo-full",
    settingSources: ["project"],
    expectCombination: "octo-full",
    cursorMode: "real",
  },
};

const CARD_META = {
  "BD-01": {
    target: "eval/agentic/fixtures/_targets/bd-01-target.md",
    checker: "bd-01.mjs",
  },
  "BD-02": {
    target: "eval/agentic/fixtures/_targets/bd-02-target.md",
    checker: "bd-02.mjs",
  },
  "BD-03": {
    target: "docs/adr/ADR-005-okf-session-index.md",
    checker: "bd-03.mjs",
  },
  "BD-04": {
    target: "eval/agentic/fixtures/_targets/bd-04-target.md",
    checker: "bd-04.mjs",
  },
  "BD-05": {
    target: "eval/agentic/fixtures/_targets/bd-05-target.md",
    checker: "bd-05.mjs",
  },
};

fs.mkdirSync(resultsDir, { recursive: true });

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function listCards() {
  if (phase === 2) return ["BD-02"];
  const force = process.env.BAKEOFF_CARDS;
  if (force) return force.split(",").map((s) => s.trim()).filter(Boolean);
  const all = fs
    .readdirSync(cardsDir)
    .filter((f) => /^BD-\d+\.md$/.test(f))
    .sort()
    .map((f) => f.replace(/\.md$/, ""));
  const n = Number(process.env.BAKEOFF_N_CARDS || "0");
  if (n > 0) return all.slice(0, n);
  return all;
}

function cardArmOrder(cardIndex) {
  const first = cardIndex % 2 === 0 ? "asis" : "full";
  const second = first === "asis" ? "full" : "asis";
  return [first, second];
}

function readPrompt(card) {
  const raw = fs.readFileSync(path.join(cardsDir, `${card}.md`), "utf8");
  const m = raw.match(/```text\r?\n([\s\S]*?)```/);
  if (!m) throw new Error(`prompt missing for ${card}`);
  return m[1].trim();
}

function rmrf(p) {
  if (!fs.existsSync(p)) return;
  fs.rmSync(p, { recursive: true, force: true });
}

function cpr(src, dest) {
  fs.cpSync(src, dest, { recursive: true });
}

function ensureCursorSnapshot() {
  if (fs.existsSync(cursorSnap)) return;
  if (!fs.existsSync(cursorDir)) throw new Error(".cursor missing");
  console.log("snapshot .cursor ->", cursorSnap);
  cpr(cursorDir, cursorSnap);
}

function applyCursor(mode) {
  ensureCursorSnapshot();
  rmrf(cursorDir);
  if (mode === "empty") {
    cpr(emptyBundle, cursorDir);
    fs.mkdirSync(path.join(cursorDir, "rules"), { recursive: true });
    fs.mkdirSync(path.join(cursorDir, "skills"), { recursive: true });
  } else {
    cpr(cursorSnap, cursorDir);
  }
}

function restoreCursor() {
  if (!fs.existsSync(cursorSnap)) return;
  rmrf(cursorDir);
  cpr(cursorSnap, cursorDir);
}

function setArmOverlay(overlayId) {
  fs.copyFileSync(
    path.join(root, "eval", "agentic", "fixtures", "runtime-arms", `${overlayId}.json`),
    path.join(root, "contexts", "runtime", "platform.local.json")
  );
}

function prepareArm(arm) {
  const cfg = ARM_CFG[arm];
  setArmOverlay(cfg.overlay);
  applyCursor(cfg.cursorMode);
  return cfg;
}

function resolveCombination() {
  try {
    const out = execSync(
      `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${path.join(root, "domains", "core", "scripts", "resolve-execution-context.ps1")}"`,
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
    );
    const m = out.match(/"combination_id"\s*:\s*"([^"]+)"/);
    return m ? m[1] : null;
  } catch {
    return null;
  }
}

function hashRulesDir() {
  const rules = path.join(cursorDir, "rules");
  if (!fs.existsSync(rules)) return "none";
  const names = fs.readdirSync(rules).filter((f) => f.endsWith(".mdc")).sort();
  const h = createHash("sha256");
  h.update(names.join("|"));
  for (const n of names) h.update(fs.readFileSync(path.join(rules, n)));
  return `${names.length}:${h.digest("hex").slice(0, 12)}`;
}

function enforceOk(arm) {
  const cfg = ARM_CFG[arm];
  const combo = resolveCombination();
  const rulesHash = hashRulesDir();
  const hasCaveman = fs.existsSync(path.join(cursorDir, "rules", "caveman-mode.mdc"));
  let ok = true;
  const reasons = [];
  if (combo !== cfg.expectCombination) {
    ok = false;
    reasons.push(`combo=${combo} want=${cfg.expectCombination}`);
  }
  if (arm === "asis" && hasCaveman) {
    ok = false;
    reasons.push("asis_has_caveman");
  }
  if (arm === "full" && !hasCaveman) {
    ok = false;
    reasons.push("full_missing_caveman");
  }
  return { enforce_ok: ok, combination_id: combo, rules_hash: rulesHash, reasons };
}

function fileDiffStats(targetAbs, original) {
  if (!targetAbs) return { added: 0, deleted: 0, net: 0, patch_chars: 0 };
  const now = fs.existsSync(targetAbs) ? fs.readFileSync(targetAbs, "utf8") : "";
  const patch_chars = Math.abs((now?.length || 0) - (original?.length || 0));
  if (original == null) {
    return { added: now.split(/\r?\n/).filter(Boolean).length, deleted: 0, net: 0, patch_chars };
  }
  if (now === original) return { added: 0, deleted: 0, net: 0, patch_chars: 0 };
  try {
    const rel = path.relative(root, targetAbs).replace(/\\/g, "/");
    const out = execSync(`git -C "${root}" diff --numstat -- "${rel}"`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
    if (out) {
      const [ad, de] = out.split(/\s+/);
      const added = Number(ad) || 0;
      const deleted = Number(de) || 0;
      return { added, deleted, net: added - deleted, patch_chars };
    }
  } catch {
    /* fall through */
  }
  return { added: 1, deleted: 0, net: 1, patch_chars };
}

/** ADR-006 lite weights; LOC scoped to target file (dirty worktree safe). */
function harnessScoreLite({ tokensTotal, diffNet, gatesPass = 1, budgetAlerts = 0 }) {
  let score = 30 * gatesPass;
  if (tokensTotal != null && !Number.isNaN(Number(tokensTotal))) {
    score += Math.max(0, 20 - Math.min(20, Math.floor(Number(tokensTotal) / 5000)));
  } else {
    score += Math.max(0, 20 - Math.min(20, Math.abs(diffNet) / 50));
  }
  score += Math.max(0, 15 - Math.min(15, Math.abs(diffNet) / 40));
  score += Math.max(0, 15 - Math.min(15, budgetAlerts * 5));
  score += 10;
  return Math.round(Math.min(100, score));
}

function pickMeasureJson(text) {
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.startsWith("{"));
  const card = [...lines].reverse().find((l) => l.includes("harness_score") || l.includes("tokens_total"));
  if (card) {
    try {
      return JSON.parse(card);
    } catch {
      /* fall */
    }
  }
  for (const l of lines) {
    try {
      return JSON.parse(l);
    } catch {
      /* continue */
    }
  }
  return { ok: false, error: "no_json" };
}

function psJson(cmd) {
  try {
    const out = execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    return pickMeasureJson(out);
  } catch (e) {
    const combined = String(e.stdout || "") + String(e.stderr || "") + String(e.message || e);
    const parsed = pickMeasureJson(combined);
    if (parsed && !parsed.error) return parsed;
    return { ok: false, error: combined.slice(0, 120) };
  }
}

function writeStatusBaseline(ticket) {
  const p = path.join(resultsDir, `status-baseline-${ticket}.txt`);
  try {
    fs.writeFileSync(
      p,
      execSync(`git -C "${root}" status --porcelain`, {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      })
    );
  } catch {
    fs.writeFileSync(p, "");
  }
  return p;
}

function runChecker(card, baselinePath) {
  const meta = CARD_META[card];
  if (!meta) return { pass: false, reason: "unknown_card" };
  const script = path.join(root, "eval", "agentic", "fixtures", "checkers", meta.checker);
  try {
    const out = execSync(`node "${script}" "${root}" "${baselinePath}"`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return JSON.parse(out.trim().split(/\r?\n/).pop());
  } catch (e) {
    try {
      return JSON.parse(String(e.stdout || "").trim().split(/\r?\n/).pop());
    } catch {
      return { pass: false, reason: String(e.message || e).slice(0, 120) };
    }
  }
}

function stampBaseline(ticket) {
  const stamp = path.join(root, "eval", "metrics", "stamp-usage-baseline.ps1");
  execSync(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${stamp}" -Ticket "${ticket}" -Profile octo-cluster`,
    { stdio: "ignore", env: { ...process.env, PERSONAL_VAULT: process.env.PERSONAL_VAULT } }
  );
  const baselinePath = path.join(root, "state", "memory", "octo-cluster", "usage-baseline.json");
  try {
    const b = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
    return Number(b.started_at_ms) || Date.now();
  } catch {
    return Date.now();
  }
}

function usageDelta(sinceMs) {
  const usage = path.join(root, "eval", "metrics", "cursor-usage.ps1");
  return pickMeasureJson(
    (() => {
      try {
        return execSync(
          `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${usage}" -SinceMs ${sinceMs}`,
          {
            encoding: "utf8",
            stdio: ["ignore", "pipe", "pipe"],
            env: { ...process.env, PERSONAL_VAULT: process.env.PERSONAL_VAULT },
          }
        );
      } catch (e) {
        return String(e.stdout || "") + String(e.stderr || "");
      }
    })()
  );
}

function loadCheckpoint() {
  if (!fs.existsSync(checkpointPath)) return { completed: [], results: [] };
  return JSON.parse(fs.readFileSync(checkpointPath, "utf8"));
}

function saveCheckpoint(state) {
  fs.writeFileSync(checkpointPath, JSON.stringify(state, null, 2));
}

function cleanupOverlay() {
  try {
    fs.unlinkSync(path.join(root, "contexts", "runtime", "platform.local.json"));
  } catch {
    /* ignore */
  }
}

function sessionProbe() {
  const probe = path.join(root, "eval", "metrics", "cursor-session.ps1");
  return psJson(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${probe}" -Json -Redact`
  );
}

const cards = listCards();
const arms = armsEnv.filter((a) => ARM_CFG[a]);
if (!arms.length) {
  console.error("No valid arms");
  process.exit(1);
}
if (!process.env.CURSOR_API_KEY) {
  console.error("BLOCKED: CURSOR_API_KEY not set");
  process.exit(2);
}

const session = sessionProbe();
console.log("session_token:", session.ok ? "present" : "missing", session.source || session.error || "");
if (!session.ok) {
  console.error("ABORT: WorkosCursorSessionToken required (vault/env). tokens gate.");
  process.exit(6);
}

const maxRuns = Number(process.env.BAKEOFF_MAX_RUNS || String(cards.length * arms.length));
console.log(
  `ASIS-vs-FULL sample=${sample} phase=${phase} cards=${cards.join(",")} arms=${arms.join(",")} ` +
    `max=${maxRuns} pause_ms=${pauseMs} inter_card_ms=${interCardMs} order=abab_by_card`
);

ensureCursorSnapshot();

const state = loadCheckpoint();
const done = new Set(state.completed || []);
const results = state.results || [];
let failures = 0;
let runIndex = 0;

async function runOneTicket(arm, card) {
  const ticket = `${card}-${arm}`;
  const cfg = prepareArm(arm);
  const meta = CARD_META[card];
  if (!meta) throw new Error(`CARD_META missing for ${card}`);

  const targetAbs = path.join(root, ...meta.target.split("/"));
  let original = null;
  if (fs.existsSync(targetAbs)) original = fs.readFileSync(targetAbs, "utf8");

  const enf = enforceOk(arm);
  console.log(`\n==== [${runIndex}/${maxRuns}] ${ticket} enforce_ok=${enf.enforce_ok} ====`);
  if (!enf.enforce_ok) console.warn("enforce reasons:", enf.reasons.join("; "));

  const sinceMs = stampBaseline(ticket);
  const statusBaseline = writeStatusBaseline(ticket);

  const prompt = `${readPrompt(card)}\n\nTicket id for metrics: ${ticket}. arm=${arm}. Keep scope to the allowlisted target only.`;
  let status = "unknown";
  let assistant_chars = 0;
  let run_duration_ms = 0;
  const t0 = Date.now();
  try {
    const result = await Agent.prompt(prompt, {
      apiKey: process.env.CURSOR_API_KEY,
      model: { id: model },
      local: { cwd: root, settingSources: cfg.settingSources },
    });
    status = result.status || "ok";
    const text =
      typeof result.result === "string" ? result.result : JSON.stringify(result.result ?? "");
    assistant_chars = text.length;
    run_duration_ms = Date.now() - t0;
    console.log("agent_status", status, "assistant_chars", assistant_chars);
  } catch (e) {
    status = "error";
    run_duration_ms = Date.now() - t0;
    const msg = String(e.message || e);
    console.error("agent_error", msg.slice(0, 180));
    if (/auth|unauthorized|api key|401|403/i.test(msg)) {
      saveCheckpoint({ completed: [...done], results, aborted: "auth", at: ticket });
      restoreCursor();
      cleanupOverlay();
      process.exit(3);
    }
    failures += 1;
  }

  const failRate = failures / Math.max(1, results.length + 1);
  if (results.length + 1 >= 3 && failRate > 0.2) {
    console.error("ABORT: fail rate >20%");
    saveCheckpoint({ completed: [...done], results, aborted: "fail_rate", at: ticket });
    restoreCursor();
    cleanupOverlay();
    process.exit(4);
  }

  const diff = fileDiffStats(targetAbs, original);
  const check = runChecker(card, statusBaseline);
  const pass = !!check.pass;

  console.log(`pause ${pauseMs}ms before usage poll...`);
  await sleep(pauseMs);

  let tokens_total = null;
  let tokens_input = null;
  let tokens_output = null;
  let tokens_cache_read = null;
  let usage_source = "skipped";
  let usage = {};
  for (let attempt = 0; attempt < 4; attempt++) {
    if (attempt > 0) await sleep(attempt === 1 ? 4000 : 5000);
    usage = usageDelta(sinceMs);
    usage_source = usage.ok ? "api" : String(usage.error || "error").slice(0, 40);
    if (usage.ok && Number(usage.tokens_total) > 0) {
      tokens_total = Number(usage.tokens_total);
      tokens_input = usage.tokens_input != null ? Number(usage.tokens_input) : null;
      tokens_output = usage.tokens_output != null ? Number(usage.tokens_output) : null;
      tokens_cache_read =
        usage.tokens_cache_read != null ? Number(usage.tokens_cache_read) : null;
      break;
    }
  }

  const harness_score = pass
    ? harnessScoreLite({
        tokensTotal: tokens_total,
        diffNet: diff.net,
        gatesPass: 1,
        budgetAlerts: 0,
      })
    : null;

  console.log(
    `metrics tokens=${tokens_total} in=${tokens_input} out=${tokens_output} cache=${tokens_cache_read} ` +
      `harness_score=${harness_score} usage_source=${usage_source} pass=${pass}`
  );

  const row = {
    ticket,
    arm,
    card,
    status,
    pass,
    assistant_chars,
    run_duration_ms,
    diff_net: diff.net,
    diff_added: diff.added,
    patch_chars: diff.patch_chars,
    tokens_total,
    tokens_input,
    tokens_output,
    tokens_cache_read,
    usage_source,
    harness_score,
    enforce_ok: enf.enforce_ok,
    enforce: enf,
    checker: check,
  };
  results.push(row);
  done.add(ticket);

  if (original !== null && targetAbs) {
    try {
      fs.writeFileSync(targetAbs, original, "utf8");
    } catch {
      /* ignore */
    }
  }

  saveCheckpoint({ completed: [...done], results, phase, sample });
  return row;
}

try {
  outer: for (let cardIdx = 0; cardIdx < cards.length; cardIdx++) {
    const card = cards[cardIdx];
    const armOrder = cardArmOrder(cardIdx);
    let lastRow = null;

    for (const arm of armOrder) {
      if (!arms.includes(arm)) continue;
      const ticket = `${card}-${arm}`;
      runIndex += 1;
      if (runIndex > maxRuns) break outer;
      if (done.has(ticket)) {
        console.log(`skip ${ticket}`);
        lastRow = results.find((r) => r.ticket === ticket) || lastRow;
        continue;
      }
      lastRow = await runOneTicket(arm, card);
    }

    if (cardIdx < cards.length - 1 && runIndex < maxRuns) {
      const fragile =
        lastRow &&
        (lastRow.tokens_total == null || lastRow.usage_source !== "api" || lastRow.tokens_total > 80000);
      const waitMs = fragile ? interCardMs : Math.min(interCardMs, pauseMs);
      console.log(`inter-card pause ${waitMs}ms after ${card}...`);
      await sleep(waitMs);
    }
  }

  if (phase === 2) {
    const asis = results.find((r) => r.arm === "asis" && r.card === "BD-02");
    const full = results.find((r) => r.arm === "full" && r.card === "BD-02");
    if (asis && full) {
      if (asis.tokens_total == null || full.tokens_total == null) {
        console.error("ABORT phase2: tokens_total null — usage regressed");
        fs.writeFileSync(
          finalPath,
          JSON.stringify(
            { sample, n_cards: 1, arms, phase: 2, aborted: "tokens_null", results },
            null,
            2
          )
        );
        restoreCursor();
        cleanupOverlay();
        process.exit(6);
      }
      const scoreTie = asis.harness_score === full.harness_score;
      const tokTie = asis.tokens_total === full.tokens_total;
      const passTie = asis.pass === full.pass;
      const diffTie = asis.diff_net === full.diff_net;
      if (scoreTie && tokTie && passTie && diffTie) {
        console.error("ABORT phase2: primary signals tied — review enforce");
        fs.writeFileSync(
          finalPath,
          JSON.stringify(
            { sample, n_cards: 1, arms, phase: 2, aborted: "phase2_tie", results },
            null,
            2
          )
        );
        restoreCursor();
        cleanupOverlay();
        process.exit(5);
      }
      console.log(
        `phase2 gate OK: score ${asis.harness_score}/${full.harness_score} tokens ${asis.tokens_total}/${full.tokens_total}`
      );
    }
  }

  const nullTok = results.filter((r) => r.tokens_total == null);
  if (nullTok.length) {
    console.warn(`WARN: ${nullTok.length} runs missing tokens_total`);
  }

  fs.writeFileSync(
    finalPath,
    JSON.stringify(
      {
        sample,
        n_cards: cards.length,
        arms,
        phase,
        model,
        run_date: new Date().toISOString().slice(0, 10),
        pause_ms: pauseMs,
        inter_card_ms: interCardMs,
        order_mode: "abab_by_card",
        results,
        directional: true,
        promote: false,
        primary_metrics: ["harness_score", "tokens_total"],
      },
      null,
      2
    )
  );
  console.log(`\nDONE runs=${results.length} -> ${finalPath}`);
} finally {
  restoreCursor();
  cleanupOverlay();
}

process.exit(0);
