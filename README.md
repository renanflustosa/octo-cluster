# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Minimal AI-assisted development harness for **Windows 11 + Cursor / Claude Code**.

A few always-on rules, a handful of shared skills, and two PowerShell scripts. No pipeline, no build step, no sync — both tools read the same files.

## What you get

| Layer | Contents |
| --- | --- |
| **Rules** (always on) | consumer-boundary, execute-operator-intent, ponytail-lite, caveman-mode |
| **Slash skills** (manual) | `/prompt`, `/ship`, `/debug` |
| **Skills** (on demand) | ponytail-lite, systematic-debugging, pr-review |
| **Scripts** | `ship.ps1` (deliver), `boundary-audit.ps1` (public-repo gate) |

## How each tool loads it

| | Cursor | Claude Code |
| --- | --- | --- |
| Rules | `.cursor/rules/*.mdc` | `CLAUDE.md` imports the same `.mdc` files |
| Skills | `.claude/skills/` (native compat) | `.claude/skills/` |
| Settings | — | `.claude/settings.json` (deny reads of `state/`, `.env*`, logs) |

## Quick start

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell](https://github.com/PowerShell/PowerShell/releases). [GitHub CLI](https://cli.github.com/) (`gh`) is optional — required only when `/ship` detects protections and opens a PR, or for `pr-review`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
pwsh -File install.ps1
```

`install.ps1` installs git hooks (pre-commit / pre-push) that run the boundary audit. Open the folder in Cursor or Claude Code — skills load automatically.

**Optional:** copy `boundary-patterns.example.yaml` to `boundary-patterns.local.yaml` and add patterns for names that must never appear in tracked public files. Generic adopters can leave the local file empty or omit it.

## Multi-repo setups

- **Cursor:** add this repo as a folder root alongside your product repos in a workspace.
- **Claude Code:** Claude loads skills from the start folder only. From a hub folder that contains your repos:

  ```powershell
  pwsh -File install.ps1 -ClaudeSkillsTo <hub-folder>   # junctions <hub>/.claude/skills/* -> this repo
  ```

  Then add `@<path-to-octo-cluster>/CLAUDE.md` to the hub `CLAUDE.md` for the rules. Edits here show up in the hub immediately.

Each repo keeps its own git root; `/ship` runs `scripts/ship.ps1` against whichever repo you are delivering.

## Slash skills

- **`/ship`** — boundary gate, commit, push to `main` or temp branch + PR when protections are detected.
- **`/debug`** — fix a bug with runtime evidence first.
- **`/prompt`** — rewrite a request into a precise prompt for the tool in use (never executes it).

The on-demand skills can also be called by name: `/pr-review` reviews a GitHub Pull Request (`gh pr view` / `gh pr diff`). In Claude Code, the built-in `/code-review` covers local diffs.

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
| Always-on rules (~4 KB) | Every agent turn | Fixed baseline — keep thin |
| caveman-mode rule | Every turn | **Saves** reply tokens |
| execute-operator-intent rule | Every turn | **Costs** ~1 KB; reduces thrash from over-refusal |
| Skills (ponytail, debugging, pr-review) | On demand; only the description is always listed | **Costs** only when invoked |
| `/prompt`, `/ship`, `/debug` | Manual only (`disable-model-invocation`) | **Zero** until invoked — not even the description |
| `.claude/settings.json` deny rules | Claude Code | **Saves** — agent can't read runtime state or logs |

**Design:** short always-on rules + heavy playbooks in skills. Target always-on budget: **≤ 8 KB**.

## Layout

```text
.cursor/rules/   always-on rules (Cursor; imported by CLAUDE.md)
.claude/skills/  shared skills + slash skills (Cursor and Claude Code)
.claude/settings.json  Claude Code read-deny rules
CLAUDE.md        Claude Code entry (imports rules)
scripts/         ship.ps1, boundary-audit.ps1
.githooks/       pre-commit + pre-push boundary gates
examples/        optional hooks (not enabled by default)
install.ps1
AGENTS.md        agent contract (read first if you use AI assistance)
INSPIRATIONS.md  curated upstream links (no vendored copies)
```

## Public-repo boundary

This is a public framework. Consumer-specific names (client, product, vault, workspace identifiers) must never appear in tracked files. Configure patterns in `boundary-patterns.local.yaml` (gitignored). The boundary audit and git hooks enforce this — see [`AGENTS.md`](./AGENTS.md) and [SECURITY.md](./SECURITY.md).

## Optional extras

See [examples/hooks/](examples/hooks/) for an optional secret-scan shell hook that works in Cursor (`beforeShellExecution`) and Claude Code (`PreToolUse`). Not enabled by default.

## Inspirations

Curated free upstream sources: [INSPIRATIONS.md](./INSPIRATIONS.md).

## License

[MIT](./LICENSE) © Renan Lustosa
