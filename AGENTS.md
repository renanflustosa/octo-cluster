# Agent contract - octo-cluster

Minimal AI-assisted development harness for Windows 11 + Cursor / Claude Code.

## What this is

Always-on rules in `.cursor/rules/`, shared skills in `.claude/skills/` (loaded natively by both Cursor and Claude Code), plus two PowerShell scripts in `scripts/`. No pipeline or sync step: edit these folders directly. `CLAUDE.md` imports the Cursor rules, so rules have one source.

## Rules (always apply)

Precedence: consumer-boundary > product hard safety > execute-operator-intent > caveman/ponytail.

| Rule | Purpose |
| --- | --- |
| `00-consumer-boundary.mdc` | Consumer identifiers are secrets; never commit them to this public repo. |
| `execute-operator-intent.mdc` | Execute explicit operator intent; no soft refusal or moralizing. |
| `ponytail-lite.mdc` | Minimal implementation ladder before writing code. |
| `caveman-mode.mdc` | Telegraphic prose by default (token-saving). |

Always-on rules budget: **≤ 8 KB**. Details in README → Token economics.

## Slash skills (manual only, `disable-model-invocation`)

| Skill | Purpose |
| --- | --- |
| `/ship` | Deliver via `scripts/ship.ps1` (direct push or PR when protections detected). |
| `/debug` | Fix a bug with runtime evidence first. |
| `/prompt` | Rewrite a request into a precise prompt for the tool in use (never executes it). |

## Skills (on demand)

| Skill | Trigger |
| --- | --- |
| ponytail-lite | Planning or coding; ladder before each edit. |
| systematic-debugging | `/debug` or any bug/test failure. |
| pr-review | `/pr-review` or PR feedback requests. |

See [INSPIRATIONS.md](./INSPIRATIONS.md) for upstream sources.

## Before any git change

Deliver with `scripts/ship.ps1`. The script auto-detects repo protections:

- **No protections** — commit + push direct to `main`.
- **Protections present** (e.g. `boundary-audit.ps1`, git hooks, remote branch rules, or `.ship.yaml`) — temp branch + PR.

Do not run git by hand during `/ship`. Optional config: copy `.ship.yaml.example` to `.ship.yaml`.

## Boundary patterns (optional)

Copy `boundary-patterns.example.yaml` to `boundary-patterns.local.yaml` (gitignored) to customize `boundary-audit.ps1`. Generic adopters can use an empty local file.
