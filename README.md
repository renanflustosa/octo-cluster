# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A lean Claude Code plugin for developers who use Claude Code every day and want three things it does not do on its own: **ship work as clean commits without ever force-pushing**, **turn a rough request into a prompt a fresh session can run without questions**, and **keep the always-on context (and the weekly limit) small**.

## Who it is for

- **Solo devs on Pro/Max** who hit the weekly limit mid-week and want fewer wasted turns.
- **Freelancers and OSS maintainers** who keep client work next to public repos and must not leak client names or secrets into a public commit.
- **Tech leads** who want one commit/PR convention for the whole team.

Works on Windows, macOS and Linux. The delivery and audit scripts are PowerShell ([`pwsh`](https://github.com/PowerShell/PowerShell/releases), also on macOS/Linux).

## Install

```bash
claude plugin install octo-cluster --marketplace renanflustosa/octo-cluster
```

Inside a session: `/plugin install octo-cluster --marketplace renanflustosa/octo-cluster`. One-step install needs Claude Code 2.1.292+ (CLI) or 2.1.275+ (in session); on older versions run `claude plugin marketplace add renanflustosa/octo-cluster` and then `claude plugin install octo-cluster@octo-cluster`.

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell 7](https://github.com/PowerShell/PowerShell/releases) for `/ship`, and optionally the [GitHub CLI](https://cli.github.com/) (`gh`) so `/ship` can read branch protection and open PRs.

Check what it costs you: `claude plugin details octo-cluster` (≈ 180 tokens of skill listings plus ≈ 300 tokens of session-start rules; skill bodies cost tokens only when invoked).

## Before and after

**Delivering work**

| Before | After: `/octo-cluster:ship` |
| --- | --- |
| `git add . && git commit -m "wip" && git push` — one mixed commit, maybe straight into a protected `main`, maybe with a stray `.env` | Reads the diff, splits it into logical Conventional Commits, runs your checks, then pushes to `main` if it is open or opens a `feature/`/`fix/`/`chore/` branch + PR if `main` is protected. Never stashes, rebases or force-pushes. |

**Asking for work**

Before:

```text
/octo-cluster:prompt fix the login bug from yesterday
```

After (excerpt of what it returns, ready to paste into a new session):

```text
Fix the login failure where POST /api/auth/login returns 500 when the email has uppercase letters.
Context: src/auth/login.ts normalizes email only on signup; test command: npm test -- auth.
Done when: a regression test reproduces the 500, the fix makes it pass, and the full auth suite is green.
```

Try both in under five minutes: run `/octo-cluster:prompt <any rough request>`, then `/octo-cluster:ship` in a repo with uncommitted changes (`scripts/ship.ps1 -WhatIf` shows the delivery decision without pushing).

## What you get

| Piece | What it does |
| --- | --- |
| `/octo-cluster:ship` | Logical commits + safe delivery (direct push or branch + PR, decided by real branch protection or `.ship.yaml`). |
| `/octo-cluster:prompt` | Rewrites a request into a self-contained prompt with scope, constraints and a verifiable "done". Never executes it. |
| `/octo-cluster:debug` | Fix a bug with runtime evidence first: reproduce, minimal fix, proof. |
| `systematic-debugging`, `ponytail-lite` | On-demand playbooks: evidence-first debugging; YAGNI → reuse → stdlib → minimum code. |
| Session-start context | Two short rules (~1.1 KB): minimal-implementation ladder and cost routing (model tier per task, no mid-task model switch, retry cap). |
| `scripts/boundary-audit.ps1` + git hooks | Blocks consumer identifiers (client, product, internal names) from reaching a public repo. |

For local diffs and GitHub PRs use the built-in `/code-review`. For terse replies, pick the built-in **Concise** output style in `/config`.

## Delivery (`/ship`)

The skill makes the logical commits; `scripts/ship.ps1` only inspects and delivers `origin/main..HEAD`. It never stages, stashes, rebases or force-pushes.

| Signal | Action |
| --- | --- |
| `.ship.yaml` / `.ship.json` `mode: direct` | Push direct to `main` |
| `.ship.yaml` / `.ship.json` `mode: pr` or `protections: true` | Branch + PR to `main` |
| GitHub: `main` not protected, or only `deletion` / `non_fast_forward` rules | Push direct to `main` |
| GitHub: branch protection or blocking rulesets (e.g. `pull_request`) | Branch + PR to `main` |
| Protection unreadable (no `gh`, no access) | Try direct push; a protection rejection falls back to PR |

`scripts/boundary-audit.ps1`, when the target repo has one, runs before every push.

## Public-repo boundary

Copy `boundary-patterns.example.yaml` to `boundary-patterns.local.yaml` (gitignored) and list the names that must never appear in tracked files. `install.ps1` wires the pre-commit and pre-push hooks for this repo; CI runs the same audit. See [AGENTS.md](./AGENTS.md) and [SECURITY.md](./SECURITY.md).

## Token economics

Always-on context is paid on every request; skills cost only when invoked. Levers, in order: smaller context per request, fewer requests, cheaper output model.

- Pick model and effort at session start. A model switch re-reads the whole conversation uncached; effort changes keep the cache.
- `/clear` between unrelated tasks; `/compact` at natural breaks; `/rewind` instead of arguing down a wrong path.
- Avoid `/loop`, agent teams and `[1m]` models in long sessions — each re-sends the full context.
- Measure before and after a change with `/usage` (per skill, plugin and subagent).

**Cost profile:** [`examples/settings/claude-cost-profile.example.json`](examples/settings/claude-cost-profile.example.json) — Sonnet by default at medium effort, auto-compact at 200k, subagents on Sonnet. Merge it into `~/.claude/settings.json`; escalate per task with `/model opus`.

## Cursor

Cursor reads the same skills from `.claude/skills/` and the always-on rules from `.cursor/rules/`. Add this repo as a folder root in your workspace and run `pwsh -File install.ps1` once for the git hooks.

## Upgrading from `install.ps1 -ClaudeSkillsTo`

The plugin replaces the skill junctions. Before installing it, delete the octo-cluster junctions in `<hub>/.claude/skills/` and the `@<octo-cluster>/CLAUDE.md` import from the hub `CLAUDE.md`, or each skill shows up twice. To roll back: `claude plugin uninstall octo-cluster` and re-run `install.ps1 -ClaudeSkillsTo <hub>`.

## Layout

```text
.claude-plugin/  plugin.json + marketplace.json (Claude Code plugin)
hooks/           SessionStart hook (injects the two thin rules)
.claude/skills/  skills (plugin, Cursor and this repo)
.cursor/rules/   always-on rules (Cursor; the hook reads two of them)
scripts/         ship.ps1, boundary-audit.ps1
.githooks/       pre-commit + pre-push boundary gates
examples/        optional hooks and settings (not enabled by default)
docs/roadmap.md  diagnosis and roadmap
```

## Optional extras

[examples/hooks/](examples/hooks/) has a secret-scan shell hook for Cursor (`beforeShellExecution`) and Claude Code (`PreToolUse`). Not enabled by default.

## Inspirations

Curated upstream sources: [INSPIRATIONS.md](./INSPIRATIONS.md).

## License

[MIT](./LICENSE) © Renan Lustosa
