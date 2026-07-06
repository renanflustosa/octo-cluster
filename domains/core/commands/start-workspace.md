# start-workspace

Morning bootstrap (~30s–2min). Run **once** when opening the day.

**Discover (once per thread):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline start-workspace -Action discover
```

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline start-workspace -Action run
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline start-workspace -Action run -SkipIndex
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline start-workspace -Action run -WithStack
```

Optional flags use flat switches (`-SkipIndex`, `-WithStack`), not `-ScriptArgs @{ ... }`.

**Core actions:**
- Context-engine validate
- Memory profile review under `state/memory/<profile>/`
- Stamp: `last-start-workspace.txt`
- Child pack scripts run additively when enabled in execution context

**Then:** new chat → `/scan <TICKET> description`.

**Playbook:** `docs/guides/productivity-tools.md`
