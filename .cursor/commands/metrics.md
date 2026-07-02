# metrics

**Agent mode** — Octo Cluster metrics (lite/report).

## Lite (automatic at `/close`)

Runs via `core-close.ps1` → `measure-card-lite.ps1` → SQLite.

## Scan baseline (token delta)

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\stamp-usage-baseline.ps1 -Ticket 8CL-123
```

## Report

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\report.ps1 -Last 20 -Arm ponytail-lite
```

## Token test

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\cursor-session.ps1 -Json -Redact
```

Playbook: [`eval/metrics/README.md`](../../eval/metrics/README.md) · [`docs/architecture/metrics-kernel.md`](../../docs/architecture/metrics-kernel.md)
