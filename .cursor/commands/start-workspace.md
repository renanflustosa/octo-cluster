# start-workspace

Morning bootstrap (~30s–2min). Run **once** when opening the day.

**Discover (once per thread):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline start-workspace -Action discover
```

**Run:**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline start-workspace -Action run
```

Optional flags via `-ScriptArgs @{ SkipIndex = $true; WithStack = $true }`.

**Core actions:**
- Context-engine validate
- Memory profile review under `state/memory/<profile>/`
- Stamp: `last-start-workspace.txt`
- Child pack scripts run additively when enabled in execution context
- Weekly metrics full run when due (>7 days)

**Then:** new chat → `/scan <TICKET> description`.

**Playbook:** `docs/productivity-tools.md`
