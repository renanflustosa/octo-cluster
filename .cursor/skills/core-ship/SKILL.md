---
name: core-ship
description: Core /ship — discovered providers, repository-policy git delivery. Domain-agnostic.
---

# /ship — verify + gate + repository policy

**Never ship without implicit verify.** If verdict ≠ READY, stop — user fixes via Execute plan, then re-runs `/ship`.

## Orchestration

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run
```

Discovery output (first run):

```text
SHIP_SKILL=<path>
SHIP_REPO=<git root>
SHIP_POLICY=<json>
SHIP_PROVIDERS=<count>
```

Read `SHIP_SKILL` once per thread.

## Step 1 — Verify (implicit)

**Read budget:** ≤3 files · ≤300 lines · grep-first

Run scoped checks from the /model validation plan plus the fast-tier repo-policy checks (provider repo-policy-verify). Pass `-FullVerify` for commands marked `tier: full`.

**Verdict (≤40 lines):** `READY` | `NEEDS FIXES` | `BLOCKED`

| Verdict | Action |
|---------|--------|
| READY | Continue Step 2 |
| NEEDS FIXES | Stop; Execute plan fixes; re-run `/ship` |
| BLOCKED | Stop; report blocker |

## Step 2 — Ship (READY only)

**Gates + git:**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run -Phase gates
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run -Phase git -ScriptArgs @{
  CommitMessage = "<message>"
}
```

Or full pipeline:

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline ship -Action run -ScriptArgs @{
  CommitMessage = "<message>"
}
```

Git phase uses `repo-policies/default.yaml` merged with `repo-policies/<repo>.yaml` only — providers never override git policy.

When `git.auto_merge: true` (see repo policy), the git phase also:

1. Creates/checks out feature branch (or derives from `CARD:` in `current_task.md` when `auto_branch_from_ticket: true`)
2. Commits all tracked/untracked changes (`git add -A`); aborts if anything remains uncommitted after commit
3. Pushes, opens PR against `base_branch`
4. Ensures GitHub `allow_auto_merge` and `delete_branch_on_merge` on the repo (idempotent via `scripts/enable-auto-merge.ps1`) and enables `gh pr merge --auto`
5. Waits for CI and merge when repo policy has `wait_for_merge: true` (default for feature-branch + auto_merge policies); pass `-NoWaitForMerge` to return immediately with `merge_state=auto_merge_enabled`
6. Prunes local branches only after GitHub confirms their PRs were merged; GitHub deletes the remote branch on merge
7. Returns to `base_branch` after merge when `checkout_main_after_merge` is set; it never resets or cleans the worktree automatically

**Worktree contract:** `/ship` never discards local work. With `-NoWaitForMerge`, the operator may remain on the feature branch until the next cleanup or a waited-for merge.

Bot PRs (e.g. Dependabot) auto-merge via `.github/workflows/auto-merge.yml`:

- Triggers on bot PRs (`user.type == Bot`) for `opened`, `synchronize`, `ready_for_review`, and `check_suite.completed`
- Sets `GH_REPO` so `gh` works without checkout; enables `gh pr merge --auto --squash` immediately — GitHub queues merge until required checks pass (no `gh pr checks --watch`; avoids self-referential deadlock)
- Skips conflicting PRs, PRs with failing CI, and PRs that already have auto-merge enabled (fail-safe)
- Remote branch cleanup relies on repo `delete_branch_on_merge` (enabled idempotently by ship)

**Workflow approval gate (after `.github/workflows/*` changes on `main`):** GitHub may block bot PR checks with `action_required` (“Approve workflows to run”). The REST approve endpoint only applies to fork PRs. Recovery without UI:

```powershell
# List blocked runs for the bot PR branch
gh run list --repo <owner>/<repo> --branch <bot-pr-branch> --json databaseId,conclusion,workflowName

# Re-run each run stuck at action_required (CI + auto-merge)
gh run rerun <run-id> --repo <owner>/<repo>
```

After rerun, `auto-merge` should enable squash auto-merge when CI is green. One-time UI approval on the PR also works if `gh run rerun` is unavailable.

Standalone utility: `pwsh scripts/enable-auto-merge.ps1`.

**Git JSON fields (when auto_merge enabled):** `pr_url`, `merged`, `merge_state`, `branch_deleted`, `main_sha`. `SHIP_RESULT` is emitted by the orchestrator. A non-zero exit means a requested waited-for merge could not complete.

When `git.auto_close_after_ship: true` and `CARD:` is set in `current_task.md`, successful git delivery also:

1. Runs discovered **ship phase `close`** providers (e.g. private tracker mark Done)
2. Invokes `core-close.ps1` (memory archive, metrics, wipe `current_task.md`)

Skip auto-close when git success criteria fail (e.g. `merged=false` with `auto_merge`). Manual `/close` remains available.

**Output (≤8 lines):** verify verdict + PR URL + merged + auto-close status + residual risk

## E2E validation (maintainer)

1. `/ship` a trivial change on a feature branch → PR queues auto-merge → waits for merge by default → returns to local `main` when policy enables checkout
2. Merge lands on `main`; remote branch auto-deleted via repo `delete_branch_on_merge`
3. Any bot PR (e.g. Dependabot) auto-merges when CI is green (no manual approve/delete)
4. `-NoWaitForMerge` returns after enabling auto-merge without blocking on CI/merge

## Customization

| Layer | Location |
|-------|----------|
| Contract | `capabilities/core/ship/contract.yaml` |
| Git strategy | `repo-policies/default.yaml` + `repo-policies/<repo>.yaml` |
| Providers | `capabilities/registry.yaml` + `capabilities/<pack>/ship/manifest.yaml` |

Core must not embed project-specific rules.
