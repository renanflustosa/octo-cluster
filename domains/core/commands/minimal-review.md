# minimal-review

**Agent mode** — over-engineering review on the current diff only. Does not apply fixes.

**Read once:** `domains/core/skills/minimal-review/SKILL.md`

**Input:** current branch diff vs base (or files changed in this card).

**Output:** tagged delete-list + `net: -N lines possible` or `Lean already. Ship.`

**Not in scope:** bugs, security, performance — use `/review` (GitHub PR) or `code-review` skill.

Optional before `/ship` on large diffs; never blocks verify gates.
