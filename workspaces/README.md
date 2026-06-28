# Workspaces

Multi-root IDE workspace files. Each sets **`AI_EXECUTION_CONTEXT`** (and optionally `OCTO_CLUSTER`).

After opening a workspace, run sync from the octo-cluster root:

```powershell
cd C:\GitHub\octo-cluster
.\scripts\sync-cursor.ps1
```

For a child domain scaffold (rules/hooks overlay):

```powershell
.\scripts\sync-cursor.ps1 -Domain company2
```

## Mapping

| Workspace file | `AI_EXECUTION_CONTEXT` | Scope |
|----------------|------------------------|-------|
| [`../octo-cluster.code-workspace`](../octo-cluster.code-workspace) | `platform` | Core harness only |
| [`company2-workspace.code-workspace`](./company2-workspace.code-workspace) | `company2` | Scaffold example |
| [`company3-workspace.code-workspace`](./company3-workspace.code-workspace) | `company3` | Scaffold example |
| [`company4-workspace.code-workspace`](./company4-workspace.code-workspace) | `company4` | Scaffold example |

Add your product repos as sibling folders. Keep secrets in a **local gitignored** vault — never in this repo.

## How sync works

`.cursor/` is **generated** from:

- **Commands + skills:** `domains/core/` only
- **Rules + hooks:** `domains/core/` + active child (`domains/<domain>/`)
- **Skill index:** `.cursor/capabilities-skills.json`
- **Pack skills at runtime:** `invoke-pipeline.ps1 -Action discover` → `PIPELINE_SKILL`

See [`docs/context-model.md`](../docs/context-model.md).
