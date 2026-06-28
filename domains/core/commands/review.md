# review

**Ask mode** — review a GitHub Pull Request. Model: session default (Auto).

**Discover (first review only):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline review -Action discover
```

Read `PIPELINE_SKILL` once (typically `code-review`).

**When:** user asks to review a PR, wants PR feedback, or mentions bugs/security/performance in an open PR.

**Do:** use `gh pr view` and `gh pr diff`; group findings by severity with `file:line` references.

**When NOT:** local uncommitted changes, creating PRs, or merging branches.

**Optional mode arg:** `BUGS` · `SECURITY` · `PERFORMANCE` — focus one category only.
