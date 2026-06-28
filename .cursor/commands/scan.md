# scan

**Skip** if scan done this chat — use prior output. Model: session default (Auto).

**User message = ticket source:** `/scan TICKET-123 description` — no carry-forward paste.

**Discover (once per thread):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline scan -Action discover
```

Read `PIPELINE_SKILL` once.

**Harness (run):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline scan -Action run
```

Then as needed:

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-domain-script.ps1 -Name context-search
powershell -File $env:OCTO_CLUSTER\scripts\invoke-domain-script.ps1 -Name read-gate -ScriptArgs @{ Path = "<file>" }
```

Update `state/memory/<profile>/current_task.md` (≤200 tokens).

**Usage baseline (best-effort, for token metrics at `/close`):**

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\stamp-usage-baseline.ps1 -Ticket "<TICKET>" -Profile "<profile>"
```

**Output:** Objective, Scope, Git, Risks, Next — **≤6 bullets**.

**Playbook:** resolve `PIPELINE_SKILL` from discover output (typically `core-adaptive-loop` or pack overlay).
