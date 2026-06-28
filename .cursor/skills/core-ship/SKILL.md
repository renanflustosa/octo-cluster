---
name: core-ship
description: Core /ship â€” discovered providers, repository-policy git delivery. Domain-agnostic.
---

# /ship â€” verify + gate + repository policy

**Never ship without implicit verify.** If verdict â‰  READY, stop â€” user fixes via Execute plan, then re-runs `/ship`.

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

## Step 1 â€” Verify (implicit)

**Read budget:** â‰¤3 files Â· â‰¤300 lines Â· grep-first

Run scoped checks from the /model validation plan plus epo-policies/<repo>.yaml verify commands (provider epo-policy-verify).

**Optional (non-blocking):** on large diffs (~100+ added lines), run `/minimal-review` or read `minimal-review` skill for a delete-list before verify — does not replace gates.

**Verdict (â‰¤40 lines):** `READY` | `NEEDS FIXES` | `BLOCKED`

| Verdict | Action |
|---------|--------|
| READY | Continue Step 2 |
| NEEDS FIXES | Stop; Execute plan fixes; re-run `/ship` |
| BLOCKED | Stop; report blocker |

## Step 2 â€” Ship (READY only)

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

Git phase uses `repo-policies/default.yaml` merged with `repo-policies/<repo>.yaml` only â€” providers never override git policy.

**Output (â‰¤8 lines):** verify verdict + branch/PR URL + gate result + residual risk

## Customization

| Layer | Location |
|-------|----------|
| Contract | `capabilities/core/ship/contract.yaml` |
| Git strategy | `repo-policies/default.yaml` + `repo-policies/<repo>.yaml` |
| Providers | `capabilities/registry.yaml` + `capabilities/<pack>/ship/manifest.yaml` |

Core must not embed project-specific rules.
