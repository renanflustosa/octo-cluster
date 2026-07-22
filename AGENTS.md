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

Run the boundary gate (also enforced by git hooks):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/boundary-audit.ps1 -Staged   # before commit
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/boundary-audit.ps1           # before push
```

Deliver with `scripts/ship.ps1` (commit + push to `main`). Do not run git by hand during `/ship`.
