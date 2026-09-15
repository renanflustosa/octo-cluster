---
name: ship
description: Verify, then deliver via scripts/ship.ps1 (direct push or PR when protections are detected).
argument-hint: <conventional commit summary>
disable-model-invocation: true
---

# ship

Agent mode. Verify, then deliver via `scripts/ship.ps1` (repo-agnostic). Run it from the root of the repo being delivered.

Commit summary: $ARGUMENTS

**Script:** `<octo>/scripts/ship.ps1`. `<octo>` = octo-cluster root (Cursor: its workspace folder). Claude Code resolved: !`pwsh -NoProfile -Command '$d = Get-Item "${CLAUDE_SKILL_DIR}"; if ($d.Target) { $d = Get-Item ([string]$d.Target) }; (Resolve-Path (Join-Path $d.FullName "../../..")).Path'`

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -CommitMessage "fix: short conventional summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -WhatIf
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
