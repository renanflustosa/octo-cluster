---
name: ship
description: Check scope, then deliver via scripts/ship.ps1 (direct push or PR when protections are detected).
argument-hint: <conventional commit summary>
disable-model-invocation: true
---

# ship

Deliver the current working tree of the repo in the session's working directory through `scripts/ship.ps1`. The script does all mutating git (stash, branch, add, commit, push, PR); you only check, write the message, run it, and report.

Commit summary: $ARGUMENTS

Octo root (holds the script): !`pwsh -NoProfile -Command '$d = Get-Item "${CLAUDE_SKILL_DIR}"; if ($d.Target) { $d = Get-Item ([string]$d.Target) }; (Resolve-Path (Join-Path $d.FullName "../../..")).Path'`

If plan mode is on, stop: say that `/ship` needs plan mode off (Shift+Tab) and end.

## 1. Check scope

Run from the repo root (PowerShell tool):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -WhatIf
```

It prints the delivery mode and `git status --short`. The script runs `git add -A`, so **everything listed ships**. Stop and ask when the list has files unrelated to this session's work, secrets (`.env*`, keys, `state/`, logs), or large generated artifacts. Read-only git (`status`, `diff`, `log`) is fine; no mutating git by hand.

## 2. Verify (focused)

Run the cheapest check that covers the change: the focused test, lint, or typecheck for the touched files. Skip for docs-only changes. Do not run full suites unless the focused check fails. Failing check → verdict `NEEDS FIXES`, do not ship.

## 3. Message

- Subject: `$ARGUMENTS` if given; else derive one from `git diff --stat` / `git diff`. Conventional commit (`feat:`, `fix:`, `docs:`, `chore:`, ...), imperative, ≤ 72 chars.
- Body (optional): 1-3 bullets on the why, when the subject is not enough.
- Trailer: the session's commit attribution line, if the system prompt gives one.

The subject becomes the PR title; the body goes into the PR description.

## 4. Run

Pass multi-line messages with a single-quoted here-string (closing `'@` at column 0):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -CommitMessage @'
fix: short conventional summary

- why, if needed

Co-Authored-By: ...
'@
```

Delivery mode is auto-detected:

| Protections | Action |
| --- | --- |
| None | Commit + push direct to `main` |
| Any detected | Temp branch `ship/<timestamp>` + PR to `main` (needs `gh`) |

Signals: `scripts/boundary-audit.ps1`, git hooks mentioning audit/gate/boundary, remote branch protection (via `gh`), or `.ship.yaml` / `.ship.json` with `mode: pr` or `protections: true`. `mode: direct` in config overrides.

## 5. On failure

- **boundary-audit failed:** fix the flagged content, re-run step 4. Two failures on the same finding → stop and show the audit output.
- **Failed after `ship-auto-stash`** (stash pop or checkout error): the changes may be in the stash. Run `git stash list`, report it, and stop. Never drop or clear the stash.
- **Push or `gh pr create` failed:** the commit exists locally. Report the error; do not retry with force or `--no-verify`.

## Report

≤ 5 lines: verdict `SHIPPED` | `NEEDS FIXES`, mode and reason, commit subject, and the pushed branch or PR URL.
