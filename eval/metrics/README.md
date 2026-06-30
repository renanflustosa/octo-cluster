# Metrics — Octo Cluster kernel

## Lite (each `/close`)

[`measure-card-lite.ps1`](measure-card-lite.ps1) — automatic via [`core-close.ps1`](../../domains/core/scripts/core-close.ps1):

- Cursor API delta since [`stamp-usage-baseline.ps1`](stamp-usage-baseline.ps1) at `/scan`
- `score-diff.ps1` LOC
- Context budget alerts + gates
- **SQLite** `state/metrics/metrics.db` table `cards`

## Full (weekly)

[`measure-harness-full.ps1`](measure-harness-full.ps1) — automatic via [`core-start-workspace.ps1`](../../domains/core/scripts/core-start-workspace.ps1) if last run >7 days:

- productivity-audit
- context budget
- agentic safety selftest
- promptfoo (optional)
- SQLite table `harness_snapshots` + report trends

Force: `measure-harness-full.ps1 -Force`

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
stamp-usage-baseline.ps1 -Ticket 8CL-123

# Close — automatic lite metrics

# Report
report.ps1 -Last 20 -Arm ponytail-lite

# Full harness
measure-harness-full.ps1 -Force

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
