# Claude Code entry - octo-cluster

Same harness as Cursor. Always-on rules are the Cursor rule files, imported below (single source of truth).
Contract and commands: [AGENTS.md](./AGENTS.md) (read on demand, not imported).

@.cursor/rules/00-consumer-boundary.mdc
@.cursor/rules/execute-operator-intent.mdc
@.cursor/rules/ponytail-lite.mdc
@.cursor/rules/caveman-mode.mdc

## Claude Code notes

- Skills live in `.claude/skills/` (Cursor loads the same folder). Slash: `/prompt`, `/ship`, `/debug`; auto: `ponytail-lite`, `systematic-debugging`, `pr-review`.
- Local diffs: prefer the built-in `/code-review`; GitHub PRs: `pr-review`.
- Use from another folder (multi-repo hub): `pwsh -File install.ps1 -ClaudeSkillsTo <hub-folder>` and add `@<octo-cluster>/CLAUDE.md` to the hub `CLAUDE.md`.
