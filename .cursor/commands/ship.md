# ship

**Agent mode** — verify → gate → deliver. Only **READY** proceeds.

**Discover (once):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action discover
```

Read `PIPELINE_SKILL` + `domains/core/skills/core-ship/SKILL.md` once.

**Run:**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run -Phase git -ScriptArgs @{ CommitMessage = "..."; FeatureBranch = "..." }
```

Phases (fail-fast): discover → preflight? → **verification** → **gates** → **git** → reviews?  
Contracts via repo policy — no hardcoded project vocabulary.

**Verdict:** `READY` | `NEEDS FIXES` | `BLOCKED` — output **≤8 lines** (verdict + git/PR + gates).  
Else: stop, fix via Execute plan, re-run `/ship`.
