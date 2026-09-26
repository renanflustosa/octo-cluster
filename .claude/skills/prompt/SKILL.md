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

1. **Objective.** Find the real objective and the observable "done" state. Several independent objectives → one prompt each, in run order (one session per objective keeps context small).
2. **Carry the context.** The fresh session sees none of this conversation. Turn references ("this", "the error above", "like before") into concrete facts; copy error messages, paths, URLs, IDs and numbers verbatim.
3. **Ground it**, read-only and cheap: up to ~5 Glob/Grep/Read calls to confirm file paths, the test/lint/build command, and patterns to follow. No subagents. In a multi-repo hub, identify the target project folder. Skip when the request is not about files on disk.
4. **Resolve ambiguity** with explicit assumptions. Ask only when a wrong guess would waste the whole run: one AskUserQuestion with 2-4 concrete options, then stop.
5. **Pick** the permission mode (below) and the tier (cost-routing).
6. **Write the prompt.** Never change the objective or add requirements; improve clarity, scope, and verification only. Already a good prompt → change little and say so.

## Permission mode

Recommend exactly one:

| Mode | When | How to enter |
| --- | --- | --- |
| **Plan mode** | Multi-file refactor, migration, architecture, audit, unclear impact, anything where a wrong first edit is costly | Shift+Tab until "plan mode on" (CLI) or the mode picker (desktop); approve the plan before edits |
| **Execute** | Scope is clear: fix a bug, implement a bounded feature, add tests, rename, write docs into the repo | Default mode, or accept-edits for low-risk edits |
| **Read-only** | Explain, research, review, compare options, answer a question | Default mode; the prompt says "do not edit files" |

Never pick Execute when the request still needs a plan.

## How to write for Opus 5.5 (high effort)

- **Direct and specific.** No "You are an expert…" role line unless a role changes behavior (e.g. "review as a security auditor").
- **No reasoning boosters.** High effort already thinks; skip "think step by step" / "ultrathink".
- **Calm wording.** No ALL-CAPS, "CRITICAL", or "MUST" stacks; Opus follows plain instructions and over-applies shouted ones. Give the *why* for non-obvious constraints instead.
- **Size to the task.** A one-line fix gets a few lines; only complex work uses every section of the skeleton.
- **Facts, not guesses.** Cite only paths and commands you verified; otherwise say where to look ("the auth middleware under `src/server/`").
- **Tight scope.** Name what to touch and what not to touch; say "smallest change that works, no unrelated refactors" (Opus tends to over-build).
- **Files by reference.** `@path` for small key files (loads them into context); plain paths for large ones so they are read only if needed. Bound searches to folders or file types.
- **Verifiable done.** Concrete success criteria plus the exact command to verify (focused test first). No test → say how to check by hand; UI change → which page or route to open and what should appear.
- **Stop rules.** Task-specific triggers to stop and ask: missing fact, destructive or irreversible step, data or schema migration.
- **No repeats.** The session already loads `CLAUDE.md` and the always-on rules (commit policy, retry cap, prose style, boundary); do not restate them. Delivery requested → the last step is `/ship`.
- **No secrets.** Never paste credential values; name the file or env var that holds them.
- **Short output.** Ask for a brief final report (what changed, how verified, open risks), not a narrative.

## Prompt skeleton

Keep only the lines that carry information, in this order:

````text
<Objective in one or two sentences, including why.>

Work in: <folder, only when it is not the session root>

Context:
- <verified facts: @small-file or plain path, current behavior, exact error>

Scope:
- Change: <files or areas>
- Leave alone: <files or areas>. Smallest change that works, no unrelated refactors.

Steps: (only when order matters)
1. ...

Done when:
- <observable result>

Verify: `<exact command>` | <how to check by hand>

Stop and ask if: <task-specific triggers>

Report: what changed, how it was verified, open risks. Brief.
````

## Output

Reply in the operator's language; translate the headings, keep this structure:

## Recommended mode

Plan mode | Execute | Read-only

### Why

One or two lines.

### Session

One line: fresh session or `/clear` if the current context is unrelated; the folder to open when it is not the current root; tier L0-L4 per cost-routing. Mention model or effort only when the tier does not fit Opus 5.5 high (e.g. L0 → `/model haiku` or `/effort low`).

---

## Optimized prompt

````text
<self-contained prompt, ready to paste into Claude Code>
````

Fence it with four backticks so code blocks inside the prompt cannot close it.

---

## Assumptions

Assumptions made (omit the section when there are none).

## Improvements

Up to 3 short bullets: what became more specific, scoped, or verifiable.

Several prompts → number them in run order, each with its own mode, why, session and prompt; assumptions and improvements once at the end.
