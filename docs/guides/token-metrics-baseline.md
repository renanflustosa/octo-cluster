# Token metrics baseline

Published baseline for harness token-economy measurement (Cycle 1 deliverable).

## Purpose

Demonstrate measurable token impact from Octo Cluster harness practices (grep-first, read budgets, ponytail-lite, phase commands).

## How metrics are collected

| Layer | Script | When |
|-------|--------|------|
| Card-lite | `eval/metrics/measure-card-lite.ps1` | Each `/close` |
| Baseline stamp | `eval/metrics/stamp-usage-baseline.ps1` | Each `/scan` with `8CL-xxx` |
| Full harness | `eval/metrics/measure-harness-full.ps1` | Weekly start-workspace |

See [`eval/metrics/README.md`](../../eval/metrics/README.md) and [`architecture/metrics-kernel.md`](../architecture/metrics-kernel.md).

## Validation

```powershell
cd engine\context-engine
bun run validate octo-cluster
.\..\..\eval\metrics\stamp-usage-baseline.ps1 -Ticket 8CL-XXX -Profile octo-cluster
.\..\..\scripts\productivity-audit.ps1
```

## Baseline targets (pilot)

| Metric | Target direction |
|--------|------------------|
| LOC delta per card | Smaller with ponytail-lite |
| Context budget alerts | Fewer gate failures over time |
| Gate pass rate | Increase with harness maturity |
| Cursor usage delta | Measurable via card-lite when API available |

## Limitations

- Cursor usage API is unofficial — may degrade to LOC-only (`usage_source=skipped`)
- Requires local `state/metrics/metrics.db` (gitignored)
- Full A/B requires manual agentic pilot — see [`eval/agentic/README.md`](../../eval/agentic/README.md)

## Implementation

Storage: SQLite `state/metrics/metrics.db` via `engine/metrics/`.

Upgrade path: publish aggregate trends in README once pilot data exists (no PII, no tokens).
