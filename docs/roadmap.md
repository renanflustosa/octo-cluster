# Octo Cluster — diagnosis and roadmap (2026-10)

Goal: make octo-cluster useful to developers and tech professionals who use Claude Code daily. Its value must sit where Claude Code does not deliver on its own; anything native becomes an integration or goes away.

## 1. Diagnosis (main @ 25413d7)

**What it is today:** 41 files, ~2.1k lines. Five always-on rules (`.cursor/rules/*.mdc`, imported by `CLAUDE.md`), six skills in `.claude/skills/` (`/prompt`, `/ship`, `/debug`, `ponytail-lite`, `systematic-debugging`, `pr-review`), two PowerShell scripts (`ship.ps1`, `boundary-audit.ps1`), git hooks, one CI job (boundary audit on `windows-latest`), and opt-in examples (secret-scan hook, cost profile).

**How it is installed and used:** clone, `pwsh -File install.ps1` (sets `core.hooksPath`), open the folder in Cursor or Claude Code. To use it elsewhere: `install.ps1 -ClaudeSkillsTo <hub>` creates junctions and you add `@<octo>/CLAUDE.md` to the hub. That is Windows-only (junctions), several manual steps, and Claude Code has no update path.

**Checks:** `boundary-audit.ps1` passes (no patterns configured). CI has no other checks: nothing validates skills, rules or scripts.

**Broken or stale:**

