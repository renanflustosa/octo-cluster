# ADR-001: Use Linear as primary work tracker

## Status

Accepted

## Context

Octo Cluster needs a structured work tracker for weekly delivery cycles, agent-friendly issues, and OSS governance. GitHub Issues alone lack cycles, initiatives, and structured agent workflows. The project must stay compatible with Linear's free tier.

## Decision

Use the dedicated Linear workspace `octo-cluster` as the **primary** work tracker for all planned development.

- Linear issues use prefix `OCT-`
- GitHub Issues remain for external community reports only (triage into Linear)
- No proprietary issue-tracker routing code in `domains/core/`
- Harness accepts any ticket ID via `/scan OCT-xxx`

## Consequences

- Contributors need Linear access for core team work
- EOS conventions live in `docs/governance/eos.md`
- Manual Linear UI setup required for cycles and GitHub integration
- MCP Linear plugin enables agent issue management without core coupling
