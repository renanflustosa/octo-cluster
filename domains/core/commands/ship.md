# ship

**Agent mode** — verify → gate → deliver. Only **READY** proceeds. Model: `gpt-5.6-terra-medium` for the verdict; scripts do the rest (COST 0). Scripts-only ship: `composer-2.5-fast` is enough.

**Discover (once):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action discover
```

Read `PIPELINE_SKILL` + `domains/core/skills/core-ship/SKILL.md` once.

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -CommitMessage "fix: short conventional summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -CommitMessage "fix: ..." -NoWaitForMerge
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -CommitMessage "fix: ..." -FullVerify
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline ship -Action run -Phase git -CommitMessage "fix: ..." -FeatureBranch "fix/my-change"
```

Use flat parameters (`-CommitMessage`, `-FeatureBranch`). Avoid `-ScriptArgs @{ ... }` through `powershell -File`.

**LLM turn budget: 1 (the verdict).** Git, branch, PR, auto-merge, and safe local cleanup are 100% script via the orchestrator — **never run git commands manually** during `/ship`. Repos with `auto_merge` + `wait_for_merge` in repo policy wait for CI and merge by default; use `-NoWaitForMerge` to return after enabling auto-merge. `-WaitForMerge` remains valid (explicit). Direct-strategy repos never wait. Use `-FullVerify` for all policy checks. Do not narrate script output; report `SHIP_RESULT` only.

Phases (fail-fast): discover → preflight? → **verification** → **gates** → **git** → reviews? → **close?** (when `auto_close_after_ship` + CARD + git OK)  
Contracts via repo policy — no hardcoded project vocabulary.

**Verdict:** `READY` | `NEEDS FIXES` | `BLOCKED` — output **≤8 lines** (verdict + git/PR + gates + auto-close).  
Else: stop, fix via Execute plan, re-run `/ship`. Manual `/close` still works when auto-close is off or skipped.
