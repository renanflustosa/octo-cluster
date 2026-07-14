# review

**Ask mode** — review a GitHub Pull Request. Model: `composer-2.5-fast`.

**LLM turn budget: 1 (the findings).** Run `gh pr view` and `gh pr diff` before any Read — the diff is the source of truth; broad file reads only when a finding needs surrounding context.

**Discover (first review only):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline review -Action discover
```

Read `PIPELINE_SKILL` once (typically `code-review`).

**When:** user asks to review a PR, wants PR feedback, or mentions bugs/security/performance in an open PR.

**Do:** use `gh pr view` and `gh pr diff`; group findings by severity with `file:line` references.

**When NOT:** local uncommitted changes, creating PRs, or merging branches.

**Optional mode arg:** `BUGS` · `SECURITY` · `PERFORMANCE` — focus one category only.
