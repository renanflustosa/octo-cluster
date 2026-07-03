# ADR-002: Adopt semantic versioning

## Status

Accepted

## Context

Octo Cluster is a public open-source project requiring predictable releases, changelog discipline, and compatibility signaling for capability packs and adapters.

## Decision

Adopt [SemVer 2.0.0](https://semver.org/) for all releases.

- Automated releases via [release-please](https://github.com/googleapis/release-please) on merge to `main`
- [CHANGELOG.md](../../CHANGELOG.md) follows Keep a Changelog
- Commit messages follow Conventional Commits to drive version bumps:
  - PATCH: `fix:`, `perf:`, `security:`
  - MINOR: `feat:`
  - MAJOR: `BREAKING CHANGE` or `feat!:` / `fix!:`

## Consequences

- `develop` integrates features; `main` receives release PRs with tags `v0.x.x`
- Breaking changes require explicit footer and major bump
- GitHub Milestone EOS v1.0.0 is strategic; semver tags track actual releases
