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

Combination bakeoff (harness tool arms): [`protocol/combination-bakeoff.md`](protocol/combination-bakeoff.md) (4-way: nada / baseline / compress-on / octo-full). Binary COM vs SEM (n=3, directional): `fixtures/run-sdk-com-vs-sem.ps1`. Binary AS-IS vs Octo-Full (n=5 paired, `harness_score` + `tokens_total`): `fixtures/run-sdk-asis-vs-full.ps1` + [`fixtures/bakeoff-cards-v2/`](fixtures/bakeoff-cards-v2/) (BD-01…BD-05).

Fixtures: [`fixtures/bakeoff-cards/`](fixtures/bakeoff-cards/), [`fixtures/bakeoff-cards-v2/`](fixtures/bakeoff-cards-v2/), [`fixtures/runtime-arms/`](fixtures/runtime-arms/).

Record results under `results/<date>-consumer-pilot.md`.

## Agentic measurement (directional)

**Comparison:** Cursor SDK defaults (`asis`: empty `.cursor`, `settingSources:[]`, `nada.json`) vs **Octo-Full** (`settingSources:["project"]`, real `.cursor`, `octo-full.json`; OKF/session hooks off).

| | AS-IS | Octo-Full | Paired Δ (full−asis) |
|---|------:|----------:|---------------------|
| Mean `harness_score` | 74.6 | 75.4 | +0.8 [IC95%: −0.4, +2.2] |
| Mean `tokens_total` | 91,308 | 77,537 | −13,771 [IC95%: −27,314, −2,013] |
| `pass` rate | 5/5 | 5/5 | — |

**Run:** n=5 paired cards (BD-01…BD-05), model `composer-2.5`, date 2026-07-10, Windows 11, Cursor Agent SDK local. Order: ABAB per card; 30s post-run pause for token attribution.

**Token breakdown (aggregate means):** AS-IS input 12,174 · output 1,924 · cache_read 77,209 — Octo-Full input 16,057 · output 1,604 · cache_read 59,877. `tokens_total` includes cache in the usage API window.

**Verdict:** `weak_directional:card_variance` — tokens IC95% favors lower usage with Octo-Full (bootstrap does not cross 0); score delta IC95% crosses 0; 2/5 cards agree on both higher score and lower tokens (BD-01, BD-02). `promote: false`.

**Full report (method + per-card):** [benchmarks/results/2026-07-10-asis-vs-full.md](benchmarks/results/2026-07-10-asis-vs-full.md)

### Per-card (paired Δ full−asis)

| Card | Δ score | Δ tokens | assistant_chars (AS-IS→Full) |
|------|--------:|---------:|-------------------------------:|
| BD-01 | +3 | −17,011 | 585 → 439 |
| BD-02 | +2 | −8,634 | 10,411 → 8,670 |
| BD-03 | −1 | +5,306 | 436 → 368 |
| BD-04 | 0 | −8,971 | 492 → 394 |
| BD-05 | 0 | −39,543 | 663 → 705 |

### Limitations

- Small sample (n=5 paired); not CLT-grade; insufficient power for strong significance claims.
- Sequential SDK runs; token attribution uses dashboard API with post-run pause; `cache_read` may dominate.
- Local Windows + single session token; not production, not cloud agents, not other models.
- `harness_score` is a lightweight ADR-006 proxy, not user-perceived quality.
- **Do not** treat as guarantee of production savings.

### Reproduce

1. Vault: `WorkosCursorSessionToken` in `PERSONAL_VAULT/DEV/CURSOR/SESSION.json` (gitignored) + API key file (never commit).
2. Phase 0: `pwsh eval/agentic/fixtures/run-sdk-smoke.ps1`
3. Gate: `pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -Phase 2 -Sample n5`
4. Full: `pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -NCards 5 -Sample n5`
5. Analyze: `python eval/agentic/fixtures/summarize-asis-vs-full.py --sample n5 --csv`
6. Protocol: [combination-bakeoff.md](protocol/combination-bakeoff.md) · [ADR-006](../../docs/adr/ADR-006-harness-tool-cluster.md)
7. Published reports: [benchmarks/](benchmarks/)

*Not a guarantee of production savings; reproducible directional benchmark. `promote: false`.*

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
