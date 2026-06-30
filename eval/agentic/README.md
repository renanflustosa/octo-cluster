# Agentic eval — scoring + manual pilot

Reusable metrics for comparing implementation arms (baseline vs ponytail-lite) on real cards.
Inspired by [Ponytail agentic benchmark](https://github.com/DietrichGebert/ponytail/blob/main/benchmarks/agentic/README.md).

**Phase 1:** scoring scripts + manual protocol — no headless agent automation.

## Tools

| Script | Purpose |
|--------|---------|
| [`score-diff.ps1`](score-diff.ps1) | `git diff` added/deleted/net LOC as JSON |
| [`score-safety.py`](score-safety.py) | Deterministic safety checks (stdlib only) |

### score-diff.ps1

```powershell
powershell -File eval/agentic/score-diff.ps1 -RepoRoot $env:CONSUMER_DEMO_ROOT -BaseRef develop -HeadRef HEAD
powershell -File eval/agentic/score-diff.ps1 -RepoRoot $env:CONSUMER_DEMO_ROOT -ExcludeTests
```

Output: `{"added":N,"deleted":M,"net":N-M,"files_changed":K,...}`

### score-safety.py

```powershell
python eval/agentic/score-safety.py --selftest
python eval/agentic/score-safety.py --task safe-path --module path/to/module.py --function safe_upload_path
```

Tasks: `safe-path`, `sql-user`, `auth-token`, `csv-sum`, `rate-limit`.

Run `--selftest` before any pilot — good refs must pass, bad refs must fail.

## Manual pilot

See [`protocol/consumer-pilot.md`](protocol/consumer-pilot.md).

Record results under `results/<date>-consumer-pilot.md`.

## Arms (manual)

| Arm | Configuration |
|-----|----------------|
| `baseline` | octo-cluster without ponytail-lite (historical branch or disable rule) |
| `ponytail-lite` | CORE with `ponytail-lite.mdc` + skill synced |
| `caveman-only` | Control — prose compression only |
| `yagni-oneliner` | Control — user rule "Follow YAGNI; prefer one-liner solutions" |

## Promotion criteria

Adopt ponytail-lite as default when a pilot card shows **>20% LOC reduction** vs baseline **without** verify gate failure or safety regression.

## Not in phase 1

- Headless Cursor/Claude Code harness (`run.py`)
- LLM judges (over-engineering / completeness)
- Blocking ship provider for agentic scores

## Related

- Shape-only eval: [`../promptfoo/`](../promptfoo/)
- Context pilot: [`../README.md`](../README.md)
