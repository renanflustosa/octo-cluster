# ship

Agent mode. Verify, then deliver: commit and push straight to `main`.

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -CommitMessage "fix: short conventional summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -WhatIf
```

The script runs the boundary gate, commits, and pushes. No feature branch, no PR, no rebase.

**Rules:**

- Write a conventional commit summary (`feat:`, `fix:`, `chore:`, ...).
- Do not run git by hand during ship - let the script do it.
- If boundary-audit fails, fix the flagged files and re-run.

**Verdict:** `READY` | `NEEDS FIXES` - report result in <=5 lines.
