# Stack — index

Single source of truth: **`domains/core/`** + **`capabilities/`** + **`contexts/`** → synced to **`.cursor/`** via [`scripts/sync-cursor.ps1`](../scripts/sync-cursor.ps1).

Pipeline skills resolve at runtime via [`scripts/invoke-pipeline.ps1`](../scripts/invoke-pipeline.ps1) (`PIPELINE_SKILL`).

## Global docs

| Document | Content |
|----------|---------|
| [ONBOARDING.md](./ONBOARDING.md) | Install, loop, token economy, hooks |
| [productivity-tools.md](./productivity-tools.md) | Design goals, harness, token layers |
| [context-model.md](./context-model.md) | Execution context, capability packs, sync rules |
| [architecture.md](./architecture.md) | Tool-agnostic workspace architecture |
| [add-child-context.md](./add-child-context.md) | Scaffold a new capability pack |

## Execution contexts

| Context | File | Workspace |
|---------|------|-----------|
| **Platform** (default) | [`contexts/platform.json`](../contexts/platform.json) | [`octo-cluster.code-workspace`](../octo-cluster.code-workspace) |
| **Company scaffolds** | add `contexts/companyN.json` | [`workspaces/companyN-workspace.code-workspace`](../workspaces/) |

Private capability packs (issue tracker, product repos) live in **your fork** or a separate private repo — see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Layout

```
octo-cluster/
  contexts/           # execution context (packs, repos, docs_root)
  capabilities/       # pack manifests + skill.md + providers
  domains/core/       # parent — any-project rules, skills, commands
  domains/companyN/   # optional child scaffolds
  adapters/           # IDE adapter scaffolding
  engine/             # context-engine (LanceDB)
  state/              # local memory indexes (gitignored)
  workspaces/         # multi-root entry points (AI_EXECUTION_CONTEXT)
  scripts/            # sync-cursor, invoke-pipeline, invoke-domain-script
```

Open [`octo-cluster.code-workspace`](../octo-cluster.code-workspace) for platform work. After switching workspace, run sync once.
