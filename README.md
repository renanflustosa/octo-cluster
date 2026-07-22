# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Minimal AI-assisted development harness for **Windows 11 + Cursor**.

A small set of Cursor rules, skills, and commands in `.cursor/`, plus two PowerShell scripts. No pipeline, no build step, no environment variables required — edit `.cursor/` directly; it is the source of truth.

## What you get

| Layer | Contents |
| --- | --- |
| **Commands** | `/ship`, `/review`, `/debug`, `/prompt` |
| **Rules** | consumer boundary, ponytail-lite, caveman-mode |
| **Skills** | code-review, systematic-debugging, ponytail-lite, caveman |
| **Scripts** | `ship.ps1` (deliver), `boundary-audit.ps1` (public-repo gate) |

## Quick start

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell](https://github.com/PowerShell/PowerShell/releases), and [GitHub CLI](https://cli.github.com/) (`gh`) for `/review`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
pwsh -File install.ps1
```

`install.ps1` installs git hooks (pre-commit / pre-push) that run the boundary audit. Open the folder in Cursor — commands load automatically.

## Multi-root workspace

Add this repo as a folder root alongside your product repos in a Cursor workspace. No `OCTO_CLUSTER` or sync step — each repo keeps its own git root; `/ship` runs `scripts/ship.ps1` from whichever repo you are delivering.

## Commands

- **`/ship`** — boundary gate, commit, push to `main` (solo direct-push workflow).
- **`/review`** — review a GitHub Pull Request (`gh pr view` / `gh pr diff`).
- **`/debug`** — fix a bug with runtime evidence first.
- **`/prompt`** — rewrite a request into a precise prompt (never executes it).

## Delivery (`/ship`)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -CommitMessage "fix: short summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -WhatIf
```

Direct push to `origin/main` — no feature branch, no PR, no rebase. The script stages all changes, runs `boundary-audit` on staged files, commits, and pushes.

## Layout

```text
.cursor/    rules, skills, commands (source of truth — edit here)
scripts/    ship.ps1, boundary-audit.ps1
.githooks/  pre-commit + pre-push boundary gates
install.ps1
AGENTS.md   agent contract (read first if you use AI assistance)
```

## Public-repo boundary

This is a public framework. Consumer-specific names (client, product, vault, workspace identifiers) must never appear in tracked files. The boundary audit and git hooks enforce this — see [`AGENTS.md`](./AGENTS.md) and [SECURITY.md](./SECURITY.md).

## License

[MIT](./LICENSE) © Renan Lustosa
