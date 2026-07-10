/**
 * Binary bakeoff: COM (compress-on) vs SEM (nada) — N=3 cards × 2 arms = 6 runs.
 * Enforce: platform.local.json overlay + .cursor bundle swap + settingSources.
 * Never logs API key or session token.
 */
import { Agent } from "@cursor/sdk";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { createHash } from "crypto";

const root = process.env.OCTO_CLUSTER || "C:\\octo-cluster";
const model = process.env.BAKEOFF_MODEL || "composer-2.5";
const phase = Number(process.env.BAKEOFF_PHASE || "3"); // 2 = BD-02 gate only; 3 = full 6
const armsEnv = (process.env.BAKEOFF_ARMS || "sem,com").split(",").map((s) => s.trim());
const resultsDir = path.join(root, "eval", "agentic", "results");
const checkpointPath = path.join(resultsDir, "bakeoff-com-vs-sem-n3-checkpoint.json");
const finalPath = path.join(resultsDir, "bakeoff-com-vs-sem-n3-final.json");
const cursorDir = path.join(root, ".cursor");
const cursorSnap = path.join(resultsDir, ".cursor-snapshot-com-vs-sem");
const emptyBundle = path.join(root, "eval", "agentic", "fixtures", "cursor-bundles", "empty");
const cardsDir = path.join(root, "eval", "agentic", "fixtures", "bakeoff-cards-v2");

