# Roadmap

Public priorities for Octo Cluster. No dates until pilot data exists — credibility over hype.

## Now (v0.1.0 prep)

- [x] Public repo split, MIT license, CONTRIBUTING / SECURITY
- [x] PR-only flow: `feature` → `develop` → `main`
- [x] THIRD_PARTY attributions for adapted skills
- [ ] First merge `develop` → `main` with release-please tag `v0.1.0`

## Next — credibility

1. **Published token metrics** — Run card-lite + ponytail-lite A/B on real work items; publish summary in docs or README (targets: LOC delta, context budget, gate pass rate). See [`eval/metrics/README.md`](eval/metrics/README.md) and [`eval/agentic/README.md`](eval/agentic/README.md).

2. **Harness maturity score** — Extend [`scripts/productivity-audit.ps1`](scripts/productivity-audit.ps1) into a shareable report (tooling installed, index freshness, gate history).

3. **CI on every PR** — GitHub Action running `bun run validate octo-cluster` for `develop` and `main`.

## Later — reach

4. **Second IDE adapter** — Pick Roo Code or Continue; smoke-test sync + one full card loop.

5. **Promptfoo in CI** — Optional regression gate when eval suite is stable.

6. **Adapter cleanup** — Move `.cursor/` generation toward `adapters/cursor/` model documented in [`adapters/README.md`](adapters/README.md).

## Out of scope (stay in private packs)

- Employer-specific repos, credentials, client names
- Proprietary issue-tracker routing beyond generic capability pack hooks

## How to suggest changes

Open a GitHub Issue with the `enhancement` label or a small PR against `develop`. Follow [CONTRIBUTING.md](./CONTRIBUTING.md).
