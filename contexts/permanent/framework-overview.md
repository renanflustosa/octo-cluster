# Framework overview (permanent)

Stable mental model for octo-cluster. For full detail see [`docs/index.md`](../../docs/index.md).

## Layers

| Layer | Path | Role |
|-------|------|------|
| **Core** | `domains/core/` | Universal rules, skills, commands, harness scripts |
| **Capability packs** | `capabilities/<pack>/` | Pipeline manifests + providers |
| **Execution context** | `contexts/runtime/*.json` | Enabled packs, memory profile, ship repos |
| **Generated adapter** | `.cursor/` | Cursor output — synced from `domains/core/`; committed for convenience |
| **Engine** | `engine/context-engine/` | Bun + LanceDB semantic search (primary) |
| **Legacy engine** | `engine/context/`, `engine/indexing/` | Python helpers — prefer context-engine for new work |

## Sync discipline

1. Edit `domains/core/` (rules, skills, commands) — not `.cursor/` by hand.
2. Run `pwsh scripts/sync-cursor.ps1` after core or capability changes.
3. Pipeline dispatch: `pwsh octo.ps1 -Pipeline <phase> -Action discover|run`.

## Public boundary

Consumer-specific names must not appear in tracked public files. Run `scripts/boundary-audit.ps1` before commit. See [`docs/guides/public-framework-boundary.md`](../../docs/guides/public-framework-boundary.md).

Private overlays (gitignored): `capabilities/_private/`, `domains/_private/`, `contexts/_private/`, `docs/_private/`.

## Merge rules (summary)

- **Commands / skills:** core-only → synced to `.cursor/`
- **Rules / hooks:** core + active child domain overlay
- **Pack skills:** resolved at runtime via `invoke-pipeline.ps1`

See [`docs/architecture/context-model.md`](../../docs/architecture/context-model.md).
