# Stack — index

Single source of truth: **`domains/core/`** + **`capabilities/`** + **`contexts/`** → synced to **`.cursor/`** via [`scripts/sync-cursor.ps1`](../scripts/sync-cursor.ps1).

Pipeline skills resolve at runtime via [`scripts/invoke-pipeline.ps1`](../scripts/invoke-pipeline.ps1) (`PIPELINE_SKILL`).

## Governance

| Document | Content |
|----------|---------|
| [governance/eos.md](./governance/eos.md) | Engineering Operating System (canonical) |
| [governance/linear-workspace-setup.md](./governance/linear-workspace-setup.md) | Linear workspace one-time setup |
| [adr/](./adr/) | Architecture decision records |

## Guides

| Document | Content |
|----------|---------|
| [guides/onboarding.md](./guides/onboarding.md) | Install, loop, token economy |
| [guides/productivity-tools.md](./guides/productivity-tools.md) | Design goals, harness, token layers |
| [guides/add-child-context.md](./guides/add-child-context.md) | Scaffold a capability pack |
| [guides/token-metrics-baseline.md](./guides/token-metrics-baseline.md) | Token metrics baseline |

## Architecture

| Document | Content |
|----------|---------|
| [architecture/overview.md](./architecture/overview.md) | Tool-agnostic workspace architecture |
| [architecture/context-model.md](./architecture/context-model.md) | Execution context, packs, sync |
| [architecture/decoupling-map.md](./architecture/decoupling-map.md) | Decoupling map |
| [architecture/metrics-kernel.md](./architecture/metrics-kernel.md) | Metrics kernel |

## Execution contexts

| Context | File | Workspace |
|---------|------|-----------|
| **Platform** (default) | [`contexts/platform.json`](../contexts/platform.json) | [`octo-cluster.code-workspace`](../octo-cluster.code-workspace) |
| **Company scaffolds** | add `contexts/companyN.json` | [`workspaces/`](../workspaces/) |

Private capability packs live in **your fork** — see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Layout

```text
octo-cluster/
  contexts/           # execution context (packs, repos, docs_root)
  capabilities/       # pack manifests + skill.md + providers
  domains/core/       # parent — any-project rules, skills, commands
  domains/companyN/   # optional child scaffolds
  adapters/           # IDE adapter scaffolding
  engine/             # context-engine (LanceDB)
  state/              # local memory indexes (gitignored)
  workspaces/         # multi-root entry points
  scripts/            # sync-cursor, invoke-pipeline
  docs/
    governance/       # EOS, linear setup
    guides/
    architecture/
    adr/
    api/
```

Open [`octo-cluster.code-workspace`](../octo-cluster.code-workspace) for platform work. After switching workspace, run sync once.

Work tracker: [Linear `octo-cluster`](https://linear.app/octo-cluster) (`OCT-xxx`).
