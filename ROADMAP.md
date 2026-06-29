# Roadmap

Public priorities for Octo Cluster under the [Engineering Operating System (EOS)](./docs/governance/eos.md).

Tracked in Linear project [**Octo Cluster EOS v1.0.0**](https://linear.app/octo-cluster). No dates until pilot data exists — credibility over hype.

## Now (v0.1.0)

- [x] Public repo split, MIT license, CONTRIBUTING / SECURITY
- [x] PR-only flow: `feature` → `develop` → `main`
- [x] THIRD_PARTY attributions for adapted skills
- [x] CI on every PR (`bun run validate octo-cluster`)
- [x] EOS governance docs, ADRs, CODE_OF_CONDUCT
- [ ] First merge `develop` → `main` with release-please tag `v0.1.0`

## Next — credibility (v0.2.x)

1. **Published token metrics** — card-lite + ponytail-lite A/B on real work items; summary in [guides/token-metrics-baseline.md](./docs/guides/token-metrics-baseline.md). See [`eval/metrics/README.md`](./eval/metrics/README.md).

2. **Harness maturity score** — shareable report from [`scripts/productivity-audit.ps1`](./scripts/productivity-audit.ps1).

3. **Expanded CI** — harness smoke tests, Dependabot enabled.

## Later — reach (0.x → 1.0.0)

4. **Second IDE adapter** — Roo Code or Continue smoke test.

5. **Promptfoo in CI** — optional regression gate.

6. **Adapter cleanup** — `.cursor/` generation toward [`adapters/cursor/`](./adapters/README.md).

## Semver ladder to 1.0.0

| Version | Gate |
|---------|------|
| **0.1.0** | Public harness, basic CI, Cursor validated |
| **0.2.x** | EOS published, metrics baseline, expanded CI |
| **0.x** | ADR process active, feature docs complete, 2nd adapter |
| **1.0.0** | Stable kernel API, eval suite in CI, full OSS governance |

## Out of scope (stay in private packs)

- Employer-specific repos, credentials, client names
- Proprietary issue-tracker routing beyond generic capability pack hooks

## How to suggest changes

Open a Linear issue in the EOS project or a small PR against `develop`. Follow [CONTRIBUTING.md](./CONTRIBUTING.md).
