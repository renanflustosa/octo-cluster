# debug

Debug mode. Fix bugs with runtime evidence, not speculation.

Gather a reproducible signal (test, logs, grep) before each hypothesis. Then: reproduce -> minimal fix -> scoped re-run. No refactors.

**When:** flaky test, hung process, permission error, API 500, missing dependency mid-run.
**When NOT:** design questions, refactors, or fixes without a reproducible failure.

**Output:** root cause (1 line) + fix + proof command, <=30 lines. Skill: systematic-debugging.