const ARM_CFG = {
  sem: {
    overlay: "nada",
    settingSources: [],
    expectCombination: "nada",
    cursorMode: "empty",
  },
  com: {
    overlay: "compress-on",
    settingSources: ["project"],
    expectCombination: "compress-on",
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
};

fs.mkdirSync(resultsDir, { recursive: true });

function listCards() {
  if (phase === 2) return ["BD-02"];
  const force = process.env.BAKEOFF_CARDS;
  if (force) return force.split(",").map((s) => s.trim()).filter(Boolean);
  return fs
    .readdirSync(cardsDir)
    .filter((f) => /^BD-\d+\.md$/.test(f))
    .sort()
    .map((f) => f.replace(/\.md$/, ""));
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
  if (!fs.existsSync(cursorDir)) {
    throw new Error(".cursor missing — cannot snapshot for bakeoff");
  }
  console.log("snapshot .cursor ->", cursorSnap);
  cpr(cursorDir, cursorSnap);
}

function applyCursor(mode) {
  ensureCursorSnapshot();
  rmrf(cursorDir);
  if (mode === "empty") {
    cpr(emptyBundle, cursorDir);
    // stub must not carry Octo rules/skills
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

function resolveCombination() {
  try {
    const out = execSync(
      `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${path.join(root, "domains", "core", "scripts", "resolve-execution-context.ps1")}"`,
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
    );
    const m = out.match(/"combination_id"\s*:\s*"([^"]+)"/) || out.match(/combination_id[=:]\s*(\S+)/i);
    return m ? m[1].replace(/[",]/g, "") : null;
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
  for (const n of names) {
    h.update(fs.readFileSync(path.join(rules, n)));
  }
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
  if (arm === "sem" && hasCaveman) {
    ok = false;
    reasons.push("sem_has_caveman");
  }
  if (arm === "com" && !hasCaveman) {
    ok = false;
    reasons.push("com_missing_caveman");
  }
  return { enforce_ok: ok, combination_id: combo, rules_hash: rulesHash, reasons };
}

function fileDiffStats(targetAbs, original) {
  if (!targetAbs) return { added: 0, deleted: 0, net: 0, changed: false, patch_chars: 0 };
  const now = fs.existsSync(targetAbs) ? fs.readFileSync(targetAbs, "utf8") : "";
  const patch_chars = Math.abs((now?.length || 0) - (original?.length || 0));
  if (original === null || original === undefined) {
    return { added: now.split(/\r?\n/).filter(Boolean).length, deleted: 0, net: 0, changed: true, patch_chars };
  }
  if (now === original) return { added: 0, deleted: 0, net: 0, changed: false, patch_chars: 0 };
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
      return { added, deleted, net: added - deleted, changed: true, patch_chars };
    }
  } catch {
    /* fall through */
  }
  return { added: 1, deleted: 0, net: 1, changed: true, patch_chars };
}

function harnessFromDiff(diff, gatesPass = 1) {
  let score = 30 * gatesPass;
  score += Math.max(0, 20 - Math.min(20, Math.abs(diff.net) / 50));
  score += Math.max(0, 15 - Math.min(15, Math.abs(diff.net) / 40));
  score += 15; // budget
  score += 5 + 5;
  return Math.round(Math.min(100, score));
}

function writeStatusBaseline(ticket) {
  const p = path.join(resultsDir, `status-baseline-${ticket}.txt`);
  try {
    const out = execSync(`git -C "${root}" status --porcelain`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    fs.writeFileSync(p, out);
  } catch {
    fs.writeFileSync(p, "");
  }
  return p;
}

function runChecker(card, baselinePath) {
  const meta = CARD_META[card];
  const script = path.join(root, "eval", "agentic", "fixtures", "checkers", meta.checker);
  try {
    const out = execSync(`node "${script}" "${root}" "${baselinePath}"`, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    const line = out.trim().split(/\r?\n/).pop();
    return JSON.parse(line);
  } catch (e) {
    const out = String(e.stdout || "");
    try {
      return JSON.parse(out.trim().split(/\r?\n/).pop());
    } catch {
      return { pass: false, reason: String(e.message || e).slice(0, 120) };
    }
  }
}

function stampBaseline(ticket) {
  const stamp = path.join(root, "eval", "metrics", "stamp-usage-baseline.ps1");
  if (!fs.existsSync(stamp)) return;
  try {
    execSync(
      `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${stamp}" -Ticket "${ticket}" -Profile octo-cluster`,
      { stdio: "ignore" }
    );
  } catch {
    /* best-effort */
  }
}

function usageDelta(sinceMs) {
  const usage = path.join(root, "eval", "metrics", "cursor-usage.ps1");
  if (!fs.existsSync(usage)) return { ok: false, error: "missing" };
  try {
    const out = execSync(
      `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${usage}" -SinceMs ${sinceMs}`,
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }
    );
    const line = out
      .split(/\r?\n/)
      .map((l) => l.trim())
      .find((l) => l.startsWith("{"));
    return line ? JSON.parse(line) : { ok: false };
  } catch (e) {
    return { ok: false, error: String(e.message || e).slice(0, 80) };
  }
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

const maxRuns = Number(process.env.BAKEOFF_MAX_RUNS || String(cards.length * arms.length));
console.log(`COM-vs-SEM phase=${phase} cards=${cards.join(",")} arms=${arms.join(",")} max=${maxRuns}`);

ensureCursorSnapshot();

const state = loadCheckpoint();
const done = new Set(state.completed || []);
const results = state.results || [];
let failures = 0;
let runIndex = 0;

try {
  outer: for (const arm of arms) {
    const cfg = ARM_CFG[arm];
    setArmOverlay(cfg.overlay);
    applyCursor(cfg.cursorMode);

    for (const card of cards) {
      const ticket = `${card}-${arm}`;
      runIndex += 1;
      if (runIndex > maxRuns) break outer;
      if (done.has(ticket)) {
        console.log(`skip ${ticket}`);
        continue;
      }

      const meta = CARD_META[card];
      const targetAbs = path.join(root, ...meta.target.split("/"));
      let original = null;
      if (fs.existsSync(targetAbs)) original = fs.readFileSync(targetAbs, "utf8");

      const enf = enforceOk(arm);
      console.log(`\n==== [${runIndex}/${maxRuns}] ${ticket} enforce_ok=${enf.enforce_ok} ====`);
      if (!enf.enforce_ok) console.warn("enforce reasons:", enf.reasons.join("; "));

      stampBaseline(ticket);
      const sinceMs = Date.now();
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
          typeof result.result === "string"
            ? result.result
            : JSON.stringify(result.result ?? "");
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
      if (results.length + 1 >= 3 && failRate > 0.33) {
        console.error("ABORT: fail rate >33%");
        saveCheckpoint({ completed: [...done], results, aborted: "fail_rate", at: ticket });
        restoreCursor();
        cleanupOverlay();
        process.exit(4);
      }

      const diff = fileDiffStats(targetAbs, original);
      const check = runChecker(card, statusBaseline);
      const pass = !!check.pass;
      const usage = usageDelta(sinceMs);
      const usage_source = usage.ok
        ? usage.source || "api"
        : String(usage.error || "skipped").slice(0, 40);
      const harness_score = pass ? harnessFromDiff(diff, 1) : null;

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
        tokens_total: usage.tokens_total ?? null,
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

      saveCheckpoint({ completed: [...done], results, phase });
    }
  }

  // Phase 2 gate: BD-02 × 2 arms — abort if total tie on primary signals
  if (phase === 2) {
    const sem = results.find((r) => r.arm === "sem" && r.card === "BD-02");
    const com = results.find((r) => r.arm === "com" && r.card === "BD-02");
    if (sem && com) {
      const charsTie = sem.assistant_chars === com.assistant_chars;
      const passTie = sem.pass === com.pass;
      const diffTie = sem.diff_net === com.diff_net;
      if (charsTie && passTie && diffTie) {
        console.error(
          "ABORT phase2: Δ assistant_chars=0 AND pass equal AND diff equal — review enforce before full 6"
        );
        fs.writeFileSync(
          finalPath,
          JSON.stringify(
            { n_cards: 1, arms, phase: 2, aborted: "phase2_tie", results },
            null,
            2
          )
        );
        restoreCursor();
        cleanupOverlay();
        process.exit(5);
      }
      console.log(
        `phase2 gate OK: chars sem=${sem.assistant_chars} com=${com.assistant_chars} pass=${sem.pass}/${com.pass}`
      );
    }
  }

  fs.writeFileSync(
    finalPath,
    JSON.stringify({ n_cards: cards.length, arms, phase, results, directional: true }, null, 2)
  );
  console.log(`\nDONE runs=${results.length} -> ${finalPath}`);
} finally {
  restoreCursor();
  cleanupOverlay();
}

process.exit(0);
