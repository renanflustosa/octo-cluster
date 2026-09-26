---
name: ship
description: Inspect, split into logical commits, validate, then deliver via scripts/ship.ps1 (direct push to main, or branch + PR when main requires it).
argument-hint: [optional scope or notes]
disable-model-invocation: true
---

# ship

Ship the working tree of the repo in the session's working directory: inspect → understand → split logically → validate → commit → pick strategy → push/PR → verify → report. `/ship` is not "commit everything and push".

Notes: $ARGUMENTS

Octo root (holds the script): !`pwsh -NoProfile -Command '$d = Get-Item "${CLAUDE_SKILL_DIR}"; if ($d.Target) { $d = Get-Item ([string]$d.Target) }; (Resolve-Path (Join-Path $d.FullName "../../..")).Path'`

If plan mode is on, stop: say that `/ship` needs plan mode off (Shift+Tab) and end. Work autonomously; ask only on the stop conditions below.

## 1. Inspect (read-only)

From the repo root: `git status --short --branch`, `git diff --stat`, `git diff --cached --stat`, `git log --oneline -10`, `git remote -v`, then:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -WhatIf
```

It fetches `origin/main` and prints the branch, ahead/behind vs `origin/main`, the origin default branch, commits already ahead, and the delivery mode with its reason (config, GitHub branch protection or rulesets, or `unknown`). It modifies nothing.

Stop (`SHIP BLOCKED`) when the state is ambiguous: merge/rebase/cherry-pick in progress, HEAD diverged from `origin/main`, the origin default branch is not `main`, or commits already ahead of `origin/main` that are not clearly part of this work. On another branch with no commits of its own, `git switch main` is a safe move (it carries the working tree).

## 2. Split into logical commits

Read the actual diffs (`git diff`, and the content of untracked files). Group changes into independently understandable commits: one logical change each (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`). Never one giant commit because many files changed; never squash logical changes to cut the count; unrelated changes go in separate commits.

- A file with unrelated hunks → partial staging. `git add -p` is interactive and unavailable: write the hunks to a patch in the scratchpad and `git apply --cached <patch>`, then confirm with `git diff --cached`.
- Do not edit source to make commits cleaner. Preserve all user work: no `stash`, `reset --hard`, `checkout --`, `restore` or `clean` on user files.
- Changes outside the session's work that you cannot attribute: leave them uncommitted and list them in the report.
- Never stage `.env*`, private keys, tokens, credential stores, `state/`, logs, or large generated artifacts. A diff containing credential-like values → stop with `SHIP BLOCKED` naming the file and line, never the value.

## 3. Validate

- Review the final diff of every group.
- Run the project's own checks for the touched areas: package scripts, Makefile, CI workflow, or documented commands, including format/lint/typecheck when they are part of the workflow. Prefer focused checks over full suites; docs-only changes skip checks.
- Failure caused by these changes → `SHIP BLOCKED` before committing. Clearly pre-existing and unrelated → report it and continue only if safe. Never fix unrelated failures here.
- Repo has `scripts/boundary-audit.ps1` → run it with `-Staged` before each commit.

## 4. Commit

If `origin/main` is ahead and you have no local commits, `git pull --ff-only` first (it refuses to overwrite local changes; a refusal is a blocker).

For each group: stage exactly its files/hunks, check `git diff --cached --stat`, commit, then verify with `git log -1 --stat` and `git status --short`.

- Message: `type(scope): description`, imperative, ≤ 72 chars; never `update`, `changes`, `fix stuff`, `misc`, `work`. Optional body: 1-3 bullets on the why. Trailer: the session's commit attribution line, if the system prompt gives one.
- Multi-line messages: single-quoted here-string with the closing `'@` at column 0, e.g. `git commit -m @'` ... `'@`.
- Never `--no-verify`, never amend a pushed commit. A hook failure is fixed at its cause.

## 5. Deliver

The script ships `origin/main..HEAD`. It refuses staged-but-uncommitted changes and a HEAD behind `origin/main`, runs `boundary-audit.ps1` (full) when present, and never stashes, rebases or force-pushes. Uncommitted leftovers stay local.

Mode `direct` (config `mode: direct`, or `main` has no protection requiring PR):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1
```

Pushes `HEAD:main` (fast-forward only) and checks `origin/main` equals HEAD. No feature branch, no PR.

Mode `pr` (config `mode: pr`, or protection/rulesets that block direct pushes):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File <octo>/scripts/ship.ps1 -BranchName feature/short-name -PrTitle 'feat(scope): summary' -PrBody @'
## Summary
- What changed
- Why it changed

## Changes
- Important implementation changes

## Validation
- Checks executed and their results (only what actually ran)

## Commits
- <subject of each commit>

<PR attribution line, if the system prompt gives one>
'@
```

- Branch: `feature/<name>` for features, `fix/<name>` for bug fixes, `chore/<name>` for maintenance; lowercase, named after the actual change. From `main`, the script creates it at HEAD and moves local `main` back to `origin/main` (the commits stay on the branch). Already on a work branch → that branch is pushed.
- PR title: Conventional Commit style. Body: no marketing language; never claim a check passed that did not run.

Mode `unknown` (protection could not be read): pass the PR arguments anyway. The script tries the direct push and falls back to a PR only when GitHub rejects it for protection. Without PR arguments that rejection exits `3`; re-run with them.

## 6. On failure

- **Push rejected as non-fast-forward:** `SHIP BLOCKED`, commits stay local. Never force-push, never rewrite remote history.
- **`gh` missing, auth or permission error:** `SHIP BLOCKED` with the exact error.
- **`gh pr create` failed:** the branch is pushed; report it with the error.
- **boundary-audit failed:** fix the flagged content (amend the unpushed commit that introduced it, or add a commit), re-run step 5. Two failures on the same finding → stop and show the audit output.
- Never delete branches holding user work; never retry with `--force` or `--no-verify`.

## Report

```
SHIP COMPLETE

Strategy: Direct push | Pull Request
Branch: <branch>
Target: main

Commits:
- <sha> <subject>

Validation:
- <check>: PASS/FAIL/SKIPPED

Remote:
- <push/PR result>

PR:
- <URL, if created>
```

On failure:

```
SHIP BLOCKED

Reason:
<exact reason>

Changes committed:
<yes/no>

Changes pushed:
<yes/no>

Recommended next action:
<specific action>
```

Also list any uncommitted changes left out on purpose.
