# ship

**Agent mode** — verify → gate → deliver. Only **READY** proceeds.

**Discover (once):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline ship -Action discover
```

Read `PIPELINE_SKILL` + `domains/core/skills/core-ship/SKILL.md` once.

**Run:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline ship -Action run
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline ship -Action run -CommitMessage "fix: short conventional summary"
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline ship -Action run -Phase git -CommitMessage "fix: ..." -FeatureBranch "fix/my-change"
```

Use flat parameters (`-CommitMessage`, `-FeatureBranch`). Avoid `-ScriptArgs @{ ... }` through `powershell -File`.

Phases (fail-fast): discover → preflight? → **verification** → **gates** → **git** → reviews?  
Contracts via repo policy — no hardcoded project vocabulary.

**Verdict:** `READY` | `NEEDS FIXES` | `BLOCKED` — output **≤8 lines** (verdict + git/PR + gates).  
Else: stop, fix via Execute plan, re-run `/ship`.
