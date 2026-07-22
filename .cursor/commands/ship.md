# ship

Agent mode. Verify, then deliver via `scripts/ship.ps1` (repo-agnostic).

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -CommitMessage "fix: short conventional summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -WhatIf
```

**Delivery mode (auto-detected):**

| Protections | Action |
| --- | --- |
| None | Commit + push direct to `main` |
| Any detected | Temp branch `ship/<timestamp>` + PR to `main` |

Protection signals: `scripts/boundary-audit.ps1`, git hooks referencing audit/gate, remote branch protection (best-effort via `gh`), or `.ship.yaml` / `.ship.json` with `mode: pr` or `protections: true`. Override with `mode: direct` in config.

**Rules:**

- Conventional commit summary (`feat:`, `fix:`, `chore:`, ...).
- Do not run git by hand during ship — let the script do it.
- If boundary-audit exists and fails, fix and re-run.
- PR mode requires `gh` CLI.

**Verdict:** `READY` | `NEEDS FIXES` — report result in <=5 lines.
