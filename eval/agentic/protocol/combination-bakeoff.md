# Combination bakeoff protocol (4-way)

Manual A/B/C/D protocol for ranking harness tool combinations (ADR-006). Windows 11 + Cursor.

## Goal

Compare **four** `combination_id` arms on the **same** five synthetic cards and declare a winner via `report.ps1 -CompareCombinations`.

## Arms

| combination_id | Intent | Compress | Search/RAG | Gates / promptfoo |
|----------------|--------|----------|------------|-------------------|
| `nada` | Negative control (minimal Octo toggles) | off | off | off (metrics on) |
| `baseline` | Platform defaults **without** compress | **off** | on | on (no promptfoo) |
| `compress-on` | Same as baseline + caveman/ponytail | **on** | on | on (no promptfoo) |
| `octo-full` | Full V1-safe stack | on | on | on + promptfoo/agentic |

Overlays (copy one → `contexts/runtime/platform.local.json`, gitignored):

- [`fixtures/runtime-arms/nada.json`](../fixtures/runtime-arms/nada.json)
- [`fixtures/runtime-arms/baseline.json`](../fixtures/runtime-arms/baseline.json)
- [`fixtures/runtime-arms/compress-on.json`](../fixtures/runtime-arms/compress-on.json)
- [`fixtures/runtime-arms/octo-full.json`](../fixtures/runtime-arms/octo-full.json)

**Caveat `nada`:** synced `.cursor/` rules/skills still load in Cursor. Toggles cannot fully erase IDE context without a clean workspace. Treat `nada` as “Octo runtime toggles off”, not “zero system prompt”.

**Never** enable `okf_index` / `session_hooks` in `octo-full` (ADR-005).

## Card suite (N = 5 per arm → 20 runs)

| id | Fixture |
|----|---------|
| BC-01 | [`fixtures/bakeoff-cards/BC-01.md`](../fixtures/bakeoff-cards/BC-01.md) |
| BC-02 | [`fixtures/bakeoff-cards/BC-02.md`](../fixtures/bakeoff-cards/BC-02.md) |
| BC-03 | [`fixtures/bakeoff-cards/BC-03.md`](../fixtures/bakeoff-cards/BC-03.md) |
| BC-04 | [`fixtures/bakeoff-cards/BC-04.md`](../fixtures/bakeoff-cards/BC-04.md) |
| BC-05 | [`fixtures/bakeoff-cards/BC-05.md`](../fixtures/bakeoff-cards/BC-05.md) |

Use the **exact** prompt block from each fixture on every arm. One card per chat. Prefer docs-only scope as written.

## Directional sample (n=5 paired)

Default SDK bakeoff: **5 cards** (`BC-01`…`BC-05`) × 4 arms = **20** `Agent.prompt` runs, paired by card id. Mean ± IC95% are **directional** (n&lt;30).

```powershell
pwsh eval/agentic/fixtures/run-sdk-bakeoff.ps1
python eval/agentic/fixtures/summarize-bakeoff.py
```

Optional larger sample: `-NCards 30` (120 runs). Key loaded on-demand from vault (never committed).

## Real Agent chats (manual)

See [`REAL-20-CHATS.md`](../fixtures/REAL-20-CHATS.md).  
Helper: `pwsh eval/agentic/fixtures/prepare-bakeoff-chat.ps1 -Arm nada -Card BC-01`  
SDK: `pwsh eval/agentic/fixtures/run-sdk-bakeoff.ps1`

1. Pick arm; copy its JSON over `contexts/runtime/platform.local.json`.
2. Confirm context: `pwsh domains/core/scripts/resolve-execution-context.ps1` shows matching `combination_id`.
3. For each BC-01…BC-05: `/scan` (paste prompt) → `/model` → Execute → `/ship` → `/close`.
4. Switch arm (replace `platform.local.json`); repeat all five cards.
5. Rank:

```powershell
pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50
```

6. **Promote** winner into tracked defaults only after review. **Reject**: note in `harness-catalog.yaml`.

## Consumption when usage skipped

If `usage_source` is not `api`, still rank on `harness_score`, `|diff_net|`, and `context_budget_alerts`. Null `tokens_total` does not disqualify an arm.

## Winner rule

Highest mean `harness_score` over the five cards per arm, with no `gate_pass` regression vs `baseline`; ties → lower tokens (or lower `|diff_net|` if usage skipped).

## Record

Optional: `eval/agentic/results/<date>-4way-bakeoff.md` (gitignored or redact secrets).

## Binary COM vs SEM (n=3, directional)

Separate from the 4-way ranking sample. Answers only: what changes with Octo harness **on** vs **off**.

| Arm | Enforce |
|-----|---------|
| `sem` | `settingSources: []` + empty `.cursor` stub + overlay `nada.json` |
| `com` | `settingSources: ["project"]` + real `.cursor` + overlay `compress-on.json` |

Cards: [`fixtures/bakeoff-cards-v2/`](../fixtures/bakeoff-cards-v2/) (`BD-01`…`BD-03`). Runner: `pwsh eval/agentic/fixtures/run-sdk-com-vs-sem.ps1` (phase 2 gate: `-Phase 2`). Summarize: `python eval/agentic/fixtures/summarize-com-vs-sem.py`.

**Caveat SEM:** SDK/Cursor may still inject product defaults; SEM means zero Octo harness on the agent path, not a blank system prompt.

**Do not promote** defaults from this n=3 sample. If primary signal sd=0 / total tie → mark directional/inconclusivo. Prior 4-way n=5 with overlay-only arms was invalid for ranking (sd=0).

## Binary AS-IS vs Octo-Full (n=5 paired, `harness_score` + `tokens_total`)

Cursor product defaults vs Octo stack máxima V1-safe. Requires `WorkosCursorSessionToken` (vault `DEV/CURSOR/SESSION.json` or env) — abort without attributed tokens.

| Arm | Enforce |
|-----|---------|
| `asis` | `settingSources: []` + empty `.cursor` stub + overlay `nada.json` |
| `full` | `settingSources: ["project"]` + real `.cursor` + overlay `octo-full.json` (OKF hooks still off) |

Cards: [`fixtures/bakeoff-cards-v2/`](../fixtures/bakeoff-cards-v2/) (`BD-01`…`BD-05`). **10 runs** (5 cards × 2 arms), **ABAB order per card** (alternating which arm runs first). Post-run pause default **30s** (`BAKEOFF_PAUSE_MS`); **60s** between cards (`BAKEOFF_INTER_CARD_MS`) when usage overlap is likely.

```powershell
pwsh eval/agentic/fixtures/run-sdk-smoke.ps1
pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -Phase 2 -Sample n5
pwsh eval/agentic/fixtures/run-sdk-asis-vs-full.ps1 -NCards 5 -Sample n5
python eval/agentic/fixtures/summarize-asis-vs-full.py --sample n5 --csv
```

Results: `eval/agentic/results/bakeoff-asis-vs-full-n5-final.json` (gitignored). Summarize emits `statistics.verdict`: `moderate` | `weak_directional` | `inconclusive` (bootstrap IC95% on paired Δ; n&lt;30 — never promote).

Prior n=3 sample (`-Sample n3`, BD-01…03) remains valid for regression; directional only.

**Do not promote.**

## Out of scope

- Headless agent automation
- OKF `sessionStart` hooks
- Consumer-demo / private repos
- Cross-IDE Claude bakeoff (phase 3)
