# Agent contract — octo-cluster

Local AI-assisted development harness. Tool-agnostic operating rules.

## Read order

1. This file (`AGENTS.md`)
2. [`contexts/context-index.yaml`](contexts/context-index.yaml) — declarative priority map
3. [`domains/core/rules/`](domains/core/rules/) — always-apply rules (synced to `.cursor/rules/`)
4. [`contexts/permanent/`](contexts/permanent/) — stable framework summary
5. [`contexts/operational/`](contexts/operational/) — active loop and CLI entry points
6. [`contexts/runtime/`](contexts/runtime/) — execution JSON (via `AI_EXECUTION_CONTEXT`, default `platform`)
7. [`docs/index.md`](docs/index.md) — deep reference (EOS, guides, architecture)

Details: [`contexts/operational/agent-loop.md`](contexts/operational/agent-loop.md).

## Before making changes

- Identify active execution context (`AI_EXECUTION_CONTEXT` → `contexts/runtime/<id>.json`).
- Read consumer-boundary rules before any public git change.
- Edit **source** in `domains/core/` and `capabilities/` — not `.cursor/` by hand.
- After domain or capability changes, run `pwsh scripts/sync-cursor.ps1`.

## Never auto-load

See [`contexts/context-index.yaml`](contexts/context-index.yaml) `never_auto_load`. Includes:

- `state/` (local memory indexes)
- `contexts/temporary/`
- `capabilities/_private/`, `domains/_private/`, `contexts/_private/`, `docs/_private/`
- `engine/context-engine/node_modules/`, `generated/`, `.git/`

Index exclusions: [`.aiignore`](.aiignore) (canonical); [`.cursorignore`](.cursorignore) mirrors it for Cursor.

## Destructive changes

- Run `pwsh scripts/boundary-audit.ps1` before committing to the public tree.
- Do not move runtime JSON without updating harness loaders (PS1 + context-engine).
- Present a plan before large refactors.

## Large changes

Explain scope and run validation:

```powershell
pwsh domains/core/scripts/resolve-execution-context.ps1
cd engine/context-engine && bun run validate octo-cluster
```

## Human index

[`README.md`](README.md) — setup and layout for humans.
