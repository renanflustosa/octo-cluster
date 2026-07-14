---
name: core-adaptive-loop
description: Universal loop master ref (/scan to /close). Domain-agnostic phase contracts via execution context + invoke-pipeline.
---

# Loop sequence

First `/scan` of the day triggers implicit daily bootstrap (validate, context budget, LanceDB index if stale).

`/scan` â†’ `/model` (Plan â†’ **Execute plan**) â†’ `/ship` â†’ `/close`

**SINGLE CARD MODE:** one chat per ticket; new chat **only** after `/close`.

## Session and read-once rules

- Read this skill **once** per thread (first command that needs it).
- Same phase repeated in chat â†’ skip skill; use prior phase output.
- Pack-specific skills resolve at runtime via `invoke-pipeline.ps1 -Action discover`.

## Phase contracts

| Phase | Mode | Output cap |
|-------|------|------------|
| scan | Agent | â‰¤6 bullets; update `current_task.md` |
| model (plan) | Plan | â‰¤80 lines; no code |
| execute plan | Agent | files changed only; diff-only; **ponytail-lite ladder before each edit** |
| ship | Agent | verify verdict + deliver; â‰¤8 lines |
| close | Agent | â‰¤5 lines; run close script |

## Harness dispatch

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline <scan|model|ship|close> -Action discover
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline <phase> -Action run
powershell -File $env:OCTO_CLUSTER\scripts\invoke-domain-script.ps1 -Name read-gate -ScriptArgs @{ Path = "<file>" }
```

Core fallbacks live in `domains/core/scripts/core-*.ps1`. Pack scripts resolve via execution context.

## Token budget

`@`â‰¤3 Â· Readâ‰¤300 lines Â· grep before Glob/Task Â· no Task agents unless user requests.

## Tool substitutes (zero-token)

Grep Â· Glob Â· LanceDB/context-search Â· read-gate before Read Â· bun test locally.
