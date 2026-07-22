# review

Ask mode. Review a GitHub Pull Request.

Run `gh pr view` and `gh pr diff` before reading files - the diff is the source of truth. Read surrounding files only when a finding needs context.

**When:** user asks to review a PR or wants PR feedback.
**When NOT:** local uncommitted changes, creating PRs, or merging branches.

Group findings by severity with `file:line` references. Skill: code-review.

Optional focus arg: `BUGS` | `SECURITY` | `PERFORMANCE`.
