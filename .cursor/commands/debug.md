# debug

**Debug mode** or **Agent** with runtime evidence. Model: session default (Auto).

**Discover (first debug only):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline debug -Action discover
```

Read `PIPELINE_SKILL` once (typically `systematic-debugging`).

**When:** flaky test, hung process, permission errors, API 500, missing dependency mid-run.

**Do:** reproduce → minimal fix → scoped re-run (same test filters as before). Trim noisy logs before pasting. No refactors.

**Output:** root cause (1 line) + fix + proof command — **≤30 lines**.

**When NOT:** design questions, refactors, or fixes without a reproducible failure.
