# ADR-004: Use GitHub Issues as public work tracker

## Status

Accepted

## Context

Octo Cluster is a public, consumer-agnostic OSS framework. ADR-001 routed all planned work through a private Linear workspace, exposing maintainer-specific identifiers (`linear.app/…`, `8CL-` prefixes) in README, CONTRIBUTING, templates, and EOS docs. This confuses external contributors and violates the public framework boundary.

GitHub Issues and Milestones provide sufficient structure for OSS governance: labels, assignees, milestones, and PR linking via `Fixes #NNN`.

## Decision

Use [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues) and [Milestones](https://github.com/renanflustosa/octo-cluster/milestones) as the **public** work tracker for all planned development visible in the repository.

- Branch pattern: `<type>/<issue#>-<short-description>` (e.g. `feat/42-add-memory-compaction`)
- PR body links issues via `Fixes #NNN`
- Harness accepts any ticket ID via `/scan ISSUE-123` — no issue-tracker coupling in `domains/core/`
- Private team trackers (Linear, Jira, etc.) may be used by maintainers via capability packs or `docs/_private/` local overlay — never committed to the public tree

Supersedes [ADR-001](./ADR-001-use-linear-as-primary-work-tracker.md).

## Consequences

- OSS contributors need only a GitHub account — no private tracker access
- EOS, CONTRIBUTING, and templates align with GitHub-native workflows
- Maintainers who use private trackers must keep setup docs and conventions in gitignored overlays
- MCP plugins for private trackers remain optional local tooling, not public documentation
