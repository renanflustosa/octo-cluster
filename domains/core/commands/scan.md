# scan

**Skip** if scan done this chat — use prior output. Model: session default (Auto).

**User message = ticket source:** `/scan TICKET-123 description` — no carry-forward paste.

**Discover (once per thread):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline scan -Action discover
```

Read `PIPELINE_SKILL` once.

**Harness (run):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline scan -Action run
```

Then as needed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo-domain.ps1" -Name context-search
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo-domain.ps1" -Name read-gate -Path "<file>"
```

Use flat `-Path` (not `-ScriptArgs @{ Path = ... }`) when calling via `powershell -File`.

Update `state/memory/<profile>/current_task.md` (≤200 tokens).

**Usage baseline (best-effort, for token metrics at `/close`):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo-run.ps1" -RelativePath eval\metrics\stamp-usage-baseline.ps1 -Ticket "<TICKET>" -Profile "<profile>"
```

**Output:** Objective, Scope, Git, Risks, Next — **≤6 bullets**.

**Playbook:** resolve `PIPELINE_SKILL` from discover output (typically `core-adaptive-loop` or pack overlay).
