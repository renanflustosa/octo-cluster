# ship

**Agent mode** — verify → gate → deliver. Only **READY** proceeds.

**Discover (once):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action discover
```

Read `PIPELINE_SKILL` + `domains/core/skills/core-ship/SKILL.md` once.

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -CommitMessage "fix: short conventional summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -Phase git -CommitMessage "fix: ..." -FeatureBranch "fix/my-change"
```

Use flat parameters (`-CommitMessage`, `-FeatureBranch`). Avoid `-ScriptArgs @{ ... }` through `powershell -File`.

Phases (fail-fast): discover → preflight? → **verification** → **gates** → **git** → reviews? → **close?** (when `auto_close_after_ship` + CARD + git OK)  
Contracts via repo policy — no hardcoded project vocabulary.

**Verdict:** `READY` | `NEEDS FIXES` | `BLOCKED` — output **≤8 lines** (verdict + git/PR + gates + auto-close).  
Else: stop, fix via Execute plan, re-run `/ship`. Manual `/close` still works when auto-close is off or skipped.
