# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Minimal AI-assisted development harness for **Windows 11 + Cursor**. A small set of Cursor rules, skills, and commands, plus two PowerShell scripts. No pipeline, no build step - `.cursor/` is the source of truth.

## Quick start

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell](https://github.com/PowerShell/PowerShell/releases), and [GitHub CLI](https://cli.github.com/) (`gh`) for `/review`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
pwsh -File install.ps1
```

`install.ps1` installs the git hooks (pre-commit / pre-push boundary gates). Open the folder in Cursor and the commands are available.

## Commands

- `/ship` - commit and push straight to `main` (boundary gate runs first).
- `/review` - review a GitHub Pull Request.
- `/debug` - fix a bug with runtime evidence.
- `/prompt` - rewrite a request into a precise prompt (never executes it).

## Delivery (`/ship`)

Direct push, solo workflow - no feature branch, no PR, no rebase:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -CommitMessage "fix: short summary"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/ship.ps1 -WhatIf
```

The script runs `boundary-audit`, commits, and pushes to `origin/main`.

## Layout

```text
.cursor/    rules, skills, commands (edited directly - the source of truth)
scripts/    ship.ps1, boundary-audit.ps1
.githooks/  pre-commit + pre-push boundary gates
install.ps1
```

## License

[MIT](./LICENSE) (c) Renan Lustosa