| Finding | Impact |
| --- | --- |
| The GitHub description still sells "RAG, memory, token economy, verify gates … phase commands, extensible packs"; RAG, memory, packs and phase commands were removed in the MVP/vNext refactors (#54, #74, #77). | First impression promises things that do not exist. |
| `/debug` collides with Claude Code's built-in `/debug`. | Ambiguous invocation; the built-in may win. |
| `pr-review` duplicates the built-in `/code-review [pr#] [--comment]`. | Extra listing tokens, two ways to do the same thing. |
| `caveman-mode` duplicates the built-in **Concise** output style (v2.1.237+). | Always-on tokens spent on something a setting does for free. |
| `/prompt` and `cost-routing` hard-code model names (Opus 5.5, haiku/sonnet/opus tiers); the cost profile uses the key `claude-sonnet-5` in `modelSettings`. | Rots with every model release; the key may not match the current Sonnet ID. |
| `execute-operator-intent` is an always-on "no soft refusal" rule. | In a public repo it reads like a jailbreak; it is not why anyone would adopt the project. |
| README targets "Windows 11 + Cursor / Claude Code" and opens with layers, not with a problem. | It does not say who it is for or what it saves them. |
| No CONTRIBUTING, issue templates, CHANGELOG or releases (removed in #74). | Hard to contribute; there is no version for users to pin. |

## 2. Feature fit

Checked against the current Claude Code docs (plugins, hooks, output styles, skills, costs, prompt caching).

| Feature | Verdict | Action |
| --- | --- | --- |
| RAG, memory, packs, phase commands | **Obsolete** (already removed) | Remove them from the GitHub description. |
| `/ship` (logical commits, then direct push or branch + PR based on the real branch protection, never force-pushes) | **Differentiator**: there is no built-in `/commit` or `/ship`, and the official `commit-commands` plugin does not detect protection | Keep; ship it in the plugin. |
| `/prompt` (rewrites a rough request into a self-contained prompt) | **Differentiator**: no built-in equivalent (`/doctor prompt-audit` audits instruction files, not requests) | Keep; make it model-agnostic. |
| Boundary audit + git hooks + CI (block client/private names in public repos) | **Differentiator**: nothing native; useful to anyone who keeps client work next to public repos | Keep the git hooks (they work in any tool); add an opt-in plugin `PreToolUse` hook on `git commit` / `git push`. |
| `systematic-debugging`, `ponytail-lite` (curated playbooks) | **Differentiator** (the content) | Keep as on-demand skills. |
| `/debug` | **Overlaps native** (name) | Rename (e.g. `/fix`) and keep the playbook. |
| `pr-review` | **Overlaps native** (`/code-review`) | Drop it for Claude Code; keep it for Cursor until the Cursor path is decided. |
| `caveman-mode` | **Overlaps native** (Concise output style) | Recommend `/config` → Output style → Concise; keep the `.mdc` for Cursor only. |
| `cost-routing` rule + cost profile + token-economics guide | **Partial differentiator**: the levers are native (`/usage`, `opusplan`, `CLAUDE_CODE_SUBAGENT_MODEL`, `autoCompactWindow`, effort); the curated profile and the "how not to burn the weekly limit" guidance are not | Keep the guide and the profile with fixed keys; turn the rule into a tiny model-agnostic one. |
| `.claude/settings.json` deny rules | **Native** (and a plugin cannot ship `permissions.deny`) | Keep as a documented snippet; the secret-scan hook covers it in the plugin. |
| Secret-scan hook example | **Partial differentiator** (Windows/PowerShell-ready, dual Cursor/Claude protocol) | Ship it as an opt-in plugin hook. |
| `execute-operator-intent` | **Out of scope** for a public product | Move it to `examples/` as opt-in. |
| `install.ps1 -ClaudeSkillsTo` (junctions) | **Overlaps native** (plugins + marketplace) | Replace with `claude plugin install`; keep `install.ps1` for git hooks and Cursor. |

## 3. Personas

| Persona | Main pain | What octo-cluster gives |
| --- | --- | --- |
| **Solo dev on Pro/Max with a weekly limit** (Windows or macOS, several side projects) | Hits the limit mid-week; doesn't know which levers matter. | Cost profile, the token-economics guide, `/prompt` (fewer back-and-forth turns), `/usage` before/after. |
| **Freelancer / OSS maintainer** working on client code next to public repos | Leaking a client name, internal path or secret into a public commit or PR. | Boundary gate (git hooks + Claude hook) and `/ship` that never force-pushes and respects protection. |
| **Tech lead standardizing a small team** | Everyone commits, opens PRs and prompts differently. | Project-scope plugin enabled through `.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`), plus the same `/ship` convention for everyone. |

## 4. Roadmap (impact × effort)

| # | Item | Impact | Effort | Notes |
| --- | --- | --- | --- | --- |
| **1** | **Plugin + one-command install + new README** (first slice, below) | High | S | Unblocks every other item. |
| 2 | Boundary guard as an opt-in plugin hook (`PreToolUse` on `git commit` / `git push`, patterns via `userConfig`) | High (persona 2) | M | Same audit script; `onFailure: block`. |
| 3 | Cost kit: fix the model keys, add a `/cost-profile` skill that merges into `~/.claude/settings.json` after confirmation, measure with `/usage` | High (persona 1) | S–M | No hard-coded model names. |
| 4 | Clean the native overlaps: rename `/debug`, drop `pr-review` and caveman from the Claude path, make `/prompt` model-agnostic | Medium | S | **Breaking:** `/debug` → new name (document it in the CHANGELOG). |
| 5 | Secret-scan hook in the plugin (opt-in) | Medium | S | Already written; needs plugin wiring and a test. |
| 6 | Team onboarding doc: the `.claude/settings.json` snippet that enables the plugin for a repo | Medium (persona 3) | S | Each teammate still runs `claude plugin install` once. |
| 7 | Cross-platform: CI matrix (windows + ubuntu with pwsh); document `pwsh` on macOS/Linux | Medium | S | The scripts are already pwsh-compatible. |
| 8 | Contributor surface: CONTRIBUTING, issue/PR templates, CHANGELOG, tagged releases tied to the `version` in `plugin.json` | Medium | S | Releases are external actions. |
| 9 | `execute-operator-intent` → `examples/` | Low | XS | |
| 10 | List it in community marketplaces / share it | Medium | S | External; after 1–4. |

### First slice (item 1)

- Add `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (`source: "."`, marketplace name `octo-cluster`). The skills stay in `.claude/skills/` (custom path in the manifest) so Cursor keeps working; `claude plugin validate` confirms the manifest.
- Plugin content: `/ship`, `/prompt`, `/debug` (namespaced as `/octo-cluster:debug`, so no clash with the built-in), `systematic-debugging`, `ponytail-lite`, and a `SessionStart` hook that injects only the thin always-on rules (ponytail-lite + cost-routing, ~1.1 KB, read from the existing `.mdc` files so there is a single source). Caveman, `execute-operator-intent` and `pr-review` are not loaded by the plugin.
- Install, on any OS:
  ```bash
  claude plugin install octo-cluster --marketplace renanflustosa/octo-cluster
  ```
  Inside a session: `/plugin install octo-cluster --marketplace renanflustosa/octo-cluster`. `install.ps1` stays for git hooks and Cursor.
- Five-minute win: `/octo-cluster:prompt <rough request>` returns a ready-to-run prompt; `/octo-cluster:ship` on a dirty repo produces logical commits and the right delivery mode (`-WhatIf` first).
- README opens with: who it is for, the problem, the install command, and a before/after (rough request → generated prompt; `git add . && git commit -m wip && git push` → logical commits + PR).
- CI: add a `claude plugin validate` job if it runs without auth; if it needs auth, add a JSON schema check instead.
- **Breaking:** users of `install.ps1 -ClaudeSkillsTo` must delete the junctions in `<hub>/.claude/skills/` and the `@<octo>/CLAUDE.md` import before installing the plugin, or the skills show up twice. Rollback: uninstall the plugin and re-run `install.ps1 -ClaudeSkillsTo`.
- The manifest lists skill folders under `./.claude/skills/` directly (accepted by `claude plugin validate`), so nothing moves and Cursor is unaffected.
