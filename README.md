# Octo Cluster

<p align="center">
  <img src="./assets/branding/logo-primary.png" alt="Octo Cluster" width="320" />
</p>

**All-in-one local harness for AI-assisted development** — RAG, memory, token economy, hooks, and verify gates in one workspace folder. Maximize automation; use the model only when judgment is required.

> IDE-agnostic by design. **Cursor** is supported today via generated adapters; other IDEs can add a folder adapter the same way.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Engineering Operating System

Octo Cluster follows the [Engineering Operating System (EOS)](./docs/governance/eos.md) — governance, delivery, quality, and AI-agent operations. Planned work is tracked in [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues); see [CONTRIBUTING.md](./CONTRIBUTING.md).

**Agents:** start at [`AGENTS.md`](./AGENTS.md) and [`contexts/context-index.yaml`](./contexts/context-index.yaml).

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

## Early measurement (directional)

We benchmark Octo against Cursor SDK defaults with a **reproducible paired protocol** — not a marketing percentage.

**Latest run (2026-07-10, n=5 paired cards, `composer-2.5`):** Octo-Full showed **lower attributed token usage** in our synthetic suite (median paired Δ −9k tokens/run; bootstrap IC95% −27k to −2k, excludes 0). Task pass rate was **5/5** for both arms. The lightweight score proxy is **inconclusive** at this sample size (IC crosses 0); only 2/5 cards agreed on both score and tokens.

This is **evidence-informed, not a production savings guarantee.** Full method, per-card tables, limitations, and reproduce commands:

**[→ Report: AS-IS vs Octo-Full (2026-07-10)](./eval/agentic/benchmarks/results/2026-07-10-asis-vs-full.md)** · [eval harness](./eval/agentic/README.md#agentic-measurement-directional) · [protocol](./eval/agentic/protocol/combination-bakeoff.md)

## Quick start

**Official dev setup:** Ubuntu 24.04 inside **Dev Container** (same flow on Windows, macOS, or Linux host). **iOS is out of scope** — desktop CLI harness only.

**Prerequisites:** [Git](https://git-scm.com/downloads) and [Docker](https://docs.docker.com/get-docker/) (Desktop on Windows/macOS, Engine on Linux). [Cursor](https://cursor.com) or VS Code with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git <clone-root>
cd <clone-root>
```

Open the folder in Cursor → **Dev Containers: Reopen in Container**. The first build runs [`.devcontainer/post-create.sh`](.devcontainer/post-create.sh) (Bun deps, `.cursor/` sync, memory index, harness audit).

Inside the container (same on every host):

```bash
gh auth login   # once, for PR flow in /ship
pwsh octo.ps1 -Pipeline scan -Action discover
cd engine/context-engine && bun run validate octo-cluster
```

Full guide: [onboarding](./docs/guides/onboarding.md).

**Linux/macOS native (optional, no container):** install `git`, `pwsh`, `bun`, `gh`, `rg`, then `./install.sh`. Use `./scripts/octo` as entry point.

**Windows host bootstrap (optional):** `pwsh -File install.ps1` — sets User-level `OCTO_CLUSTER` without Dev Container.

Env vars are set by the dev container; a consumer-managed IDE workspace covers local terminals when not in a container.

Add this folder as a root in your **local** multi-root workspace (vault, product repos, etc.) — never commit workspace files to this repo.

## Layout

```text
octo-cluster/          ← drop this folder into any multi-root workspace
  domains/core/        rules, skills, commands, harness scripts (IDE-agnostic source)
  capabilities/        pack manifests + pipeline providers
  contexts/            agent context tiers + runtime JSON (contexts/runtime/)
  engine/              context-engine (Bun + LanceDB)
  scripts/             sync adapters, invoke-pipeline, install helpers
  adapters/            IDE/tooling adapter scaffolding
  .cursor/             generated for Cursor — edit domains/, then sync
```

Agent context hub: [`contexts/README.md`](./contexts/README.md). Docs index: [`docs/index.md`](./docs/index.md).

See [context model](./docs/architecture/context-model.md) and [add a capability pack](./docs/guides/add-child-context.md).

## Optional loop (Cursor commands)

One chat ≈ one work item. Phase commands are **optional**; routine edits do not need them.

```text
/start-workspace  →  /scan ISSUE-123 description  →  /model  →  Execute plan  →  /ship  →  /close
```

Discover the active pipeline skill (inside the dev container):

```bash
pwsh octo.ps1 -Pipeline scan -Action discover
```

## Docs

| Doc | Content |
|-----|---------|
| [`contexts/README.md`](./contexts/README.md) | Agent context hierarchy (start here for AI) |
| [`docs/index.md`](./docs/index.md) | Full documentation index |
| [governance/eos.md](./docs/governance/eos.md) | Engineering Operating System (canonical) |
| [onboarding](./docs/guides/onboarding.md) | Full setup |
| [oss-workstation-setup](./docs/guides/oss-workstation-setup.md) | Ubuntu + VSCodium + Continue + Ollama |
| [productivity-tools](./docs/guides/productivity-tools.md) | Harness design, token layers |
| [context-model](./docs/architecture/context-model.md) | Execution context and sync |
| [path-resolution](./docs/architecture/path-resolution.md) | Installation root discovery |
| [add-child-context](./docs/guides/add-child-context.md) | Scaffold a capability pack |
| [public-framework-boundary](./docs/guides/public-framework-boundary.md) | Public vs private overlay audit |
| [agentic benchmark (2026-07-10)](./eval/agentic/benchmarks/results/2026-07-10-asis-vs-full.md) | AS-IS vs Octo-Full paired measurement (directional) |
| [ROADMAP.md](./ROADMAP.md) | Planned work and semver ladder |
| [CHANGELOG.md](./CHANGELOG.md) | Release history |
| [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) | Community standards |
| [THIRD_PARTY.md](./THIRD_PARTY.md) | Attributions |

## Install helpers (optional)

Most tools are pre-installed by [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json).

| Script | Purpose |
|--------|---------|
| [`install.sh`](./install.sh) | Linux/macOS native bootstrap (delegates to `pwsh`) |
| [`install.ps1`](./install.ps1) | Windows host bootstrap (optional) |
| [`scripts/octo`](./scripts/octo) | Bash shim → `octo.ps1` on Unix |
| `scripts/install-go.ps1` | Go via [go.dev](https://go.dev/dl/) MSI or zip |
| `scripts/install-ollama.ps1` | Ollama via official install script |
| `scripts/productivity-audit.ps1` | Local harness health check |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Capability packs that name private products stay in **your fork** or a separate repo; promote shared behavior into `domains/core/`.

## License

[MIT](./LICENSE) © Renan Lustosa — see [THIRD_PARTY.md](./THIRD_PARTY.md) for adapted skills and dependencies.
