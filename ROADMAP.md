# Roadmap

Public priorities for Octo Cluster under the [Engineering Operating System (EOS)](./docs/governance/eos.md).

Tracked via [GitHub Issues and Milestones](https://github.com/renanflustosa/octo-cluster/issues). No dates until pilot data exists — credibility over hype.

## Shipped (v0.1.x)

- [x] Public repo split, MIT license, CONTRIBUTING / SECURITY
- [x] PR-only flow: feature branch → `main` (trunk-based)
- [x] THIRD_PARTY attributions for adapted skills
- [x] CI on every PR (`bun run validate octo-cluster`)
- [x] EOS governance docs, ADRs, CODE_OF_CONDUCT
- [x] First release on `main` with release-please tag `v0.1.0`
- [x] Public framework boundary hardening — tagged **`v0.1.1`** (2026-06-30)

**Current release:** `v0.1.1` on `main`. **Next semver target:** `v0.2.x` (credibility milestone below).

## Next — credibility (v0.2.x)

1. **Published token metrics** — card-lite + ponytail-lite A/B on real work items; summary in [guides/token-metrics-baseline.md](./docs/guides/token-metrics-baseline.md). See [`eval/metrics/README.md`](./eval/metrics/README.md).

2. **Harness maturity score** — shareable report from [`scripts/productivity-audit.ps1`](./scripts/productivity-audit.ps1).

3. **Expanded CI** — harness smoke (`productivity-audit -CiSmoke` on Windows); Ubuntu matrix deferred. Dependabot enabled.

## Later — reach (0.x → 1.0.0)

4. **Second IDE adapter** — Roo Code or Continue smoke test.

5. **Promptfoo in CI** — optional regression gate.

6. **Adapter cleanup** — `.cursor/` generation toward [`adapters/cursor/`](./adapters/README.md).

## Semver ladder to 1.0.0

| Version | Gate |
|---------|------|
| **0.1.0** | Public harness, basic CI, Cursor validated |
| **0.1.1** | Public framework boundary audit, consumer-agnostic naming |
| **0.2.x** | EOS published, metrics baseline, expanded CI |
| **0.x** | ADR process active, feature docs complete, 2nd adapter |
| **1.0.0** | Stable kernel API, eval suite in CI, full OSS governance |

## Out of scope (stay in private packs)

- Employer-specific repos, credentials, client names
- Proprietary issue-tracker routing beyond generic capability pack hooks

## How to suggest changes

Open a [GitHub issue](https://github.com/renanflustosa/octo-cluster/issues/new/choose) or a small PR against `main`. Follow [CONTRIBUTING.md](./CONTRIBUTING.md).
