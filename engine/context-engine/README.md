# Octo Cluster Context Engine

Local-first semantic search and memory indexing for the Octo Cluster harness.

**Nothing is stored in product repos.** Runtime memory lives under `state/memory/<profile>/` (gitignored).

**Bootstrap:** tracked fixtures in `fixtures/profiles/<profile>/` are copied on `install.ps1`, `bun run seed-profile`, and `bun run validate` when files are missing.

## Stack

- **Runtime:** [Bun](https://bun.sh)
- **Vector store:** LanceDB (embedded)
- **Full-text:** SQLite FTS (sidecar)

## Commands

From `engine/context-engine`:

```powershell
bun run validate octo-cluster
bun run seed-profile octo-cluster
bun test src/lib/ensure-profile-seed.test.ts
bun run index octo-cluster
bun run search octo-cluster "your query"
```

## Profiles

- `octo-cluster` — platform profile (core harness paths only)
- Custom profiles via capability packs — see [`docs/guides/add-child-context.md`](../../docs/guides/add-child-context.md)

## Paths

Resolved via `OCTO_CLUSTER` env var. See `src/lib/paths.ts`.
