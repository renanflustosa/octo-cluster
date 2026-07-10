# Tool Impact Protocol (TIP)

Evidence-based method to measure whether an **external** harness tool (MCP, IDE extension, CLI, eval lib, memory layer) improves `harness_score` and/or reduces token usage — before promoting it in [`harness-catalog.yaml`](../architecture/harness-catalog.yaml).

Related: [ADR-006](../adr/ADR-006-harness-tool-cluster.md), [combination-bakeoff.md](../../eval/agentic/protocol/combination-bakeoff.md), [harness-tool-cluster.md](./harness-tool-cluster.md), [eval/metrics/README.md](../../eval/metrics/README.md).

## Why TIP exists

The **4-way combination bakeoff** ranks Octo **runtime toggles** (`nada` / `baseline` / `compress-on` / `octo-full`). It does **not** isolate third-party tools (MCP servers, Cline, Aider, Mem0, etc.).

Without TIP, the cluster becomes “install everything” with no promote/reject path. ADR-006 requires **scorecard evidence**, not vibes.

## Scope

| In | Out |
|----|-----|
| Paired A/B: baseline Octo vs baseline + **one** external tool | Porting external runtimes into `domains/core/` |
| Same synthetic card suite both arms | Paid SaaS as sole token signal |
| SQLite via `measure-card-lite.ps1` | OKF `sessionStart` default (ADR-005) |
| Promote / Hold / Reject → catalog | n=1 “it felt faster” |

## Scorecard (inherit ADR-006)

| Metric | Weight | TIP use |
|--------|--------|---------|
| `gate_pass` | 30 | Hard block — failing arm cannot win |
| `tokens_total` / delta | 20 | Prefer lower; `usage_source=skipped` → use `\|diff_net_loc\|` proxy |
| `diff_net_loc` | 15 | Prefer lower churn for same outcome |
| `context_budget_alerts` | 15 | Prefer fewer |
| `phase_shape_ok` | 10 | promptfoo / shape when run |
| `bootstrap_ms` | 10 | Prefer lower when recorded |

**Winner rule:** highest mean `harness_score` over ≥3 paired cards, **no `gate_pass` regression** vs baseline arm; ties → lower tokens (or lower `\|diff_net\|` if usage skipped).

Samples with n&lt;30 are **directional only** — document as such; do not promote defaults from inconclusive runs.

---

## Experiment structure

```text
experiment_id:  TIP-<tool-slug>-<YYYYMMDD>
baseline_arm:   combination_id=baseline, external_tool=OFF
treatment_arm:  combination_id=baseline (or tip-<tool-slug>), external_tool=ON
card_suite:     BC-01…BC-05 (docs-only) — identical prompts both arms
runs:           n ≥ 3 per arm (5 recommended)
persist:        /close → measure-card-lite → metrics.db
rank:           report.ps1 (CompareCombinations today; CompareTools when implemented)
verdict:        Promote | Hold | Reject → harness-catalog.yaml note
```

### Negative control (mandatory)

Every TIP run compares **the same Octo baseline** with exactly **one** variable changed (the external tool). Never compare two unfamiliar stacks at once.

### Recording

- Primary: SQLite `state/metrics/metrics.db` (gitignored)
- Optional: `eval/agentic/results/TIP-<tool-slug>-<date>.md` (gitignored; redact secrets)
- Future: `experiment_id` / `tool_slug` columns on card-lite (see backlog below)

---

## Promote / Hold / Reject gates

| Verdict | Criteria |
|---------|----------|
| **Promote** | Mean `harness_score` ↑ ≥5 pts **or** measured tokens ↓ ≥10% vs baseline, across ≥3 cards, **and** zero `gate_pass` regression |
| **Hold** | Directional improvement but n&lt;5, or `usage_source=skipped` without LOC proxy improvement, or operational cost unclear |
| **Reject** | Any `gate_pass` regression vs baseline, or tool adds complexity with no score/token benefit, or violates ADR-006 OUT (paid-only signal, fleet daemon, runtime port) |

Update catalog entry: `status: on | off | defer | reject` + one-line evidence link (private tracker or gitignored result path — **no private issue IDs in public tree**).

---

## Isolation matrix (spike candidates)

How to turn each tool **ON/OFF** without confounding Octo toggles. All configs stay **local** (gitignored) unless promoted.

| Tool | Category | Layer | ON | OFF | Confounders |
|------|----------|-------|----|-----|-------------|
| Cline | IDE extension | adapter | Enable extension; separate workspace or window | Disable extension | Cursor still loads synced `.cursor/` rules |
| Continue.dev | IDE extension | adapter | Enable extension + config | Disable extension | Same as Cline |
| Aider | CLI | adapter | Run task via `aider` in terminal | Same task via Octo loop only | Different edit/commit path — match task scope |
| OpenCode | CLI | adapter | `opencode` session with same card prompt | Octo `/scan`→`/close` | Plugin MCP may overlap |
| GitHub MCP | MCP server | pack | Entry in local `mcp.json` | Remove/disable server | Auth token in local config only |
| GitMCP | MCP server | pack | Remote URL in `mcp.json` | Disable server | Network vs LanceDB latency |
| Mem0 | Memory | pack | Local OSS Mem0 + pack overlay | LanceDB + memory files only | Extra vector store cost |
| DeepEval | Eval lib | core | Offline metric run on fixture output | promptfoo-only baseline | No agent tokens unless integrated in loop |
| ast-grep | Structural search | pack | CLI/LSP available to agent | grep-first only | Agent must be instructed to use sg |
| OpenHands | Multi-agent | adapter | Local Docker/agent server | N/A for MVP | Heavy orchestration — likely Reject for core |

