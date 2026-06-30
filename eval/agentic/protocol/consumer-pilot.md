# Consumer demo manual A/B pilot — ponytail-lite

One real ticket, two arms, same scope. Repo pinned at start.

## Prerequisites

- `octo-cluster` synced (`.\scripts\sync-cursor.ps1`)
- `consumer-demo` clone with `develop` up to date
- `python eval/agentic/score-safety.py --selftest` passes
- Ticket chosen: feature with **over-build risk** (UI widget, new helper lib, wrapper layer)

## Steps

| Step | Action |
|------|--------|
| 1 | Pick ticket DEMO-XXX; note repo SHA at pilot start |
| 2 | **Arm A (baseline):** branch from pin without `ponytail-lite` rule (or pre-integration commit); full card `/scan` → `/model` → Execute → `/ship` |
| 3 | **Arm B (ponytail-lite):** fresh branch from same pin; sync with ponytail-lite; same ticket wording |
| 4 | Score each arm: `score-diff.ps1 -RepoRoot <consumer-demo> -BaseRef <pin-sha> -HeadRef HEAD -ExcludeTests` |
| 5 | Run verify gates: `go build ./...` and `go vet ./...` in `consumer-backend` (per `repo-policies/consumer-demo.yaml`) |
| 6 | If backend touched trust boundaries (paths, SQL, auth, CSV parse): run applicable `score-safety.py --task ...` on produced module |
| 7 | Write `eval/agentic/results/<YYYY-MM-DD>-consumer-pilot.md` |

## Results template

```markdown
# Consumer demo pilot — YYYY-MM-DD

Ticket: DEMO-XXX
Pin SHA: abc123

| Arm | added LOC | net LOC | files | go build | go vet | safety |
|-----|-----------|---------|-------|----------|--------|--------|
| baseline | | | | pass/fail | pass/fail | n/a or pass |
| ponytail-lite | | | | pass/fail | pass/fail | n/a or pass |

LOC delta vs baseline: -X%

Notes:
- ...
```

## Optional controls

- **caveman-only:** same as B but temporarily disable ponytail-lite rule — isolates prose effect
- **yagni-oneliner:** add ephemeral user rule only — compare to full skill

## Do not

- Mix two tickets in one comparison
- Change ticket wording between arms
- Count test file LOC unless comparing with `-ExcludeTests:$false` on both arms
