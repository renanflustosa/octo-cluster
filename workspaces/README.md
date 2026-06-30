# Workspaces

Multi-root IDE workspace files. Each sets **`AI_EXECUTION_CONTEXT`** (and optionally `OCTO_CLUSTER`).

After opening a workspace, run sync from the octo-cluster root:

```powershell
cd "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))"
.\scripts\sync-cursor.ps1
```

For a child domain scaffold (rules/hooks overlay):

```powershell
.\scripts\sync-cursor.ps1 -Domain company2
```

## Mapping

| Workspace file | `AI_EXECUTION_CONTEXT` | Scope |
|----------------|------------------------|-------|
| [`../octo-cluster.code-workspace.example`](../octo-cluster.code-workspace.example) | `platform` | Core harness (copy to `octo-cluster.code-workspace` locally) |
| [`company2-workspace.code-workspace`](./company2-workspace.code-workspace) | `company2` | Scaffold example |
| [`company3-workspace.code-workspace`](./company3-workspace.code-workspace) | `company3` | Scaffold example |
| [`company4-workspace.code-workspace`](./company4-workspace.code-workspace) | `company4` | Scaffold example |

`octo-cluster.code-workspace` is **gitignored** — copy from `.example` or run `.\install.ps1`. Optionally add sibling folders (your app, local secrets vault) in your local copy only.

## How sync works

`.cursor/` is **generated** from:

- **Commands + skills:** `domains/core/` only
- **Rules + hooks:** `domains/core/` + active child (`domains/<domain>/`)
- **Skill index:** `.cursor/capabilities-skills.json`
- **Pack skills at runtime:** `invoke-pipeline.ps1 -Action discover` → `PIPELINE_SKILL`

See [`docs/architecture/context-model.md`](../docs/architecture/context-model.md).
