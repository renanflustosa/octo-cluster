# Context-engine evolution POC

**Decision (initial):** **Keep DIY LanceDB** (`engine/context-engine/`) + manual L0/L1/L2 memory until a pilot card proves meaningful token savings without quality loss.

## Why not migrate yet

| Criterion | DIY (current) | External RAG tools |
|-----------|---------------|-------------------|
| L0/L1/L2 | Manual `overview` + `current_task` + `context/*` | Auto tiers (varies) |
| Windows + Bun stack | Works today | Extra services |
| MCP overhead | None (scripts) | Medium |
| Multi-repo profiles | Per-profile memory | Cross-project hub |
| Data locality | `state/memory/` only | Varies |

## Pilot protocol

1. Baseline one full card with slim loop + compression.
2. Compare external tool vs DIY on: retrieval hits, setup minutes, tokens in scan+execute, wrong-file reads.

## Primary stack

DIY LanceDB + FTS5 hybrid (`engine/context-engine/`).

## Metrics

Lite at `/close` · Full weekly at first `/scan` of the week. See [`metrics/README.md`](metrics/README.md).

## Agentic eval

[`agentic/`](agentic/) — diff LOC + safety fixtures for manual pilot cards.
