---
name: ponytail-lite
description: Minimal implementation ladder before writing code. Apply before each edit; question over-scope during planning. Complements caveman (prose). Inspired by DietrichGebert/ponytail (MIT).
---

# Ponytail-lite — minimal implementation

> Adapted from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT).

Lazy means efficient, not careless. Complements **caveman** (shorter replies). This skill governs **what** to implement, not how to phrase status updates.

## The ladder

Before writing any code, stop at the first rung that holds:

1. **YAGNI** — Does this need to be built at all?
2. **Reuse** — Does it already exist in this codebase? Reuse the helper, util, or pattern — do not rewrite.
3. **Stdlib** — Does the standard library already do this?
4. **Native** — Does a native platform feature cover it? (`<input type="date">`, `Intl`, `path.Join`, etc.)
5. **Installed dep** — Does an already-installed dependency solve it?
6. **One line** — Can this be one line? Make it one line.
7. **Minimum** — Only then: write the minimum code that works.

**Order:** read and trace the real flow first, then climb. Lazy about the solution, never about reading.

## Examples by rung

| Rung | Bad | Good |
|------|-----|------|
| YAGNI | Build a generic plugin system for one hook | Inline the one hook |
| Reuse | New `parseDate()` when `utils/date.ts` exists | Import existing helper |
| Stdlib | Hand-rolled email regex class | `"@" in email` or stdlib validator |
| Native | flatpickr for a date field | `<input type="date">` |
| Installed dep | Add lodash for one `groupBy` | Use existing dep or stdlib |
| One line | 15-line wrapper around `dict(zip(...))` | `dict(zip(keys, values))` |
| Minimum | Framework for a one-off script | Direct script |

## Bug fix = root cause

A report names a symptom. Grep every caller of the function you touch and fix the shared function once — one guard there beats one patch per caller.

## Carve-outs (never cut)

- Understanding the problem (read fully, trace flow before picking a rung)
- Input validation at trust boundaries
- Error handling that prevents data loss
- Security, accessibility
- Hardware calibration (clocks drift, sensors read off)
- Anything explicitly requested by the user or ticket

Non-trivial logic leaves **ONE** runnable check (assert-based self-check or one small test file; no frameworks, no fixtures). Trivial one-liners need no test.

## Debt comments

Mark intentional simplifications:

```python
# ponytail: global lock; upgrade to per-key sharding if contention shows up
```

Names the ceiling and the upgrade path so "later" does not become "never".

## Phase integration

| Phase | Behavior |
|-------|----------|
| Plan | Rejected alternatives cite rung; plan must not violate carve-outs |
| Execute | Ladder active before each file edit |
| `/ship` | Prefer smallest diff that passes the boundary gate |

## Does NOT replace

- **caveman** — prose compression on status turns
- **systematic-debugging** — reproduce before fix; ponytail-lite applies after root cause is understood

Trigger: active when `.cursor/rules/ponytail-lite.mdc` applies.
