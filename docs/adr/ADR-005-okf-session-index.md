# ADR-005: OKF-style session index (claude-mega-brain patterns)

## Status

Deferred

## Context

[claude-mega-brain](https://github.com/guhcostan/claude-mega-brain) (MIT) injects a compact Open Knowledge Format (OKF) index at Claude Code `SessionStart`: any `.md` with YAML frontmatter `type:` is scanned and summarized (~16k tokens, 0 tool calls for known concepts). Linked concepts can surface on `PostToolUse`.

Octo Cluster today:

| Dimension | mega-brain | Octo Cluster |
|-----------|------------|--------------|
| Runtime | Claude Code plugin | Cursor + PowerShell harness |
| Injection | `SessionStart` hook | LanceDB / FTS on demand + memory files |
| Format | OKF `type:` in any `.md` | `state/memory/<profile>/` + fixtures |
| Cost model | Fixed compact index | Embeddings + index build + script search |
| IDE lock-in | Claude Code | Cursor (`domains/core/hooks/hooks.platform.json` → empty `hooks`) |

Ticket: Linear **8CL-17**. Related analysis: [opensre-analysis.md](../guides/opensre-analysis.md) (harness / cost / hooks overlap).

### Cursor hook constraints (evidence)

- Cursor documents `sessionStart` and `additional_context` for injecting session context ([Hooks docs](https://cursor.com/docs/hooks.md)).
- **Cloud agents do not run `sessionStart`** (deferred while agents may start read-only).
- Community reports (2026): `sessionStart` `additional_context` can be accepted/merged in logs yet **not reach the Agent window** (race with composer handle). `env` from the same hook is more reliable; static `.cursor/rules` is the suggested workaround for static text.

So a mega-brain-style “zero tool call” injection path is **not reliable on Cursor today**, and is unavailable on cloud agents.

## Decision

| Choice | Verdict | Rationale |
|--------|---------|-----------|
| Port Claude Code mega-brain plugin literally | **Reject** | Wrong runtime; conflicts with ADR-003 provider-agnostic core |
| Replace LanceDB with OKF-only index | **Reject** | Ad-hoc semantic search remains required (`context-search`, profiles) |
| Wire `sessionStart` into platform `hooks.platform.json` now | **Defer** | Injection path unstable; cloud gap; empty hooks stay intentional |
| Keep LanceDB + on-demand memory | **Keep** | Current cost/quality tradeoff validated for platform |
| Optional OKF frontmatter + offline compact index (no hook) | **Defer** (follow-up) | Format is useful; wire only after Cursor injection is trustworthy or via non-hook path (rules/sync artifact) |

**Adopt later (conditional):** when Cursor reliably surfaces `additional_context` (or we choose a non-hook delivery such as a generated compact rules/memory snippet), add an optional OKF scanner under `domains/core/` synced like other hooks, keep LanceDB for semantic queries, and treat PostToolUse concept linking as phase 2.

## Consequences

### Easier

- No fragile platform hook in core while Cursor behavior is unsettled
- Clear license posture: cite mega-brain; do not vendor its plugin code (no `THIRD_PARTY.md` change for this defer)
- POC proves OKF frontmatter scanning without changing agent runtime

### Harder / deferred cost

- No automatic first-turn concept index in Cursor Agent (still rely on rules, `current_task`, LanceDB)
- Full Adopt still needs product work (see Effort)

## POC results

Script: [`eval/okf-session-poc/build-okf-index.ps1`](../../eval/okf-session-poc/build-okf-index.ps1)

- Scans `engine/context-engine/fixtures/profiles/**/*.md` for YAML frontmatter containing `type:`.
- Emits a compact stdout index (path, type, title/description).
- Sample concept: `fixtures/profiles/octo-cluster/context/okf-sample.md`.
- **Platform hooks unchanged** (`hooks.platform.json` remains `{ "version": 1, "hooks": {} }`).

**Verdict:** OKF **format** works offline. Cursor **session injection** path is **not** adopted (inviability / unreliability documented above). This satisfies “minimal POC or proof of inviability.”

### Recorded run

```text
<okf-poc>
Knowledge: 1 documented concept(s) in fixtures

  engine/context-engine/fixtures/profiles/octo-cluster/context/okf-sample.md [Concept] - Core domains, context-engine, and execution context layout for the platform profile.
</okf-poc>
```

## Effort estimate (if Adopt later)

| Work | Estimate |
|------|----------|
| Harden scanner (exclude dirs, `maxConcepts`, priority types) + tests | 0.5–1 d |
| Delivery path: hook **or** generated compact artifact via `sync-cursor` / memory | 1–2 d |
| Optional `type:` on selected fixtures/docs + docs | 0.5 d |
| PostToolUse concept linking (phase 2) | 1–2 d (separate card) |
| **Total (without phase 2)** | **~2–4 days** |

Revisit when Cursor confirms reliable `additional_context` for Agent, or when a non-hook delivery is preferred.

## Follow-ups (draft)

- `[memory] add optional OKF compact index generator for fixtures`
- `[rag] document OKF frontmatter convention for memory markdown`
- Re-evaluate `sessionStart` wiring after Cursor hook fix (link ADR status → Accepted or keep Deferred)

## References

- Upstream: https://github.com/guhcostan/claude-mega-brain (MIT)
- Open Knowledge Format (industry): Google Cloud OKF blog / related data-knowledge patterns
- Cursor Hooks: https://cursor.com/docs/hooks.md
- ADR-003: [provider-agnostic architecture](./ADR-003-provider-agnostic-architecture.md)
