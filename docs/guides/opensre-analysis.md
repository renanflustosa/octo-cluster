# OpenSRE pattern analysis

Competitive / pattern analysis of [Tracer-Cloud/opensre](https://github.com/Tracer-Cloud/opensre) (Apache-2.0) against Octo Cluster EOS initiatives. Docs-only; no upstream code vendored.

Related: [ADR-005 OKF session index](../adr/ADR-005-okf-session-index.md), [EOS](../governance/eos.md), [eval/](../../eval/README.md), [token metrics baseline](./token-metrics-baseline.md).

## Purpose

Map OpenSRE agent-harness, eval, cost, MCP, and governance patterns to Octo Cluster so the team can adopt, adapt, defer, or reject ideas without porting the SRE product runtime.

## Implementation (analysis method)

1. Read upstream [AGENTS.md](https://github.com/Tracer-Cloud/opensre/blob/main/AGENTS.md), README capabilities, `CI.md` / `TESTING.md` references, and public docs (benchmark, masking, `/cost`, fleet monitoring).
2. Compare to Octo Cluster paths: `domains/core/`, `eval/`, `eval/metrics/`, `scripts/productivity-audit.ps1`, `scripts/sync-cursor.ps1`, capability packs / MCP docs.
3. Score each checklist item and each of the [15 EOS initiatives](../governance/eos.md#initiatives-15).
4. Draft follow-up issues (titles only + one-line objective) — not created in the tracker here.

Local export `uploads/opensre-0.md` was absent; GitHub main was the source of truth.

## Usage

Use this guide when prioritizing harness/eval work. Prefer **Adapt** rows that cite a concrete Octo path. Do not copy OpenSRE modules into `domains/core/` without a license review and a new ADR.

## Validation

```powershell
Test-Path docs/guides/opensre-analysis.md
# Manual: every checklist row has a verdict; EOS table has 15 rows; >=3 follow-up drafts
pwsh scripts/boundary-audit.ps1
```

## Limitations

- Snapshot of upstream main at analysis time; OpenSRE moves quickly.
- No runtime dependency on OpenSRE; recommendations are pattern-level.
- Apache-2.0 NOTICE/attribution required if substantial code or skills are later copied (none in this card).
- Product SRE/incident investigation is explicitly out of scope for the public kernel.

---

## License posture

| Item | Upstream | Octo Cluster | Note |
|------|----------|--------------|------|
| Repository | Apache-2.0 | MIT (project) | Compatible for *ideas*; copying code needs NOTICE + attribution in `THIRD_PARTY.md` |
| This analysis | — | Docs only | No code copied → **no** `THIRD_PARTY.md` change |
| Future code adopt | Apache-2.0 | Must record NOTICE | Gate any paste behind license checklist |

Per-recommendation license: **cite-only** unless marked Adopt with code path (none below require vendoring today).

---

## Analysis checklist

| # | Topic | Upstream signal | Octo target | Verdict | License |
|---|--------|-----------------|-------------|---------|---------|
| 1 | Agent orchestration (`AGENTS.md`, tool loop, slash REPL) | Rich `AGENTS.md` repo map; interactive shell slash commands; shared tool-calling loop in `core/` | [`AGENTS.md`](../../AGENTS.md), `core-adaptive-loop`, phase commands | **Adapt** — keep phase loop; optionally thicken public `AGENTS.md` repo map like OpenSRE’s table | Cite-only |
| 2 | Benchmark / synthetic eval vs promptfoo + agentic | `tests/synthetic`, `tests/e2e`, `make benchmark`, misses→scenarios loop | [`eval/promptfoo/`](../../eval/promptfoo/), [`eval/agentic/`](../../eval/agentic/) | **Adapt** — grow agentic/synthetic fixtures; defer full CloudOps-style bench | Cite-only |
| 3 | Session cost / tokens vs `eval/metrics/` | `/cost`, `TokenUsage` in agent harness accounting | [`eval/metrics/`](../../eval/metrics/), card-lite at `/close` | **Adapt** — align naming (measured vs estimated) and document `/cost`-like operator UX in metrics README | Cite-only |
| 4 | Local agent fleet scan vs productivity-audit | Fleet monitoring for Cursor/Codex/Claude on machine | [`scripts/productivity-audit.ps1`](../../scripts/productivity-audit.ps1) | **Adapt** — extend audit checks; reject shipping a full fleet daemon in core | Cite-only |
| 5 | MCP / tool catalog vs capability packs | 60+ integrations; MCP/ACP; `TOOL_INTEGRATION_CHECKLIST.md` | Capability packs, MCP docs, adapters | **Adapt** — adopt a short tool/integration checklist for packs; reject porting integration catalog | Cite-only |
| 6 | Identifier masking before LLM calls | `platform/masking/` reversible redaction | Boundary rules, consumer-boundary, no secrets in tree | **Adapt** — document redaction guidance for agent prompts; defer full reversible masker | Cite-only |
| 7 | `.cursor/` / rules / skills vs `domains/core` sync | Multi-surface agent assets (`.cursor/`, `.claude/`) | `sync-cursor.ps1`, `domains/core/` source of truth | **Keep / Defer** — Octo already has sync model; do not dual-write hand-edited `.cursor/` | Cite-only |
| 8 | CI / governance promotion | `CI.md`, `TESTING.md`, pre-commit, import linter, PR AI disclosure | EOS, repo-policies, boundary-audit, CI workflows | **Adapt** — consider explicit agent pre-push checklist doc mirroring `CI.md` brevity | Cite-only |

### Checklist notes

- **Reject** wholesale: investigation pipeline, Hermes/Telegram ops product, EC2 deploy stack, 60+ vendor tools as core dependencies.
- Overlap with ADR-005: OpenSRE invests in session accounting and harness ports; Octo should deepen `eval/metrics/` rather than Cursor `sessionStart` injection (see Deferred OKF path).

---

## EOS initiatives map (15)

| Initiative | OpenSRE overlap | Verdict | Target path (if act) |
|------------|-----------------|---------|----------------------|
| Engineering Standards & Governance | `CI.md`, PR template, CONTRIBUTING | **Adapt** | `docs/governance/`, root OSS docs |
| Kernel Architecture | `core/`, `platform/`, `surfaces/` layering | **Defer** | Study only; keep `domains/core` + packs |
| Memory | Session/resume REPL | **Defer** | `state/memory/`, context-engine (existing) |
| Context Engineering | Context budget in tool loop | **Adapt** | `contexts/`, context budget scripts |
| RAG | Evidence retrieval in investigations | **Defer** | Keep LanceDB DIY ([eval README](../../eval/README.md)) |
| Token Optimization | `/cost`, TokenUsage measured/estimated | **Adapt** | `eval/metrics/` |
| MCP Integration | MCP entrypoints, protocol matrix | **Adapt** | Capability pack MCP docs + checklist |
| Agent Orchestration | Tool loop, slash REPL, harness ports | **Adapt** | Phase commands + richer `AGENTS.md` |
| Evaluation & Benchmarking | synthetic/e2e/benchmark/misses loop | **Adapt** | `eval/agentic/`, `eval/promptfoo/` |
| Observability | Hermes watch, analytics | **Reject** (product) / **Defer** (patterns) | `engine/metrics/` only for harness metrics |
| Developer Experience | SETUP.md, Makefile, onboarding wizard | **Adapt** | `docs/guides/onboarding.md`, Makefile targets as needed |
| Documentation | Mintlify docs, ARCHITECTURE.md | **Adapt** | `docs/` — keep English EOS style |
| Open Source Governance | Apache-2.0, citations, telemetry notes | **Defer** | Stay on current MIT + NOTICE discipline |
| CI/CD | Mandatory CI.md agent checklist | **Adapt** | `.github/workflows/`, short agent CI doc |
| Security | Masking, sandbox, guardrails | **Adapt** | SECURITY.md + boundary-audit; defer sandbox port |

---

## Follow-up issue drafts

Tracker-agnostic titles (EOS naming: `[domain] imperative + object`). Create as separate cards; split if >3 days.

1. **`[eval] add measured-vs-estimated token buckets to card-lite`**  
   Objective: Mirror OpenSRE `TokenUsage` clarity in `eval/metrics` close reports.

2. **`[docs] add agent pre-push checklist (CI parity one-pager)`**  
   Objective: Single short doc agents must follow before push (lint/test/boundary), inspired by OpenSRE `CI.md`.

3. **`[mcp] add tool-integration checklist for capability packs`**  
   Objective: Pack authors get a TOOL_INTEGRATION-style gate (schema, docs, tests, secrets).

4. **`[eval] grow agentic synthetic fixtures for phase-command shape`**  
   Objective: Expand `eval/agentic` / promptfoo cases toward reproducible harness regressions (not full CloudOpsBench).

5. **`[security] document prompt-side identifier redaction guidance`**  
   Objective: Lightweight masking guidance for public/private overlays without vendoring OpenSRE masker.

6. **`[dx] extend productivity-audit with optional local agent-process hints`**  
   Objective: Optional fleet-inspired checks; no always-on daemon in core.

---

## Recommended priority

| Priority | Action | Why |
|----------|--------|-----|
| P1 | Issues 1–3 | Cheap, aligns with Token Optimization, Governance, MCP |
| P2 | Issues 4–5 | Eval depth + security docs |
| P3 | Issue 6 | DX nicety; easy to over-scope |

**Do not:** port OpenSRE runtime, deploy OpenSRE as a dependency, or enable Cursor `sessionStart` OKF injection (see [ADR-005](../adr/ADR-005-okf-session-index.md)).
