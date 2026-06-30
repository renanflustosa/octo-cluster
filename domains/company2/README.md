# Company 2 domain (scaffold)

Placeholder child context for a future company or project.

## When ready

1. Add `contexts/company2.json` and `capabilities/company2/` (see [`docs/guides/add-child-context.md`](../../docs/guides/add-child-context.md)).
2. Add rules, hooks, scripts under `domains/company2/`.
3. Open `workspaces/company2-workspace.code-workspace` (sets `AI_EXECUTION_CONTEXT=company2`).
4. Run `.\scripts\sync-cursor.ps1 -Domain company2` from the octo-cluster root.

Pack skills live in `capabilities/company2/` — not synced to `.cursor/skills/`.
