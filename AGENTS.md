# Agent contract - octo-cluster

Minimal AI-assisted development harness for Windows 11 + Cursor.

## What this is

A small set of Cursor rules, skills, and commands in `.cursor/`, plus two PowerShell scripts in `scripts/`. There is no pipeline or sync step: `.cursor/` is edited directly and is the source of truth.

## Rules (always apply)

- `.cursor/rules/00-consumer-boundary.mdc` - consumer identifiers are secrets; never commit them to this public repo.
- `.cursor/rules/ponytail-lite.mdc` - minimal implementation ladder before writing code.
- `.cursor/rules/caveman-mode.mdc` - telegraphic prose by default.

## Commands

`/ship`, `/review`, `/debug`, `/prompt` - see `.cursor/commands/`.

## Before any git change

Deliver with `scripts/ship.ps1`. The script auto-detects repo protections:

- **No protections** — commit + push direct to `main`.
- **Protections present** (e.g. `boundary-audit.ps1`, git hooks, remote branch rules, or `.ship.yaml`) — temp branch + PR.

Do not run git by hand during `/ship`. Optional config: copy `.ship.yaml.example` to `.ship.yaml`.
