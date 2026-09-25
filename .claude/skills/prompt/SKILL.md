---
name: prompt
description: Rewrite a request into a precise Claude Code prompt for Opus 5.5 at high effort (never executes it).
argument-hint: <any request>
disable-model-invocation: true
---

# prompt

Rewrite the raw request into a prompt that a fresh Claude Code session (Opus 5.5, high effort) can run with no follow-up questions. **Never execute the request, never edit files, never write the code asked for.** Output only the package below.

Raw request: $ARGUMENTS

If the raw request is empty, ask for it in one line and stop.

## Process

1. Find the real objective and the observable "done" state.
2. Ground it in the repo, read-only and cheap: up to ~5 Glob/Grep/Read calls to confirm file paths, the test/lint/build command, and existing patterns to follow. No subagents. Skip when the request is not about this repo.
3. Resolve ambiguity with **explicit assumptions**. Ask the operator only when a wrong guess would waste the whole run (one short question, then stop).
4. Pick the permission mode (below).
5. Write the prompt. Never add requirements that change the objective; improve clarity, scope, and verification only.

## Permission mode

Recommend exactly one:

| Mode | When | How to enter |
| --- | --- | --- |
| **Plan mode** | Multi-file refactor, migration, architecture, audit, unclear impact, anything where a wrong first edit is costly | Shift+Tab until "plan mode on"; approve the plan before edits |
| **Execute** | Scope is clear: fix a bug, implement a bounded feature, add tests, rename, write docs into the repo | Default mode, or auto-accept edits (Shift+Tab) for low-risk edits |
| **Read-only** | Explain, research, review, compare options, answer a question | Default mode; the prompt says "do not edit files" |

Never pick Execute when the request still needs a plan.

## How to write for Opus 5.5 (high effort)

- **Direct and specific.** No "You are an expert…" role line unless a role changes behavior (e.g. "review as a security auditor").
- **No reasoning boosters.** High effort already thinks; skip "think step by step" / "ultrathink".
- **Calm wording.** No ALL-CAPS, "CRITICAL", or "MUST" stacks; Opus follows plain instructions and over-applies shouted ones. Give the *why* for non-obvious constraints instead.
- **Tight scope.** Name what to touch and what not to touch; say "smallest change that works, no unrelated refactors" (Opus tends to over-build).
- **Files by reference.** `@path` for small key files (loads them into context); plain paths for large ones so they are read only if needed. Bound searches to folders or file types.
- **Verifiable done.** Concrete success criteria plus the exact command to verify (focused test first). If no test exists, say how to check.
- **Stop rules.** When to stop and ask (missing fact, destructive or irreversible step); cap retries ("after 2 failed attempts with the same approach, stop and report evidence").
- **Git.** Do not commit or push unless the request says so; delivery goes through `/ship`.
- **Short output.** Ask for a brief final report (what changed, how verified, open risks), not a narrative.
- Include only sections that carry information: objective, context, scope and constraints, steps (only when order matters), success criteria, verification, do-nots, report format.

## Output

Reply in the operator's language, with exactly this structure:

## Modo recomendado

Plan mode | Execute | Read-only

### Motivo

One or two lines.

### Sessão

One line: fresh session or `/clear` if the current context is unrelated; tier L0-L4 per cost-routing. Mention model or effort only when the tier does not fit Opus 5.5 high (e.g. L0 → `/model haiku` or `/effort low`).

---

## Prompt otimizado

```text
<self-contained prompt, ready to paste into Claude Code>
```

---

## Suposições

Assumptions made (omit the section when there are none).

## Melhorias realizadas

Short bullets: what became more specific, scoped, or verifiable.
