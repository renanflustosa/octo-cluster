---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

> Adapted from [obra/superpowers](https://github.com/obra/superpowers) (MIT). Deep dives: `references/` in this directory.

## Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Complete Phase 1 before proposing fixes. Use for test failures, production bugs, build failures, perf issues — especially under time pressure or after a failed fix.

## Phase 1: Root Cause Investigation

1. **Read errors** — stack traces, line numbers, codes; do not skip warnings.
2. **Reproduce** — exact steps; if flaky, gather data instead of guessing.
3. **Recent changes** — git diff, deps, config, environment.
4. **Multi-component systems** — log at each boundary (in/out, config propagation); run once to see *where* it breaks.
5. **Trace data flow** — bad value upstream? See [root-cause-tracing.md](references/root-cause-tracing.md).

## Phase 2: Pattern Analysis

Find working examples in the codebase. Compare broken vs working line by line. Read reference implementations fully before adapting.

## Phase 3: Hypothesis and Testing

One hypothesis: "X is the cause because Y." Smallest test change; one variable. Failed? New hypothesis — do not stack fixes.

## Phase 4: Implementation

1. Failing repro (test or script) before the fix.
2. Single fix at root cause — no bundled refactors.
3. Verify fix and no regressions.
4. **≥ 3 failed fix attempts** → stop; question architecture with operator before fix #4.

After root cause found, optional hardening: [defense-in-depth.md](references/defense-in-depth.md), [condition-based-waiting.md](references/condition-based-waiting.md).

## Red flags — STOP, return to Phase 1

- "Quick fix now, investigate later"
- "Just try X and see"
- Multiple changes before one verified hypothesis
- Proposing fixes before tracing data flow
- "One more attempt" after 2+ failures

| Excuse | Reality |
|--------|---------|
| "Too simple for process" | Simple bugs still have root causes |
| "No time" | Systematic beats thrashing |
| "I'll test after" | Repro first or fixes do not stick |

## Output (`/debug`)

Root cause (1 line) + fix + proof command, ≤30 lines.

## Quick reference

| Phase | Success |
|-------|---------|
| 1 Root cause | Know WHAT and WHY |
| 2 Pattern | Differences identified |
| 3 Hypothesis | Confirmed or replaced |
| 4 Implementation | Bug resolved, proof run |

If truly environmental/external after full investigation: document findings, add handling/monitoring — do not skip phases to get there.
