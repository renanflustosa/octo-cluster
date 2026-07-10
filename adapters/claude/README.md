# Claude adapter (stub)

Contract for a future **Ubuntu + Claude Code** adapter. Not implemented in MVP (ADR-006 phase 3).

## Status

Scaffold only — no sync script, no generated tree.

## Principles (same as other adapters)

- Consume IDE-agnostic source from `domains/core/` (+ optional child domain)
- Emit tool-specific assets under `generated/claude/` (gitignored until promoted)
- No consumer-specific identifiers in tracked templates
- Reuse core metrics (`combination_id`, scorecard) — do not fork SQLite schema

## Target mapping (phase 3)

| Octo Cluster | Claude Code / Ubuntu |
|--------------|----------------------|
| `scripts/sync-cursor.ps1` | `adapters/claude/sync-claude.sh` (future) |
| `.cursor/rules`, skills, commands | `.claude/` settings, skills, hooks |
| `domains/core/hooks/hooks.platform.json` | Claude hooks (`SessionStart`, etc.) — respect ADR-005 lessons; do not assume Cursor parity |
| `eval/metrics/*.ps1` | Same Python store; thin bash wrappers calling `python engine/metrics/metrics_db.py` |
| `contexts/runtime/*.json` | Same `combination_id` / `harness_tools` |

## OS matrix

| Host | Shell | Adapter |
|------|-------|---------|
| Windows 11 | PowerShell | `adapters/cursor` (active) |
| Ubuntu | bash | `adapters/claude` (this stub) |

## Non-goals (now)

- Porting mega-brain as the Claude adapter
- Dual-writing hand-edited `.claude/` in the public tree
- Changing core loop commands for Claude-only syntax

## Next implementation slice

1. README + empty `generated/claude/.gitkeep` policy
2. Map core skills → Claude skill format
3. Wire bakeoff protocol on Ubuntu with identical `combination_id` labels

See [adapters/README.md](../README.md) and [harness-tool-cluster.md](../../docs/guides/harness-tool-cluster.md).
