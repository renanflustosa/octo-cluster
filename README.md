# Octo Cluster

<p align="center">
  <img src="./assets/branding/logo-primary.png" alt="Octo Cluster" width="128" />
</p>

**All-in-one local harness for AI-assisted development** — RAG, memory, token economy, hooks, and verify gates in one workspace folder. Maximize automation; use the model only when judgment is required.

> IDE-agnostic by design. **Cursor** is supported today via generated adapters; other IDEs can add a folder adapter the same way.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Linear](https://img.shields.io/badge/Linear-octo--cluster-5E6AD2)](https://linear.app/octo-cluster)

## Engineering Operating System

Octo Cluster follows the [Engineering Operating System (EOS)](./docs/governance/eos.md) — governance, delivery, quality, and AI-agent operations. Work is tracked in [Linear](https://linear.app/octo-cluster) (`8CL-xxx`).

## Why Octo Cluster?

Most teams stitch token savings piecemeal: grep rules here, a RAG script there, ad-hoc hooks, separate eval harnesses. Octo Cluster **bundles the full stack** so cheap layers run first and expensive LLM calls are the exception.

| Layer | Role |
|-------|------|
| **Harness** | Scripts, hooks, repo policies, local gates (`go test`, `bun validate`, Promptfoo, …) |
| **Context engine** | LanceDB semantic search + memory profiles per project |
| **Token economy** | Read budgets, grep-first, compressed task cards, optional “caveman” prose mode |
| **Core loop** | Optional phase commands (`/scan` → `/model` → `/ship` → `/close`) — useful, not required |
| **Capability packs** | Pluggable domain extensions (issue tracker, repos, verify providers) |

```text
[COST 0]  hooks · sync · git · grep · LanceDB · gate scripts
[COST LOW]  scoped Ask / review
[COST HIGH]  plan · execute · ship when harness cannot finish alone
```

## Quick start

**Prerequisites:** [Git](https://git-scm.com/downloads). Windows-first scripts; core concepts are portable.

```powershell
git clone https://github.com/renanflustosa/octo-cluster.git <clone-root>
cd $env:OCTO_CLUSTER
.\install.ps1
gh auth login   # optional, for PR flow in /ship
```

Open [`octo-cluster.code-workspace`](./octo-cluster.code-workspace) in your IDE (Cursor today). On first clone, copy from [`octo-cluster.code-workspace.example`](./octo-cluster.code-workspace.example) or run `.\install.ps1` — it seeds the local file automatically. Set `OCTO_CLUSTER` to your clone root; the workspace file does this automatically.

Add your product repos or a **local gitignored** secrets vault as sibling folders in your workspace copy — never commit those paths to this repo.

## Layout

```text
octo-cluster/          ← drop this folder into any multi-root workspace
  domains/core/        rules, skills, commands, harness scripts (IDE-agnostic source)
  capabilities/        pack manifests + pipeline providers
  contexts/            execution context JSON (enabled packs, ship repos)
  engine/              context-engine (Bun + LanceDB)
  scripts/             sync adapters, invoke-pipeline, install helpers
  adapters/            IDE/tooling adapter scaffolding
  .cursor/             generated for Cursor — edit domains/, then sync
```

See [context model](./docs/architecture/context-model.md) and [add a capability pack](./docs/guides/add-child-context.md).

## Optional loop (Cursor commands)

One chat ≈ one work item. Phase commands are **optional**; routine edits do not need them.

```text
/start-workspace  →  /scan TICKET description  →  /model  →  Execute plan  →  /ship  →  /close
```

Discover the active pipeline skill:

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline scan -Action discover
```

## Docs

| Doc | Content |
|-----|---------|
| [EOS](./docs/governance/eos.md) | Engineering Operating System (canonical) |
| [onboarding](./docs/guides/onboarding.md) | Full setup |
| [productivity-tools](./docs/guides/productivity-tools.md) | Harness design, token layers |
| [context-model](./docs/architecture/context-model.md) | Execution context and sync |
| [add-child-context](./docs/guides/add-child-context.md) | Scaffold a capability pack |
| [public-framework-boundary](./docs/guides/public-framework-boundary.md) | Public vs private overlay audit |
| [ROADMAP.md](./ROADMAP.md) | Planned work and semver ladder |
| [CHANGELOG.md](./CHANGELOG.md) | Release history |
| [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) | Community standards |
| [THIRD_PARTY.md](./THIRD_PARTY.md) | Attributions |

## Install helpers (official sources, no winget)

| Script | Purpose |
|--------|---------|
| `install.ps1` | Bun, gh, ripgrep |
| `scripts/install-go.ps1` | Go via [go.dev](https://go.dev/dl/) MSI or zip |
| `scripts/install-ollama.ps1` | Ollama via official install script |
| `scripts/install-docker.ps1` | Docker Desktop direct download |
| `scripts/productivity-audit.ps1` | Local harness health check |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Capability packs that name private products stay in **your fork** or a separate repo; promote shared behavior into `domains/core/`.

## License

[MIT](./LICENSE) © Renan Lustosa — see [THIRD_PARTY.md](./THIRD_PARTY.md) for adapted skills and dependencies.
