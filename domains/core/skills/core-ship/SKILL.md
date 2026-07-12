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

Run scoped checks from the /model validation plan plus repo-policies/<repo>.yaml verify commands (provider repo-policy-verify).

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
2. Commits, pushes, opens PR against `base_branch`
3. Ensures GitHub `allow_auto_merge` on the repo (idempotent), enables `gh pr merge --auto`, and waits for CI (timeout from `ci_wait_timeout_minutes`)
4. On merge: deletes remote + local branch, checks out `base_branch`

Release-please PRs auto-merge via `.github/workflows/auto-merge.yml` (bot PRs only). Standalone utility: `pwsh scripts/enable-auto-merge.ps1`.

**Git JSON fields (when auto_merge enabled):** `pr_url`, `merged`, `merge_state`, `branch_deleted`, `main_sha`

When `git.auto_close_after_ship: true` and `CARD:` is set in `current_task.md`, successful git delivery also:

1. Runs discovered **ship phase `close`** providers (e.g. private tracker mark Done)
2. Invokes `core-close.ps1` (memory archive, metrics, wipe `current_task.md`)

Skip auto-close when git success criteria fail (e.g. `merged=false` with `auto_merge`). Manual `/close` remains available.

**Output (≤8 lines):** verify verdict + PR URL + merged + auto-close status + residual risk

## Customization

| Layer | Location |
|-------|----------|
| Contract | `capabilities/core/ship/contract.yaml` |
| Git strategy | `repo-policies/default.yaml` + `repo-policies/<repo>.yaml` |
| Providers | `capabilities/registry.yaml` + `capabilities/<pack>/ship/manifest.yaml` |

Core must not embed project-specific rules.
