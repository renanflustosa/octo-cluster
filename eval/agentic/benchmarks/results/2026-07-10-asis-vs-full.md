# AS-IS vs Octo-Full — paired bakeoff report (2026-07-10)

Directional measurement of Cursor SDK defaults against the Octo V1-safe stack on synthetic agent cards. **Not a production savings guarantee.** `promote: false`.

Related: [combination-bakeoff.md](../../protocol/combination-bakeoff.md) · [ADR-006](../../../docs/adr/ADR-006-harness-tool-cluster.md) · [eval/agentic/README.md](../../README.md#agentic-measurement-directional)

## Hypothesis

With real harness enforcement (rules, skills, runtime overlay, `settingSources`), **Octo-Full** should:

1. Keep **task pass rate** (scope/YAGNI checkers) at least equal to AS-IS.
2. Reduce **attributed token usage** on cards that reward grep-first, prose compression, and YAGNI.
3. Improve or match a lightweight **harness_score** proxy (ADR-006 weights).

We test this with paired runs on the same five cards — not with a single headline percentage.

## Method

### Arms (enforced)

| Arm | `settingSources` | `.cursor` | Runtime overlay | `combination_id` |
|-----|------------------|-----------|-----------------|------------------|
| **AS-IS** | `[]` | empty stub | `nada.json` | `nada` |
| **Octo-Full** | `["project"]` | synced project rules/skills | `octo-full.json` | `octo-full` |

OKF `sessionStart` / session hooks remain **off** (ADR-005). Runner verifies overlay + rules hash before each run (`enforce_ok`).

### Card suite (n = 5 paired → 10 runs)

| Card | Type | Fixture |
|------|------|---------|
| BD-01 | YAGNI / scope | [BD-01.md](../../fixtures/bakeoff-cards-v2/BD-01.md) |
| BD-02 | Prose / compress | [BD-02.md](../../fixtures/bakeoff-cards-v2/BD-02.md) |
| BD-03 | Search / ADR | [BD-03.md](../../fixtures/bakeoff-cards-v2/BD-03.md) |
| BD-04 | Catalog search | [BD-04.md](../../fixtures/bakeoff-cards-v2/BD-04.md) |
| BD-05 | YAGNI / oneliner | [BD-05.md](../../fixtures/bakeoff-cards-v2/BD-05.md) |

Each run: one `Agent.prompt` per card per arm. Checkers: marker in allowlisted file + no extra dirty paths ([`bd-check.mjs`](../../fixtures/checkers/bd-check.mjs)).

### Run design (token attribution)

- **Order:** ABAB per card — arm order alternates by card index to balance sequencing bias.
- **Post-run pause:** 30s (`BAKEOFF_PAUSE_MS`) before usage API poll.
- **Inter-card pause:** up to 60s after each card pair when overlap risk is high.
- **Tokens:** Cursor dashboard usage API delta since per-run baseline (`cursor-usage.ps1`); requires `WorkosCursorSessionToken` (vault, gitignored).
- **Primary metrics:** `harness_score`, `tokens_total` (+ `tokens_input`, `tokens_output`, `tokens_cache_read`).

### Environment (as run)

| Field | Value |
|-------|-------|
| Date | 2026-07-10 |
| Model | `composer-2.5` |
| Host | Windows 11, Cursor Agent SDK local |
| Harness | `run-sdk-asis-vs-full.ps1` → `run-asis-vs-full.mjs` |
| Sample id | `n5` |
| Raw JSON | `eval/agentic/results/bakeoff-asis-vs-full-n5-final.json` (gitignored) |

### Statistical analysis

Paired deltas **full − asis** per card; aggregated n = 5:

| Analysis | Method |
|----------|--------|
| Mean Δ + IC95% | Bootstrap paired (10k resamples, seed 42) |
| Secondary IC | Student t, df = 4 |
| Effect size | Cohen's d on paired Δ |
| Tokens robustness | Median Δ, Wilcoxon signed-rank (W+, direction only) |
| Pass discordance | McNemar (none in this run) |

**Verdict rules:** `moderate` if both primary IC95% exclude 0 in the same favorable direction and ≥4/5 cards agree; `weak_directional` if signal is mixed; `inconclusive` if tokens missing or both ICs cross 0.

Power note: n = 5 paired is **not** CLT-grade (~25–35% power for d = 0.8 at α = 0.05).

## Results (aggregate)

| | AS-IS | Octo-Full | Paired Δ (full−asis) |
|---|------:|----------:|---------------------|
| Mean `harness_score` | 74.6 | 75.4 | +0.8 [IC95% boot: −0.4, +2.2] |
| Mean `tokens_total` | 91,308 | 77,537 | −13,771 [IC95% boot: −27,314, −2,013] |
| `pass` | 5/5 | 5/5 | McNemar discordant: 0 |

**Token breakdown (arm means):**

| Arm | input | output | cache_read |
|-----|------:|-------:|-----------:|
| AS-IS | 12,174 | 1,924 | 77,209 |
| Octo-Full | 16,057 | 1,604 | 59,877 |

`tokens_total` includes `cache_read` in the API window — not isolated marginal cost.

**Verdict:** `weak_directional:card_variance`

- Tokens: bootstrap IC95% **does not cross 0** (direction: lower with Octo-Full); Wilcoxon direction `full_lower_tokens`.
- Score: bootstrap IC95% **crosses 0** — inconclusive on harness proxy.
- Card agreement (score↑ and tokens↓): **2/5** (BD-01, BD-02 only).

## Per-card paired results

| Card | Δ score | Δ tokens | AS-IS tok | Full tok | assistant_chars (A→F) | Notes |
|------|--------:|---------:|----------:|---------:|------------------------:|-------|
| BD-01 | +3 | −17,011 | 57,739 | 40,728 | 585 → 439 | YAGNI: both pass; full shorter |
| BD-02 | +2 | −8,634 | 83,259 | 74,625 | 10,411 → 8,670 | Compress card; prose ↓ on full |
| BD-03 | −1 | +5,306 | 53,901 | 59,207 | 436 → 368 | Search; **discordant** (repeat from n=3) |
| BD-04 | 0 | −8,971 | 119,148 | 110,177 | 492 → 394 | Catalog search |
| BD-05 | 0 | −39,543 | 142,492 | 102,949 | 663 → 705 | YAGNI; largest token delta |

## What we conclude

**Supported (directional, n = 5):**

- Octo-Full **does not regress pass rate** on this synthetic suite (5/5 both arms).
- **Attributed total tokens** trend lower with Octo-Full in aggregate; bootstrap IC excludes 0.
- Cards **BD-01** and **BD-02** show the intended harness behaviors (scope discipline, shorter prose).

**Not supported:**

- A strong claim that Octo-Full improves **harness_score** (IC includes 0).
- Uniform savings across card types (BD-03 still discordant).
- Production or bill-level **%** savings without n ≥ 30 and real-repo tasks.

**Do not promote** into `platform.json` from this sample.

## Comparison to prior n = 3

| Metric | n = 3 (BD-01…03) | n = 5 (BD-01…05) |
|--------|-------------------|------------------|
| Δ score mean | +2.0 | +0.8 |
| Δ tokens mean | −9,621 | −13,771 |
| BD-03 | discordant | still discordant |
| Token attribution | 6/6 | 10/10 |
| Run order | arm-major (biased) | ABAB per card |

n = 5 adds statistical tooling (bootstrap, verdict enum) and two new cards; score signal **weakened**, token signal **similar direction**.

## Reproduce

```powershell
# Prerequisites: API key file + WorkosCursorSessionToken in vault (never commit)
pwsh eval/agentic/fixtures/run-sdk-smoke.ps1
pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -Phase 2 -Sample n5
pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -NCards 5 -Sample n5
python eval/agentic/fixtures/summarize-asis-vs-full.py --sample n5 --csv
```

Summarize writes `eval/agentic/results/bakeoff-asis-vs-full-n5-summary.json` (gitignored).

## Next steps (stronger public claims)

1. **n ≥ 30** paired repetitions (or 5 cards × 6+ reps) to narrow IC95%.
2. **Real-repo agentic suite** (Ponytail-style): `git diff` LOC + safety execution on public template.
3. Pin Cursor / SDK versions in run metadata; third-party reproduction note.
4. Keep README hero to **one conditional sentence** linked to this report.

---

*Report generated from run 2026-07-10. Numbers match `bakeoff-asis-vs-full-n5-summary.json` at time of publication.*
