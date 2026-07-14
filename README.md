# Octo Cluster

<p align="center">
  <img src="./assets/branding/logo-primary.png" alt="Octo Cluster" width="320" />
</p>

**All-in-one local harness for AI-assisted development** — RAG, memory, token economy, hooks, and verify gates in one workspace folder. Maximize automation; use the model only when judgment is required.

> IDE-agnostic by design. **Cursor** is supported today via generated adapters; other IDEs can add a folder adapter the same way.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Mission

Make high-quality generative AI accessible to anyone using open source software and free tools.

Octo Cluster is a **means**, not the end — a local harness that helps you build and ship with AI while keeping expensive model calls the exception, not the default.

## Principles

- **100% open source** — MIT-licensed core; no proprietary runtime required
- **Free tools first** — local scripts, grep, LanceDB, and gates before paid APIs
- **Simple experience** — one workspace folder, optional phase loop, IDE adapters
- **Transparent development** — public roadmap, issues, and discussions
- **Architectural quality** — consistency, simplicity, and measurable harness behavior

## Governance

Octo Cluster follows a **SQLite-inspired** model: the code and roadmap are open; technical direction stays with the maintainers so the kernel stays small, fast, and coherent.

| Open to everyone | Centralized with maintainers |
|------------------|------------------------------|
| Read the code and docs | Architecture and release gates |
| Open bugs and discuss ideas | Final design decisions |
| Follow the public roadmap | PR review without obligation to merge |
| Suggest improvements via [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues) | Preserve velocity and consistency |

**Open source ≠ open governance.** We welcome feedback, bug reports, and public discussion. Pull requests are reviewed, but there is no expectation that every external contribution will be accepted — especially when it would add complexity or slow evolution.

Details: [Engineering Operating System (EOS)](./docs/governance/eos.md) · [public vs private trackers](./docs/adr/ADR-004-use-github-issues-as-public-work-tracker.md)

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
| **Core loop** | Optional phase commands (`/scan` → `/model` → `/ship` → `/close`, plus `/review`, `/debug`, `/prompt`) — useful, not required |
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

**Official dev setup:** native bootstrap on **Windows, macOS, or Linux** with PowerShell 7 and Bun. **iOS is out of scope** — desktop CLI harness only.

**Prerequisites:** [Git](https://git-scm.com/downloads), [PowerShell 7](https://github.com/PowerShell/PowerShell/releases), [Bun](https://bun.sh), and optionally [GitHub CLI](https://cli.github.com/) for `/ship`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git <clone-root>
cd <clone-root>
```

**Windows:** `pwsh -File install.ps1`  
**Linux/macOS:** `./install.sh`

Then sync the Cursor adapter and validate:

```powershell
pwsh scripts/sync-cursor.ps1
cd engine/context-engine && bun run validate octo-cluster
pwsh scripts/productivity-audit.ps1
```

Smoke test:

```powershell
pwsh octo.ps1 -Pipeline scan -Action discover
```

Full guide: [onboarding](./docs/guides/onboarding.md).

**Dev Container:** optional future path — not shipped in this repo yet.

Env vars: set `OCTO_CLUSTER` to the repo root (install scripts do this). Use `AI_EXECUTION_CONTEXT=platform` unless overridden in a local multi-root workspace.

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
  .cursor/             synced from domains/core/ — edit domains/, then sync
```

Agent context hub: [`contexts/README.md`](./contexts/README.md). Docs index: [`docs/index.md`](./docs/index.md).

See [context model](./docs/architecture/context-model.md) and [add a capability pack](./docs/guides/add-child-context.md).

## Optional loop (Cursor commands)

One chat ≈ one work item. Phase commands are **optional**; routine edits do not need them.

```text
/scan ISSUE-123 description  →  /model  →  Execute plan  →  /ship  →  /close
```

Meta and support commands: `/review` (PR review), `/debug` (systematic troubleshooting), `/prompt` (rewrites a prompt without executing it), `/linkedin` (bilingual draft from an active card).

Discover the active pipeline skill:

```powershell
pwsh octo.ps1 -Pipeline scan -Action discover
```

### Delivery (`/ship`)

`/ship` runs **verify → gate → deliver**, driven by repository policy (`repo-policies/`) — no project vocabulary hardcoded in core. Delivery is script-only (LLM budget = 1, the verdict):

- Feature branch → commit → push → PR against `base_branch`, then **auto-merge** enabled on the PR
- Returns immediately after enabling auto-merge; add `-WaitForMerge` to block until merge, `-FullVerify` to run every policy check instead of the fast tier
- Remote branch auto-deleted on merge; local branches pruned only after GitHub confirms their PR merged (never resets or cleans the worktree)
- Portable across machines: paths resolve from `OCTO_CLUSTER`; `gh auth login` (scopes `repo`, `workflow`) is the only per-machine prerequisite
- Ship any repo via `-RepoPath <path>`; policy is picked from `.octo/repo-policy` in the target repo

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

## Install helpers

| Script | Purpose |
|--------|---------|
| [`install.sh`](./install.sh) | Linux/macOS native bootstrap (delegates to `pwsh`) |
| [`install.ps1`](./install.ps1) | Windows host bootstrap |
| [`scripts/octo`](./scripts/octo) | Bash shim → `octo.ps1` on Unix |
| `scripts/sync-cursor.ps1` | Sync `domains/core/` → `.cursor/` |
| `scripts/productivity-audit.ps1` | Local harness health check |
| `scripts/install-go.ps1` | Go via [go.dev](https://go.dev/dl/) MSI or zip |
| `scripts/install-ollama.ps1` | Ollama via official install script |

## Contributing

We encourage **bugs, feedback, and public discussion** — open a [GitHub issue](https://github.com/renanflustosa/octo-cluster/issues/new/choose) or join a thread on an existing one. For large changes, read [CONTRIBUTING.md](./CONTRIBUTING.md) and the [Engineering Operating System (EOS)](./docs/governance/eos.md) first.

Architectural direction and merge decisions stay with the maintainers. Capability packs that name private products belong in **your fork** or a separate repo; promote shared behavior into `domains/core/`.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for setup, branch naming, PR flow, and the public framework boundary.

## License

[MIT](./LICENSE) © Renan Lustosa — see [THIRD_PARTY.md](./THIRD_PARTY.md) for adapted skills and dependencies.
