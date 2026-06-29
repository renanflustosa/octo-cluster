# metrics

**Agent mode** — Octo Cluster metrics (lite/full/report).

## Lite (automatic at `/close`)

Runs via `core-close.ps1` → `measure-card-lite.ps1` → SQLite.

## Full (weekly at `/start-workspace`)

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\measure-harness-full.ps1
powershell -File $env:OCTO_CLUSTER\eval\metrics\measure-harness-full.ps1 -Force
```

## Scan baseline (token delta)

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\stamp-usage-baseline.ps1 -Ticket OPE-123
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
