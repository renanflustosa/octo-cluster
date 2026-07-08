# Stack — index

Single source of truth: **`domains/core/`** + **`capabilities/`** + **`contexts/`** → synced to **`.cursor/`** via [`scripts/sync-cursor.ps1`](../scripts/sync-cursor.ps1).

Pipeline skills resolve at runtime via [`scripts/invoke-pipeline.ps1`](../scripts/invoke-pipeline.ps1) (`PIPELINE_SKILL`).

## Governance

| Document | Content |
|----------|---------|
| [governance/eos.md](./governance/eos.md) | Engineering Operating System (canonical) |
| [assets/branding/](../assets/branding/) | Logos, app icon, favicon, GitHub avatar |
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
| **Platform** (default) | [`contexts/runtime/platform.json`](../contexts/runtime/platform.json) | [`octo-cluster.code-workspace.example`](../octo-cluster.code-workspace.example) |
| **Company scaffolds** | add `contexts/runtime/companyN.json` | [`workspaces/`](../workspaces/) |

## Agent context hierarchy

| Tier | Path | Purpose |
|------|------|---------|
| Hub | [`contexts/README.md`](../contexts/README.md) | Priority map for agents |
| Permanent | [`contexts/permanent/`](../contexts/permanent/) | Stable framework summary |
| Operational | [`contexts/operational/`](../contexts/operational/) + [`contexts/runtime/`](../contexts/runtime/) | Active loop and runtime config |
| Temporary | [`contexts/temporary/`](../contexts/temporary/) | Discardable drafts |

Rules and skills source of truth: `domains/core/` (synced to `.cursor/`).

Private capability packs live in **your fork** — see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Layout

```text
octo-cluster/
  contexts/           # agent context tiers + runtime JSON (contexts/runtime/)
  capabilities/       # pack manifests + skill.md + providers
  domains/core/       # parent — any-project rules, skills, commands
  domains/companyN/   # optional child scaffolds
  adapters/           # IDE adapter scaffolding
  engine/             # context-engine (LanceDB)
  state/              # local memory indexes (gitignored)
  workspaces/         # multi-root entry points
  scripts/            # sync-cursor, invoke-pipeline
  docs/
    governance/       # EOS
    guides/
    architecture/
    adr/
    api/
```

Copy [`octo-cluster.code-workspace.example`](../octo-cluster.code-workspace.example) to `octo-cluster.code-workspace` (gitignored) for platform work, or run `.\install.ps1`. After switching workspace, run sync once.

Work tracker: [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues).
