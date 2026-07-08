# ADR-003: Provider-agnostic architecture

## Status

Accepted

## Context

Octo Cluster must integrate with multiple IDEs, LLM providers, issue trackers, and capability packs without hardcoding vendor-specific logic in the core harness.

## Decision

Split the repository into:

- **CORE** (`domains/core/`, `capabilities/core/`) — agnostic loop, rules, scripts, RAG patterns
- **Capability packs** (`capabilities/<pack>/`, `contexts/`) — domain-specific routing, repos, providers
- **Adapters** (`adapters/`) — IDE-specific sync (Cursor validated first)
- **Execution context** (`contexts/runtime/*.json`) — runtime dispatch via `AI_EXECUTION_CONTEXT`

Promotion rule: behavior needed by two or more packs moves to CORE; product-specific logic stays in packs.

## Consequences

- `.cursor/` is generated — edit `domains/` and `capabilities/`, then sync
- Private issue tracker integration is documentation + MCP via capability packs, not core code
- New adapters (Roo Code, Continue) plug in without changing the kernel loop
- Child domains scaffold under `domains/companyN/` for private extensions
