# debug

**Debug mode** or **Agent** with runtime evidence. Model: `gpt-5.6-terra-medium`; thinking only after 2 failed hypotheses.

**Evidence script-first:** gather runtime evidence via `bun test`, logs, and grep **before** each hypothesis — no LLM speculation without a reproducible signal.

**Discover (first debug only):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline debug -Action discover
```

Read `PIPELINE_SKILL` once (typically `systematic-debugging`).

**When:** flaky test, hung process, permission errors, API 500, missing dependency mid-run.

**Do:** reproduce → minimal fix → scoped re-run (same test filters as before). Trim noisy logs before pasting. No refactors.

**Output:** root cause (1 line) + fix + proof command — **≤30 lines**.

**When NOT:** design questions, refactors, or fixes without a reproducible failure.
