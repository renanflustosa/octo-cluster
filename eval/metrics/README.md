# Metrics — Octo Cluster kernel

## Lite (each `/close`)

[`measure-card-lite.ps1`](measure-card-lite.ps1) — automatic via [`core-close.ps1`](../../domains/core/scripts/core-close.ps1):

- Cursor API delta since [`stamp-usage-baseline.ps1`](stamp-usage-baseline.ps1) at `/scan`
- `score-diff.ps1` LOC
- Context budget alerts + gates
- **SQLite** `state/metrics/metrics.db` table `cards`

## Token setup

1. **Auto:** `%APPDATA%\Cursor\User\globalStorage\state.vscdb` (Elis-style)
2. **Fallback:** local gitignored `DEV/CURSOR/SESSION.json` (any path via env)

```json
{
  "WorkosCursorSessionToken": "user_id%3A%3AeyJ..."
}
```

3. **Env:** `$env:CURSOR_SESSION_TOKEN`

Test: `cursor-session.ps1 -Json -Redact`

## Commands

```powershell
# Scan — stamp baseline
stamp-usage-baseline.ps1 -Ticket ISSUE-123

# Close — automatic lite metrics (reads combination_id from runtime JSON)

# Report
report.ps1 -Last 20 -Arm ponytail-lite
report.ps1 -CompareCombinations -Last 50
```

## Combination bakeoff (ADR-006)

Set `combination_id` + `harness_tools` in `contexts/runtime/*.json` (or `.local.json`). Each `/close` persists `combination_id`, measured/estimated token buckets when usage API works, and `harness_score`. Rank arms with `-CompareCombinations`.

See [`docs/guides/harness-tool-cluster.md`](../../docs/guides/harness-tool-cluster.md).

## TIP stamp (experiment metadata)

Optional columns on each card (schema v3): `experiment_id`, `tool_slug`, `experiment_arm` (`baseline` | `treatment`). Omit them for normal `/close` — backward compatible.

```powershell
# Direct measure
pwsh eval/metrics/measure-card-lite.ps1 -Ticket TIP-ast-grep-1 `
  -ExperimentId TIP-ast-grep-20260711 -ToolSlug ast-grep -ExperimentArm treatment

# Or set env before /close (core-close → measure-card-lite reads these)
$env:OCTO_EXPERIMENT_ID  = 'TIP-ast-grep-20260711'
$env:OCTO_TOOL_SLUG      = 'ast-grep'
$env:OCTO_EXPERIMENT_ARM = 'baseline'   # or treatment
```

Guide: [`docs/guides/tool-impact-protocol.md`](../../docs/guides/tool-impact-protocol.md).

```powershell
# DB admin
engine/metrics/metrics-store.ps1 -StoreAction init
engine/metrics/metrics-store.ps1 -StoreAction migrate-csv
```

## Storage

| Path | Role |
|------|------|
| `state/metrics/metrics.db` | SQLite (gitignored) |
| `engine/metrics/schema.sql` | Portable schema |
| `engine/metrics/metrics_db.py` | Store API |

Legacy CSV in `state/logs/metrics-baseline/` migrated once via `migrate-csv`.

## API note

Uses unofficial Cursor dashboard endpoints. May break; lite metrics degrade to LOC-only (`usage_source=skipped`).

See [`docs/architecture/metrics-kernel.md`](../../docs/architecture/metrics-kernel.md) for portable metrics schema.
