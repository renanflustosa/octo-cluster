# ADR-001: Use Linear as primary work tracker

## Status

Superseded by [ADR-004](./ADR-004-use-github-issues-as-public-work-tracker.md)

## Context

Octo Cluster needs a structured work tracker for weekly delivery cycles, agent-friendly issues, and OSS governance. GitHub Issues alone lack cycles, initiatives, and structured agent workflows. The project must stay compatible with Linear's free tier.

## Decision

Use the dedicated Linear workspace `octo-cluster` as the **primary** work tracker for all planned development.

- Linear issues use prefix `8CL-` (Octo Cluster team key)
- GitHub Issues remain for external community reports only (triage into Linear)
- No proprietary issue-tracker routing code in `domains/core/`
- Harness accepts any ticket ID via `/scan 8CL-xxx`

## Consequences

- Contributors need Linear access for core team work
- EOS conventions live in `docs/governance/eos.md`
- Manual Linear UI setup required for cycles and GitHub integration
- MCP Linear plugin enables agent issue management without core coupling

## Supersession rationale

The public OSS repository must not expose private maintainer workspace identifiers (`linear.app/…`, `8CL-` prefixes). GitHub Issues and Milestones are sufficient for community contributors. Private team trackers belong in gitignored local overlays or capability packs — see ADR-004.
