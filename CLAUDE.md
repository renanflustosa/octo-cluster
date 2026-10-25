# Claude Code entry - octo-cluster

Same harness as Cursor. Always-on rules are the Cursor rule files, imported below (single source of truth).
Contract and commands: [AGENTS.md](./AGENTS.md) (read on demand, not imported).

@.cursor/rules/00-consumer-boundary.mdc
@.cursor/rules/execute-operator-intent.mdc
@.cursor/rules/ponytail-lite.mdc
@.cursor/rules/caveman-mode.mdc
@.cursor/rules/cost-routing.mdc

## Claude Code notes

- Skills live in `.claude/skills/` (Cursor loads the same folder). Slash: `/prompt`, `/ship`, `/debug`; auto: `ponytail-lite`, `systematic-debugging`, `pr-review`.
- Local diffs: prefer the built-in `/code-review`; GitHub PRs: `pr-review`.
- Use from any other folder: install the plugin (`claude plugin install octo-cluster --marketplace renanflustosa/octo-cluster`). Manifests: `.claude-plugin/`; always-on context: `hooks/hooks.json` (SessionStart injects `ponytail-lite` + `cost-routing`). Check with `claude plugin validate .`.
