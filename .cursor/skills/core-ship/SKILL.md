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

**Output (≤8 lines):** verify verdict + branch/PR URL + gate result + residual risk

## Customization

| Layer | Location |
|-------|----------|
| Contract | `capabilities/core/ship/contract.yaml` |
| Git strategy | `repo-policies/default.yaml` + `repo-policies/<repo>.yaml` |
| Providers | `capabilities/registry.yaml` + `capabilities/<pack>/ship/manifest.yaml` |

Core must not embed project-specific rules.