Preliminary research verdicts live in private Linear spikes; TIP **replaces opinion with numbers**.

---

## Runbooks by category

### MCP (pack)

1. Baseline arm: Octo `baseline` overlay, MCP server **disabled** in local Cursor config.
2. Treatment arm: same overlay, **one** MCP server enabled.
3. Run BC-01…BC-05 (one card per chat): `/scan` → execute fixture → `/close`.
4. Swap MCP off; repeat suite.
5. Compare: `pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50`

Never commit `mcp.json` or tokens to the public tree.

### IDE extension (adapter)

1. Use a **clean workspace clone** or dedicated window when possible.
2. Baseline: Cursor + Octo project hooks, extension **off**.
3. Treatment: extension **on**, same cards — accept that `.cursor/` rules still load (document as caveat).
4. Prefer docs-only BC cards to reduce edit-path differences.

### CLI (adapter)

1. Define **equivalent task** (same acceptance criteria as a BC card).
2. Baseline: Octo phase loop through `/close` with card-lite.
3. Treatment: CLI completes same task; manually invoke `measure-card-lite.ps1` with same `combination_id` + note `tool_slug` in ticket metadata until schema exists.

### Eval library (core)

1. Run **offline** on saved agent outputs or promptfoo fixtures.
2. Measure metric deltas (hallucination, relevancy) — does not replace `harness_score` until wired into close path.
3. Promote only metrics that map to EOS eval initiatives without mandatory SaaS.

### Memory (pack)

1. Baseline: LanceDB + `state/memory/` (catalog ON).
2. Treatment: add Mem0 OSS self-hosted retrieval for same profile.
3. Compare: tokens per card + retrieval hit quality (manual checklist if no auto metric yet).

---

## Card suite

Default: [BC-01 … BC-05](../../eval/agentic/fixtures/bakeoff-cards/) (docs-only, low risk).

Planned expansion: BC-06…BC-08 for TIP-specific scenarios (backlog).

Same prompt text on **both** arms. One card = one chat session.

---

## Commands

```powershell
# Confirm runtime arm
pwsh domains/core/scripts/resolve-execution-context.ps1

# Baseline stamp at /scan
pwsh eval/metrics/stamp-usage-baseline.ps1 -Ticket TIP-ast-grep-001

# After each /close (automatic lite metrics)
# ...

# Rank combinations (today)
pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50

# Audit before any public doc change
pwsh scripts/boundary-audit.ps1
```

When `usage_source=skipped`, still rank on `harness_score`, `gate_pass`, and `|diff_net_loc|`.

---

## Recommended Linear backlog (implementation)

English issue titles; private tracker only. Do **not** duplicate Cycle 2 MVP delivery cards — these are **measurement infrastructure**.

**Status:** Linear issues created in the private tracker (Cycle 2). Spec card is Done (this doc). Do not paste private issue IDs into the public tree.

| P | Title | Layer | Estimate |
|---|-------|-------|----------|
| P0 | `[eval] define Tool Impact Protocol (TIP) spec` | core | 1d — **this doc (Done)** |
| P0 | `[eval] add experiment_arm / tool_slug metadata to card-lite schema` | core | 2d |
| P1 | `[eval] extend report.ps1 with CompareTools ranking` | core | 2d |
| P1 | `[eval] add BC-06…BC-08 docs-only TIP card fixtures` | core | 2d |
| P1 | `[mcp] TIP runbook validation for GitHub MCP and GitMCP` | pack | 2d |
| P1 | `[dx] TIP runbook validation for Aider and OpenCode CLI` | adapter | 2d |
| P2 | `[dx] TIP runbook validation for Cline and Continue IDE extensions` | adapter | 2d |
| P2 | `[eval] TIP pilot: ast-grep vs grep-first (first Promote/Reject)` | pack | 2d |
| P2 | `[eval] TIP pilot: DeepEval offline vs promptfoo baseline` | core | 2d |
| P2 | `[eval] wire TIP verdict fields into harness-catalog.yaml` | core | 1d |

Pilot order (lowest confounding first): **ast-grep** → **GitHub MCP** → **DeepEval offline** → **Aider** → IDE extensions last.

---

## KPIs

| KPI | Baseline | Target |
|-----|----------|--------|
| Spike tools with ≥1 TIP run | 0/10 | 10/10 directional |
| Tools with Promote/Reject verdict | 0 | ≥5 before post-MVP review |
| `gate_pass` regression on promoted tools | — | 0 |
| Documented token delta (measured arms) | card-lite baseline | per-tool row in private results |

---

## Risks

1. **Confounding** — Cursor rules always on; mitigate with docs-only cards and explicit caveats in results.
2. **usage skipped** — rely on LOC proxy; mark Hold until measured tokens available.
3. **Scope creep** — one tool per experiment; reject “enable all MCPs” runs.

---

## Related analysis (already done — not re-spike)

- OpenSRE — [opensre-analysis.md](./opensre-analysis.md) (patterns only, no runtime port)
- claude-mega-brain — [ADR-005](../adr/ADR-005-okf-session-index.md) (OKF sessionStart deferred)

TIP applies when a tool moves from **research** to **evidence-based promote/reject**.
