# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1](https://github.com/renanflustosa/octo-cluster/compare/v0.1.0...v0.1.1) (2026-06-30)


### Bug Fixes

* enforce public framework boundary and consumer-agnostic naming ([f82abed](https://github.com/renanflustosa/octo-cluster/commit/f82abedb54994f3037164568866371c24c73a8a6))
* enforce public framework boundary and consumer-agnostic naming ([f68e18b](https://github.com/renanflustosa/octo-cluster/commit/f68e18b45a6f114e8c31b9253eeaf9e00030f4b3))

## [Unreleased]

### Planned

See [ROADMAP.md](./ROADMAP.md).

## [0.1.0] - 2026-06-29

First public stable release.

### Added

- All-in-one local harness for AI-assisted development (RAG, memory, token economy, verify gates)
- CORE loop phase commands: `/scan` → `/model` → Execute plan → `/ship` → `/close`
- Context engine: LanceDB + Bun semantic search with per-profile memory (`engine/context-engine/`)
- Token economy: read budgets, grep-first, caveman-lite prose mode, ponytail-lite implementation ladder
- Capability packs and execution contexts (`capabilities/`, `contexts/`)
- Ship pipeline: discovered providers, repo policies, feature-branch → PR delivery
- Branch protection helper and GitHub ruleset script (`scripts/protect-branches.ps1`)
- Metrics scaffold: card-lite on `/close`, harness-full weekly audit (`eval/metrics/`)
- Optional Promptfoo eval gate (`eval/promptfoo/`)
- Agentic A/B pilot tooling for LOC comparison (`eval/agentic/`)
- Install bootstrap: Bun, gh, ripgrep, context-engine deps (`install.ps1`)
- OSS docs: THIRD_PARTY, CHANGELOG, ROADMAP, CI, release-please
- Profile seed fixtures for CI validate (`engine/context-engine/fixtures/`)
- **Validated IDE:** Cursor (via `scripts/sync-cursor.ps1` → `.cursor/`)

### Features

* public octo-cluster harness (core-only split from ai-workspace) ([2ee89d1](https://github.com/renanflustosa/octo-cluster/commit/2ee89d1040f8aa5169a94664d56543a5cda968d7))

### Bug Fixes

* align release-please manifest root key ([d36f1f7](https://github.com/renanflustosa/octo-cluster/commit/d36f1f7547a9e03665194cf328cfa19f1d4e3ba9))
* github ruleset required pull_request fields ([25dfd64](https://github.com/renanflustosa/octo-cluster/commit/25dfd64cb6473a2e5df42383961271ce8fdf28ca))
* null-safe context-engine exit codes and stale OCTO_CLUSTER resolution ([c8972aa](https://github.com/renanflustosa/octo-cluster/commit/c8972aa2afa5e6f5c69cff7d55208633a734cb9b))
* resolve OCTO_CLUSTER path and ship git chain ([da19c9c](https://github.com/renanflustosa/octo-cluster/commit/da19c9c2cd77af6598c28354a9847553e9301983))
* seed memory profile from fixtures in CI validate ([33e7165](https://github.com/renanflustosa/octo-cluster/commit/33e71657bc4d3ac4243ff23743e02f2bde64fc5a))
* ship git reuse existing PR on push ([85ee4d3](https://github.com/renanflustosa/octo-cluster/commit/85ee4d37c7a790728b4bfbc11c9c7f09000941b0))

### Documentation

* THIRD_PARTY attributions and OSS changelog ([5de64d9](https://github.com/renanflustosa/octo-cluster/commit/5de64d9cfbe520eb80cd34cfc120a5ff98e9ac21))

### Not yet validated

- Roo Code, Continue, Claude Code, Windsurf adapters (scaffolding under `adapters/` only)

[Unreleased]: https://github.com/renanflustosa/octo-cluster/compare/v0.1.0...develop
[0.1.0]: https://github.com/renanflustosa/octo-cluster/releases/tag/v0.1.0
