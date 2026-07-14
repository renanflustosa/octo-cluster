# Agent loop (operational)

Operational supplement during active development. **Contract:** [`../../AGENTS.md`](../../AGENTS.md).

Phase commands are **optional** — routine edits do not require them.

## Optional loop

```text
/scan  →  /model  →  Execute plan  →  /ship  →  /close
```

Meta (no pipeline): `/prompt` — rewrite only, never execute. Also: `/review`, `/debug`.

One chat ≈ one work item.

## CLI entry points

| Entry | Command |
|-------|---------|
| Pipeline | `pwsh octo.ps1 -Pipeline scan\|model\|ship\|close\|review\|debug -Action discover\|run` |
| Domain tools | `pwsh octo-domain.ps1` — context-search, read-gate |
| Sync adapter | `pwsh scripts/sync-cursor.ps1` |
| Boundary audit | `pwsh scripts/boundary-audit.ps1` |

Discover active pipeline skill:

```bash
pwsh octo.ps1 -Pipeline scan -Action discover
```

## Environment variables

| Variable | Purpose |
|----------|---------|
| `OCTO_CLUSTER` | Repo root (set by install scripts or IDE workspace) |
| `AI_EXECUTION_CONTEXT` | Selects `contexts/runtime/<id>.json` (default: `platform`) |

## Pipeline → skill (platform)

| Pipeline | Skill |
|----------|-------|
| scan, model, close | `domains/core/skills/core-adaptive-loop/SKILL.md` |
| ship | `domains/core/skills/core-ship/SKILL.md` |
| review | `domains/core/skills/code-review/SKILL.md` |
| debug | `domains/core/skills/systematic-debugging/SKILL.md` |

Private packs may override when enabled in `contexts/runtime/*.json`.

## Validation smoke

```bash
cd engine/context-engine && bun run validate octo-cluster
```

See [`docs/guides/onboarding.md`](../../docs/guides/onboarding.md).
