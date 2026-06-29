# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

See [ROADMAP.md](./ROADMAP.md).

## [0.1.0] - TBD

First stable release when `develop` merges to `main`.

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
- **Validated IDE:** Cursor (via `scripts/sync-cursor.ps1` → `.cursor/`)

### Not yet validated

- Roo Code, Continue, Claude Code, Windsurf adapters (scaffolding under `adapters/` only)

[Unreleased]: https://github.com/renanflustosa/octo-cluster/compare/v0.1.0...develop
[0.1.0]: https://github.com/renanflustosa/octo-cluster/releases/tag/v0.1.0
