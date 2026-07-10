# ADR-006: Harness tool cluster (catalog + experiment protocol)

## Status

Accepted

## Context

Octo Cluster already has free/local harness pieces (phase loop, LanceDB, caveman/ponytail, `eval/metrics`, gates, Cursor sync) but no single catalog, no explicit tool toggles, and no protocol to rank **combinations** by evidence. Related: [ADR-003](./ADR-003-provider-agnostic-architecture.md), [ADR-005](./ADR-005-okf-session-index.md) (OKF session injection deferred), [opensre-analysis](../guides/opensre-analysis.md).

Goal: modular cluster of free tools for harness quality and token/cost reduction, with measurement so the **winning combination** is chosen by scorecard — not by installing everything.

## Decision

1. **Catalog** — Versioned inventory at [`docs/architecture/harness-catalog.yaml`](../architecture/harness-catalog.yaml) under a fixed taxonomy: `ctx`, `search`, `compress`, `eval`, `cost`, `gate`, `ide`.
2. **Toggles** — Runtime JSON fields `combination_id` + `harness_tools` (defaults preserve today’s behavior). Packs stay capability-based; tools map to toggles, not scattered `if`s in core.
3. **Scorecard** (weights for `harness_score`, 0–100):

| Metric | Weight | Notes |
|--------|--------|-------|
| `gate_pass` | 30 | Hard preference: failing gates cannot win |
| `tokens_delta` / usage | 20 | Prefer lower; `skipped` → use LOC proxy in ranking |
| `diff_net_loc` | 15 | Prefer lower absolute churn for same outcome |
| `context_budget_alerts` (tool_calls_proxy) | 15 | Prefer fewer alerts |
| `phase_shape_ok` | 10 | Promptfoo / shape checks when run |
| `bootstrap_ms` | 10 | Prefer lower when recorded |

**Winner rule:** highest mean `harness_score` over ≥3 cards of the same bakeoff protocol, with no `gate_pass` regression vs baseline; ties → lower tokens (or lower `|diff_net|` if usage skipped).

4. **Experiment protocol** — Manual bakeoff in [`eval/agentic/protocol/combination-bakeoff.md`](../../eval/agentic/protocol/combination-bakeoff.md); persist `combination_id` on each card; `report.ps1 -CompareCombinations` ranks arms.
5. **Adapters** — Core owns catalog/metrics/loop. Cursor+Windows is the MVP adapter. Claude+Ubuntu is a **contract stub** only ([`adapters/claude/`](../../adapters/claude/README.md)); full sync is phase 3.
6. **IN vs OUT** — IN: local/OSS already in-repo or installable without paid SaaS. OUT: mandatory paid APIs as sole signal; OpenSRE/mega-brain ports; OKF `sessionStart` default; fleet daemons.

## Consequences

### Easier

- Clear promote/reject path for harness changes (PDCA via SQLite)
- Cross-IDE path later without rewriting metrics
- Avoids “install all free tools” noise

### Harder

- Operators must set `combination_id` when running bakeoffs
- Cursor usage API remains optional/unofficial (`usage_source=skipped` still valid)
- Real on/off for every catalog tool is phase 2; MVP documents toggles and measures combinations

## References

- Guide: [`docs/guides/harness-tool-cluster.md`](../guides/harness-tool-cluster.md)
- Metrics: [`docs/architecture/metrics-kernel.md`](../architecture/metrics-kernel.md)
