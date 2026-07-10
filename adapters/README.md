# Adapters

Tool-specific adapter scaffolding. Each adapter consumes `domains/core/` (and optional child domain), generates into `generated/<tool>/`, and avoids business knowledge.

## Available adapters

| Adapter | Path | Status |
|---------|------|--------|
| **Cursor** | [`cursor/`](cursor/) | Active — syncs to `.cursor/` via `scripts/sync-cursor.ps1` |
| **Claude Code** | [`claude/`](claude/) | Stub — Ubuntu + Claude contract (ADR-006 phase 3) |
| **Continue** | [`continue/`](continue/) | Scaffold |
| **Roo Code** | [`roocode/`](roocode/) | Scaffold |

Future adapters should follow the same pattern under `adapters/<tool>/` and output to `generated/<tool>/` (gitignored until promoted).

**Note:** `.cursor/` is currently committed and synced from `domains/core/` for convenience. Long-term target: `generated/cursor/` per adapter README in `adapters/cursor/`.

## Principles

- No consumer-specific identifiers in tracked adapter templates
- Edit IDE-agnostic source in `domains/` first
- Run sync after changes — do not hand-edit generated rules/skills/commands

See [`contexts/permanent/framework-overview.md`](../contexts/permanent/framework-overview.md) and [`docs/architecture/context-model.md`](../docs/architecture/context-model.md).
