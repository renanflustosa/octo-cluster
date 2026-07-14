# Cursor adapter

Generates Cursor-specific artifacts from `domains/core/` (and optional child domain overlays).

## Policy

- **Edit source** in `domains/core/` (rules, skills, commands) — not `.cursor/` by hand.
- Run `pwsh scripts/sync-cursor.ps1` after core or capability changes.
- `.cursor/` is **committed for convenience** so the harness works out of the box after clone.
- Long-term multi-tool target: `generated/cursor/` (see [`../README.md`](../README.md)).

Pack skills resolve at runtime via `invoke-pipeline.ps1` and `.cursor/capabilities-skills.json`.

See [`docs/architecture/context-model.md`](../../docs/architecture/context-model.md).
