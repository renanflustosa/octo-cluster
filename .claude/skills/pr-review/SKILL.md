---
name: pr-review
description: Review a GitHub Pull Request for bugs, security, performance, and code quality. Use when user asks to review a PR or wants pull request feedback. Don't use for reviewing local uncommitted changes, creating new PRs, or merging branches.
argument-hint: "[PR number] [BUGS|SECURITY|PERFORMANCE]"
---

# Review Pull Request

Ask mode. Arguments: $ARGUMENTS

If a focus mode is given, adjust the review:
- BUGS: Focus only on logical or other bugs
- SECURITY: Focus only on security issues
- PERFORMANCE: Focus only on performance issues

## Workflow

1. Run `gh pr view [PR]` and `gh pr diff [PR]` before reading files — the diff is the source of truth
2. Read surrounding files only when a finding needs context
3. Review based on mode (or all categories if no mode set)
4. Provide structured feedback

## Output format

Group by severity:
- **Critical** - must fix before merge (bugs, security vulnerabilities)
- **Suggestions** - improvements worth considering
- **Positives** - good patterns to call out

Use `file:line` references for all findings. Include suggested fix for each critical issue.

See [examples.md](references/examples.md) for output format and [review-checklist.md](references/review-checklist.md) for full checklist.

## Rules

- Review ALL changed files, not just the latest commit
- Be specific: file:line + issue + suggested fix
- Separate critical issues from suggestions

## Error Handling

- If `gh pr view` fails → run `gh auth status` to verify authentication; ask user for PR number if not on a PR branch
- If a changed file is deleted in the PR → skip reading it; note it was removed
- If diff is too large → prioritize changed files with highest risk (auth, payments, data mutation)
