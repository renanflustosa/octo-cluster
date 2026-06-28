# Octo Cluster Context Engine

Local-first semantic search and memory indexing for the Octo Cluster harness.

**Nothing is stored in product repos.** Memory and vector indexes live under `state/memory/<profile>/` (gitignored).

## Stack

- **Runtime:** [Bun](https://bun.sh)
- **Vector store:** LanceDB (embedded)
- **Full-text:** SQLite FTS (sidecar)

## Commands

From `engine/context-engine`:

```powershell
bun run validate octo-cluster
bun run index octo-cluster
bun run search octo-cluster "your query"
```

## Profiles

- `octo-cluster` — platform profile (core harness paths only)
- Custom profiles via capability packs — see [`docs/add-child-context.md`](../../docs/add-child-context.md)

## Paths

Resolved via `OCTO_CLUSTER` env var. See `src/lib/paths.ts`.
