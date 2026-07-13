# Stack — index

Single source of truth: **`domains/core/`** + **`capabilities/`** + **`contexts/`** → synced to **`.cursor/`** via [`scripts/sync-cursor.ps1`](../scripts/sync-cursor.ps1).

Pipeline skills resolve at runtime via [`scripts/invoke-pipeline.ps1`](../scripts/invoke-pipeline.ps1) (`PIPELINE_SKILL`).

## Governance

| Document | Content |
|----------|---------|
| [governance/eos.md](./governance/eos.md) | Engineering Operating System (canonical) |
| [governance/agent-pre-push.md](./governance/agent-pre-push.md) | Agent pre-push checklist |
| [assets/branding/](../assets/branding/) | Logos, app icon, favicon, GitHub avatar |
| [adr/](./adr/) | Architecture decision records |

## Guides

| Document | Content |
|----------|---------|
| [guides/onboarding.md](./guides/onboarding.md) | Install, loop, token economy |
| [guides/productivity-tools.md](./guides/productivity-tools.md) | Design goals, harness, token layers |
| [guides/add-child-context.md](./guides/add-child-context.md) | Scaffold a capability pack |
| [guides/token-metrics-baseline.md](./guides/token-metrics-baseline.md) | Token metrics baseline |
| [guides/harness-tool-cluster.md](./guides/harness-tool-cluster.md) | Harness tool catalog + bakeoff |
| [guides/tool-impact-protocol.md](./guides/tool-impact-protocol.md) | TIP — measure external tools before promote |
| [guides/v1-harness-readiness.md](./guides/v1-harness-readiness.md) | V1 config stack certainty (10 layers) |
| [adr/ADR-006-harness-tool-cluster.md](./adr/ADR-006-harness-tool-cluster.md) | Catalog + experiment protocol |

## Architecture

| Document | Content |
|----------|---------|
| [architecture/overview.md](./architecture/overview.md) | Tool-agnostic workspace architecture |
| [architecture/context-model.md](./architecture/context-model.md) | Execution context, packs, sync |
| [architecture/decoupling-map.md](./architecture/decoupling-map.md) | Decoupling map |
| [architecture/metrics-kernel.md](./architecture/metrics-kernel.md) | Metrics kernel |

## Execution contexts

| Context | File | IDE workspace |
|---------|------|---------------|
| **Platform** (default) | [`contexts/runtime/platform.json`](../contexts/runtime/platform.json) | Consumer-managed (outside this repo) |
| **Company scaffolds** | add `contexts/runtime/companyN.json` | Consumer-managed |

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
  scripts/            # sync-cursor, invoke-pipeline
  docs/
    governance/       # EOS
    guides/
    architecture/
    adr/
    api/
```

Open this harness as a folder root inside your **consumer-managed** IDE workspace. After switching workspace, run sync once.

Work tracker: [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues).
