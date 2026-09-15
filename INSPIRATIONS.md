# Inspirations

Curated free upstream sources for octo-cluster. **Link and adapt — do not vendor wholesale copies into this repo.**

| Source | License | What we took |
| --- | --- | --- |
| [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | MIT | YAGNI → reuse → stdlib → minimum code ladder ([ponytail-lite skill](.claude/skills/ponytail-lite/SKILL.md)) |
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | Evidence-first debugging ([systematic-debugging skill](.claude/skills/systematic-debugging/SKILL.md)) |
| [Cursor Rules docs](https://cursor.com/docs/rules) | — | Always-on rules vs on-demand skills/commands |
| [Cursor Agent best practices](https://cursor.com/blog/agent-best-practices) | — | Thin rules, dynamic skills, hooks |
| [Claude Code skills docs](https://code.claude.com/docs/en/skills) | — | `disable-model-invocation`, `CLAUDE.md` imports |
| [agentskills.io](https://agentskills.io) | — | Portable skill standard (`.claude/skills/*/SKILL.md`, read by Cursor and Claude Code) |

## When to link vs copy

| Situation | Action |
| --- | --- |
| One-line constraint ("use TypeScript") | Project rule in your product repo |
| Multi-step workflow (debug, review, ship) | Skill in octo-cluster or your repo |
| Domain-specific (PDF, deploy, legal) | Link from INSPIRATIONS; add a skill only if you use it weekly |
| 50 community skills | Do **not** bundle — pick ≤3 defaults |

## Native tools (use instead of reinventing)

- Cursor: `/create-rule`, `/create-skill`, `/migrate-to-skills` (Cursor 2.4+)
- Claude Code: `/code-review` (local diffs), `/security-review`, `/init`

## Optional patterns (not included by default)

- **Hooks** — secret scan before shell; see [examples/hooks/](examples/hooks/)
- **Subagents** — `.cursor/agents/` (Cursor nightly as of 2025; check your channel)
- **Boundary overlay** — `boundary-patterns.local.yaml` (gitignored) for names that must never ship in public repos

## Contributing inspirations

Open a PR with one row in the table above: link, license, and what pattern you adapted (not a pasted skill dump).
