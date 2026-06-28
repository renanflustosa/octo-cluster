---
name: minimal-review
description: Review diffs for over-engineering only — delete-list, not fixes. Use on /minimal-review, before /ship on large diffs, or when user asks what to cut. Complements code-review (correctness/security).
---

# Minimal review — over-engineering only

Review diffs for unnecessary complexity. One line per finding: location, what to cut, what replaces it. The diff's best outcome is getting shorter.

**Out of scope:** correctness bugs, security holes, performance — route to `code-review` skill, not this pass.

Does not apply fixes — only lists them.

## Format

`path:Lstart-Lend: tag: finding`

Tags:

- `delete:` — dead code, unused flexibility, speculative feature. Replacement: nothing.
- `stdlib:` — hand-rolled thing the standard library ships. Name the function.
- `native:` — dependency or code doing what the platform already does. Name the feature.
- `yagni:` — abstraction with one implementation, config nobody sets, layer with one caller.
- `shrink:` — same logic, fewer lines. Show the shorter form.

## Examples

Bad: "This EmailValidator class might be more complex than necessary, have you considered whether all these validation rules are needed?"

Good:

- `validators.py:L12-38: stdlib: 27-line validator class. "@" in email, 1 line; real validation is the confirmation mail.`
- `ui.tsx:L4: native: moment.js imported for one format call. Intl.DateTimeFormat, 0 deps.`
- `repo.py:L88: yagni: AbstractRepository with one implementation. Inline until a second exists.`
- `handler.go:L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.`
- `utils.py:L30-44: shrink: manual loop builds dict. dict(zip(keys, values)), 1 line.`

## Scoring

End with the only metric that matters: `net: -N lines possible.`

If there is nothing to cut, say `Lean already. Ship.` and stop.

## Boundaries

- A single smoke test or assert-based self-check is the ponytail-lite minimum, not bloat — never flag it for deletion.
- "stop minimal-review" or "normal mode": revert to verbose review style.
- Optional before `/ship` when diff exceeds ~100 added lines; does not block ship gates.

Trigger: `/minimal-review` command or user phrases ("review over-engineering", "what can we delete", "is this over-engineered").
