# Inspirations

Curated free upstream sources for octo-cluster. **Link and adapt — do not vendor wholesale copies into this repo.**

| Source | License | What we took |
| --- | --- | --- |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | MIT | YAGNI → reuse → stdlib → minimum code ladder ([ponytail-lite skill](.cursor/skills/ponytail-lite/SKILL.md)) |
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | Evidence-first debugging ([systematic-debugging skill](.cursor/skills/systematic-debugging/SKILL.md)) |
| [Cursor Rules docs](https://cursor.com/docs/rules) | — | Always-on rules vs on-demand skills/commands |
| [Cursor Agent best practices](https://cursor.com/blog/agent-best-practices) | — | Thin rules, dynamic skills, hooks |
| [agentskills.io](https://agentskills.io) | — | Portable skill standard (`.cursor/skills/*/SKILL.md`) |

## When to link vs copy

| Situation | Action |
| --- | --- |
| One-line constraint ("use TypeScript") | Project rule in your product repo |
| Multi-step workflow (debug, review, ship) | Command + skill in octo-cluster or your repo |
| Domain-specific (PDF, deploy, legal) | Link from INSPIRATIONS; add a skill only if you use it weekly |
| 50 community skills | Do **not** bundle — pick ≤3 defaults |

## Native Cursor tools (use instead of reinventing)

- `/create-rule` — scaffold a new rule
- `/create-skill` — scaffold a new skill
- `/migrate-to-skills` — convert eligible rules/commands to skills (Cursor 2.4+)

## Optional patterns (not included by default)

- **Hooks** — secret scan before shell; see [examples/hooks/](examples/hooks/)
- **Subagents** — `.cursor/agents/` (Cursor nightly as of 2025; check your channel)
- **Boundary overlay** — `boundary-patterns.local.yaml` (gitignored) for names that must never ship in public repos

## Contributing inspirations

Open a PR with one row in the table above: link, license, and what pattern you adapted (not a pasted skill dump).
