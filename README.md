# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Minimal AI-assisted development harness for **Windows 11 + Cursor**.

A small set of Cursor rules, skills, and commands in `.cursor/`, plus two PowerShell scripts. No pipeline, no build step, no environment variables required — edit `.cursor/` directly; it is the source of truth.

## What you get

| Layer | Contents |
| --- | --- |
| **Rules** (always on) | consumer-boundary, execute-operator-intent, ponytail-lite, caveman-mode |
| **Commands** (on demand) | `/ship`, `/review`, `/debug`, `/prompt` |
| **Skills** (on demand) | ponytail-lite, systematic-debugging, code-review |
| **Scripts** | `ship.ps1` (deliver), `boundary-audit.ps1` (public-repo gate) |

## Quick start

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell](https://github.com/PowerShell/PowerShell/releases). [GitHub CLI](https://cli.github.com/) (`gh`) is optional — required only when `/ship` detects protections and opens a PR, or for `/review`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
pwsh -File install.ps1
```

`install.ps1` installs git hooks (pre-commit / pre-push) that run the boundary audit. Open the folder in Cursor — commands load automatically.

**Optional:** copy `boundary-patterns.example.yaml` to `boundary-patterns.local.yaml` and add patterns for names that must never appear in tracked public files. Generic adopters can leave the local file empty or omit it.

## Multi-root workspace

Add this repo as a folder root alongside your product repos in a Cursor workspace. No sync step — each repo keeps its own git root; `/ship` runs `scripts/ship.ps1` from whichever repo you are delivering.

## Commands

- **`/ship`** — boundary gate, commit, push to `main` or temp branch + PR when protections are detected.
- **`/review`** — review a GitHub Pull Request (`gh pr view` / `gh pr diff`).
- **`/debug`** — fix a bug with runtime evidence first.
- **`/prompt`** — rewrite a request into a precise prompt (never executes it).

## Delivery (`/ship`)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -CommitMessage "fix: short summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -WhatIf
```

**Auto-detected mode:**

| Protections | Action |
| --- | --- |
| None | Commit + push direct to `main` |
| Any detected | Temp branch `ship/<timestamp>` + PR to `main` |

Protection signals: `scripts/boundary-audit.ps1`, git hooks referencing audit/gate, remote branch protection (via `gh`), or `.ship.yaml` / `.ship.json` with `mode: pr` or `protections: true`. Override with `mode: direct` in config.

## Token economics

| Layer | When loaded | Token impact |
| --- | --- | --- |
| Always-on rules (~5 KB) | Every agent turn | Fixed baseline — keep thin |
| caveman-mode rule | Every turn | **Saves** reply tokens |
| execute-operator-intent rule | Every turn | **Costs** ~1 KB; reduces thrash from over-refusal |
| Skills (ponytail, debugging, review) | On demand via command or relevance | **Costs** only when invoked |
| `/prompt` | On demand | Upfront cost; **saves** thrash on complex tasks |
| `/ship`, `/debug`, `/review` | On demand | No always-on cost |

**Design:** short always-on rules + heavy playbooks in skills/commands. Target always-on budget: **≤ 8 KB**.

## Layout

```text
.cursor/    rules, skills, commands (source of truth — edit here)
scripts/    ship.ps1, boundary-audit.ps1
.githooks/  pre-commit + pre-push boundary gates
examples/   optional hooks (not enabled by default)
install.ps1
AGENTS.md   agent contract (read first if you use AI assistance)
INSPIRATIONS.md  curated upstream links (no vendored copies)
```

## Public-repo boundary

This is a public framework. Consumer-specific names (client, product, vault, workspace identifiers) must never appear in tracked files. Configure patterns in `boundary-patterns.local.yaml` (gitignored). The boundary audit and git hooks enforce this — see [`AGENTS.md`](./AGENTS.md) and [SECURITY.md](./SECURITY.md).

## Optional extras

See [examples/hooks/](examples/hooks/) for an optional `beforeShellExecution` hook (secret-scan example). Not enabled by default — copy to `.cursor/hooks.json` if you want it.

## Inspirations

Curated free upstream sources: [INSPIRATIONS.md](./INSPIRATIONS.md).

## License

[MIT](./LICENSE) © Renan Lustosa
