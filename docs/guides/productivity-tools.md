# Productivity tools — agnostic stack

> Local AI development harness — works for any project via capability packs.

---

## Design goals

**One-line vision:** a local **productivity harness** that does the maximum outside paid LLMs (scripts, hooks, RAG, MCP, rules) and invokes the Cursor model **only** when a phase needs judgment or code — with a reusable **CORE** parent and thin **child** domains per company/project.

### Objectives

| Goal | What it means | How this repo supports it |
|------|---------------|---------------------------|
| **Maximize harness** | Cursor is infrastructure, not just chat | Rules, skills, commands, scripts, LanceDB, memory, MCP, hooks, `domains/` → `.cursor/` sync |
| **Minimize tokens** | Structure is cheap; prose and history are expensive | One chat per work item; `current_task.md`; `@`≤3; grep before Read; Caveman lite; ponytail-lite on Execute; phase commands only; verify inside `/ship`; log compress |
| **Maximize synergy** | Each layer feeds the next | Workspace → sync → hooks → scripts → context-engine → memory → MCP → loop → `gh` / CI |
| **Maximize free/local models** | Local LLM = plumbing; paid LLM = brain of the card | Embeddings local (context-engine); optional local compress/classify; Cursor Agent for plan/build/ship |
| **Maximize hook automation** | Deterministic routines without prompts | Hooks for explore block, future start-workspace; prefer scripts over slash commands when no judgment needed |
| **Maximize CORE vs pack split** | Generic in core; product-specific in capability packs | `domains/core/` + `capabilities/<pack>/` + `contexts/`; see [`context-model.md`](./context-model.md) |
| **Prefer established tools** | Mature stack executes; custom code orients | Cursor, `gh`, Context7, Turbo/Vitest/Biome, Promptfoo — thin domain adapters, not a second framework |

### Token cost layers (official framework contract)

Use the cheapest layer that can finish the job. This ordering is the **public contract** for all capability packs:

```text
[COST 0]     hooks, sync, git, gh, bun test, LanceDB search, grep, gate scripts
[COST LOW]   Ask mode, scoped review
[COST HIGH]  Plan + Execute plan, /ship, /debug when reproduction is hard
```

**Rule:** only move up a layer when the layer below cannot resolve the task.

### Core vs capability packs

| **CORE** | **Capability pack (my-company, …)** |
|----------|------------------------------------------|
| Agnostic loop: scan → model → ship → close | Repo ownership, CARD_TYPE, issue-tracker routing |
| `/debug`, `/review`, caveman, systematic-debugging | Parity/auxiliary skills in `capabilities/<pack>/` |
| Memory/RAG patterns, generic hooks | Pack scripts (`<script_prefix>-*.ps1`) + providers |
| [`productivity-tools.md`](./productivity-tools.md) (this doc) | Pack playbooks under `capabilities/<pack>/` |

**Promotion rule:** if two or more packs need the same behavior → move it to CORE. If it names a product repo or legacy stack → keep in the pack.

### Established vs custom

| Established (compose) | Custom (thin adapter) |
|-----------------------|------------------------|
| Cursor rules/skills/hooks/Plan | Domain commands wired to core loop |
| `gh`, GitHub Actions CI | Ship/verify gates calling repo test commands |
| LanceDB + Bun context-engine | Index profiles per child domain |
| Context7, issue-tracker MCP | Pack-specific routing docs only |
| Promptfoo, Cursor babysit | Optional eval overlays per domain |

**Principle:** *established tools execute; custom assets orient and glue.*

---

## `octo-cluster` (single source of truth)

Git repo that syncs Cursor rules, skills, and local RAG tooling. Clone once per machine; open via the multi-root workspace (not global `~/.cursor` symlinks).

| Path | Role |
|------|------|
| `domains/core/` | Parent CORE — agnostic rules, synced skills/commands, harness scripts |
| `capabilities/` | Pack manifests (`scan`, `ship`, …), providers, canonical `skill.md` |
| `contexts/` | Execution context JSON — enabled packs, repo ownership, `docs_root` |
| `domains/companyN/` … | Child scaffolds — rules/hooks when a new company is ready |
| `.cursor/` | What Cursor reads — **generated**; skills/commands core-only |
| `.cursor/capabilities-skills.json` | Pipeline + auxiliary skill index (regenerated on sync) |
| `engine/context-engine/` | LanceDB local semantic search (Bun) |
| `state/memory/` | Per-profile agent memory (gitignored) |
| `eval/promptfoo/` | Optional command/skill regression evals |
| `eval/agentic/` | Manual A/B LOC + safety scoring (ponytail-lite pilot) |
| `eval/metrics/` | Harness score + card CSV (token/harness proxies) |
| `workspaces/*.code-workspace` | Multi-root entry points — each sets `AI_EXECUTION_CONTEXT` |

**Bootstrap (new machine):**

```powershell
git clone https://github.com/renanflustosa/octo-cluster.git <clone-root>
cd <clone-root>
.\install.ps1
```

**After editing `domains/`:**

```powershell
.\scripts\sync-cursor.ps1
```

Active execution context comes from `AI_EXECUTION_CONTEXT` in the workspace file (default `platform`). See [`context-model.md`](./context-model.md).

**Env:** `OCTO_CLUSTER` — User env (set by `install.ps1`) or workspace session env. See [path-resolution.md](../architecture/path-resolution.md). `AI_EXECUTION_CONTEXT` selects capability packs (`platform`, `company2`, …).

**What stays in `~/.cursor`:** Cursor runtime only (`projects/`, `skills-cursor/`, `plugins/`, plans). Migrated loop assets live in `octo-cluster`, not under the home profile.

---

## Local environment (machine)

| Runtime / tool | Detected version | Generic use |
|----------------|------------------|-------------|
| **Windows 10/11** | 10.0.26100 | Primary OS |
| **PowerShell** | — | Shell, scripts, automation |
| **Bun** | 1.3.9 | Fast JS/TS runtime; context-engine; npm alternative |
| **Node.js** | 24.13.1 | JS ecosystem; tool engines |
| **.NET SDK** | 9.0.304 | C# APIs and services |
| **Flutter** | 3.44.2 stable | Cross-platform mobile apps |
| **Git** | — | Version control |
| **GitHub CLI (`gh`)** | — | PRs, issues, checks, releases from the terminal |
| **Docker** | — | Local dependencies, testcontainers, deploy |
| **VS Code / Cursor** | — | Primary IDE |

---

## IDE: Cursor

VS Code–based editor with integrated AI agents.

| Feature | What it's for (any project) |
|---------|----------------------------|
| **Agent mode** | Implement, refactor, debug with terminal and file access |
| **Plan mode** | Design approach before coding; trade-offs and architecture |
| **Ask mode** | Explore code and answer without editing |
| **Debug mode** | Investigate bugs with runtime evidence |
| **Multitask / subagents** | Parallel tasks (explore, shell, review) |
| **Rules (`octo-cluster/.cursor/rules/`)** | Persistent instructions — `domains/core/rules/` + active child rules |
| **Skills (`octo-cluster/.cursor/skills/`)** | Core playbooks only — pack skills via `invoke-pipeline discover` |
| **MCP servers** | Connect external tools (issues, docs, search) to the agent |
| **Composer / chat** | Fast iteration on files with context |

**Workflow:** edit `domains/` → `sync-cursor.ps1` → Cursor picks up `.cursor/`. Product repos keep their own `.cursor/` or `.agents/` only when team-owned.

---

## Installed skills (agnostic)

### In `octo-cluster/domains/core/skills/` and `domains/core/commands/`

| Skill / command | Role |
|-----------------|------|
| **caveman** | Telegraphic replies — lite default; off on model/ship/security |
| **ponytail-lite** | Minimal implementation ladder before writing code (Execute plan) |
| **minimal-review** | Over-engineering delete-list on diff; optional before `/ship` |
| **systematic-debugging** | Protocol before proposing a fix: reproduce, isolate, trace root cause |
| **code-review** | Review GitHub PRs (bugs, security, performance, quality) |
| **simplify** | Clarity post-edit within ponytail-lite's chosen solution |
| **find-skills** | Discover and install new skills |
| **`/debug`** | Runtime bugs — uses systematic-debugging |
| **`/review`** | GitHub PR review — uses code-review |
| **`/minimal-review`** | Diff audit for over-engineering only |

Paired rules: `caveman-mode.mdc` (prose) · `ponytail-lite.mdc` (implementation ladder).

### In `~/.cursor/skills-cursor/` (Cursor bundled)

| Skill | Role |
|-------|------|
| **create-skill** | Author custom skills |
| **create-rule** | Create persistent Cursor rules |
| **create-hook** | Automation on Cursor events (hooks) |
| **split-to-prs** | Split work into smaller PRs |
| **babysit** | Keep PR mergeable (comments, CI, conflicts) |
| **canvas** | Visual artifacts (analyses, tables, timelines) |
| **context7-mcp** | Fetch up-to-date library documentation |
| **langfuse** | Prompt observability, traces, and LLM sessions |

Pack-specific skills live under **`capabilities/<pack>/`**. The loop below is the **agnostic pattern**; any project can adopt the same phases with its own tracker, repos, and pack config.

---

## Continuous improvement loop (agnostic)

A **project-independent** workflow for turning work items into shipped, verified changes. Same phases in any stack (web, mobile, API, data, infra): clarify → design → build → prove → deliver → archive → repeat.

**One chat = one work item.** Start a new chat only after `/close`. Routine edits do not need a command — use commands for **phase changes** only.

### Loop

```
/scan → /model → Execute plan → /ship → /close
```

Optional morning bootstrap: `/start-workspace` (environment health, memory index, local tooling — see child domain for project-specific steps).

### Commands (abstract)

| Command | Mode | Purpose | Generic outcome |
|---------|------|---------|-----------------|
| **`/scan`** | Agent | **Orient** — understand the task, scope, and context | Goal, boundaries, risks, branch/setup, compact task state (e.g. `current_task.md`) |
| **`/model`** | Plan → Execute | **Design** then **build** — Plan phase: no code; Execute plan: scoped implementation from approved design | Written plan (approach, target files, done criteria) → minimal diff in agreed scope |
| **`/ship`** | Agent | **Prove and deliver** — implicit verification first; ship only if **READY**; then PR/commit gates | Verdict (READY / NEEDS FIXES / BLOCKED) + PR or merge-ready branch |
| **`/close`** | Agent | **Archive and reset** — capture learnings, compact memory, clear active task | Ticket/work item archived; next item starts with fresh `/scan` |

Supporting commands (any project): **`/debug`** (runtime bugs), **`/review`** (GitHub PR review).

### Phase detail (stack-neutral)

| Phase | What you do | What you avoid |
|-------|-------------|----------------|
| **Scan** | Read ticket/issue; define scope and repos; note risks; update lightweight task file | Implementing, opening wide grep, mixing multiple tasks |
| **Model** | Trade-offs, closed file list, acceptance criteria, validation plan | Coding during Plan; unbounded scope |
| **Execute plan** | Edit only planned paths; small diffs; defer full test suites | Refactors, drive-by fixes, shipping before proof |
| **Ship** | Scoped tests/typecheck from validation plan; CI-parity gate if applicable; PR when asked | Push on NEEDS FIXES; force push to main |
| **close** | Archive notes, reindex local memory if used, clear task state | Carry-forward paste into next chat |

### Verification inside `/ship`

`/ship` always includes an **implicit verify** step:

1. Run the **validation plan** from `/model` (scoped — not whole-repo `check` unless the project requires it).
2. Emit verdict: **READY** | **NEEDS FIXES** | **BLOCKED**.
3. **READY only** → proceed to push/PR and project gates (hooks, CI smoke, etc.).
4. **NEEDS FIXES** → stop; fix via Execute plan; run `/ship` again.

This keeps “did we prove it?” and “did we deliver it?” in one deliberate phase without a separate verify command.

### Continuous improvement mindset

| Principle | Practice |
|-----------|----------|
| **Small batches** | One work item per chat; small PRs |
| **Design before code** | `/model` Plan before Execute plan on non-trivial work |
| **Prove before ship** | `/ship` verify gate; no merge on BLOCKED |
| **Institutional memory** | `/close` archives what worked; local RAG/memory optional (`engine/context-engine/`) |
| **Adapt per project** | Issue tracker, branch naming, and test commands live in the **capability pack** — not in this doc |

### Capability packs

Private or public packs implement the loop via `contexts/<pack>.json`, `capabilities/<pack>/`, and your issue tracker. That is **one pack**, not the definition of the loop. See [add-child-context.md](./add-child-context.md).

---

## MCP servers (Model Context Protocol)

Integrations the agent can call during chat.

| Server | Generic use |
|--------|-------------|
| **Issue tracker** | Issues, projects, milestones (private overlay / capability pack) |
| **Context7** | Library docs (React, Hono, Prisma, etc.) without API hallucination |
| **Langfuse** | Agent traces, datasets, scores, prompt debugging |
| **Sourcegraph** | Semantic search and navigation in large codebases |

**Rule:** always read the tool schema in the project's `mcps/<server>/tools/` folder before calling.

---

## Local secrets management

Never commit credentials. Use a **local gitignored** vault (separate folder or `.env.local`).

```
{ENV}/{PROJECT}/{SERVICE}.json
```

| Principle | Detail |
|-----------|--------|
| **Local only** | Never commit, push, or paste values in chat/PR |
| **Mapping** | Vault → gitignored `.env` / `.env.local` per repo |
| **Code references** | Variable names only, never values |
| **Rotation** | Change vault only when explicitly requested |

---

## Code quality (transferable)

Tools used in the modern stack; applicable to any TS monorepo:

| Tool | Role |
|------|------|
| **Biome** | Lint + format (ESLint+Prettier alternative, faster) |
| **Ultracite** | Opinionated rule layer on top of Biome |
| **Lefthook** | Git hooks (pre-commit, pre-push) with light config |
| **Vitest** | Unit and integration tests in JS/TS |
| **Vitest Browser Mode + Playwright** | Component tests with a real browser |
| **MSW** | HTTP mocking in dev and tests |
| **dependency-cruiser** | Enforce architecture boundaries between packages |
| **type-coverage** | % of typed code |
| **Fallow** | Static audit: duplication, dead exports, complexity, flags |
| **ast-grep** | Structural refactors by AST pattern |
| **Testcontainers** | Ephemeral DBs/services in integration tests |
| **Turbo** | Monorepo cache and orchestration |
| **openapi-typescript** | TS types generated from OpenAPI |

---

## Observability (modern standard)

| Tool | Role |
|------|------|
| **OpenTelemetry** | Vendor-neutral traces and metrics |
| **Pino** | Structured JSON logging (Node/Bun) |
| **Prometheus** (`prom-client`) | HTTP and custom metrics |
| **OTLP exporter** | Send telemetry to Jaeger, Grafana, Datadog, etc. |

---

## Git and GitHub (generic workflow)

| Practice | How |
|----------|-----|
| **Branches** | `type/issue-id-short-description` |
| **Commits** | Message focused on *why*; commit only when asked |
| **PRs** | `gh pr create` with summary + test plan |
| **Review** | `code-review` skill or Bugbot subagent |
| **CI** | Check status with `gh pr checks` |

**Never:** force push to main, amend after push, skip hooks without explicit request.

---

## AI helpers beyond Cursor

| Tool | Use |
|------|-----|
| **Aider** | Terminal pair programming; `.aider.conf.yml` per repo |
| **Cursor Automations** | Recurring tasks (`automate` skill) |
| **Cursor SDK** | Run agents programmatically (CI, bots, pipelines) |
| **Promptfoo** | Optional evals under `octo-cluster/eval/promptfoo/` |

---

## Knowledge organization for agents

Patterns that work in any large codebase:

| Artifact | Role |
|----------|------|
| **`CONTEXT.md` in repo** | Architecture summary for humans and AI |
| **`state/memory/<profile>/current_task.md`** | Active ticket state (≤200 tokens) |
| **`state/memory/<profile>/`** | Tickets, architecture notes, vector index (gitignored) |
| **`engine/context-engine/`** | LanceDB indexing + search; validate with `bun run validate` |
| **Traceability matrices** | Map legacy ↔ new ↔ API (adaptable to any migration) |
| **Domain glossary** | Business entities in versioned markdown |

Context-engine resolves paths via `OCTO_CLUSTER`; memory never lives in product repos.

### CORE loop harness (zero-token substitutes)

| Spec tool | DIY substitute in octo-cluster |
|-----------|----------------------------------|
| Tree-sitter / Grep-ast | `core-map.ps1` → `engine/context-engine/src/map-file.ts` |
| Tiktoken | `token-budget.ts` + line caps in rules |
| DuckDB CLI | `compress-log.ts` + optional query template below |
| ChromaDB / Qdrant | LanceDB + FTS5 hybrid |
| LiteLLM / Ollama | Deprioritized — Cursor Agent for Execute; opt-in via domain policy |

**Dispatch:** `scripts/invoke-pipeline.ps1 -Pipeline <phase> -Action discover|run` resolves pack skills and providers. `scripts/invoke-domain-script.ps1 -Name <gate>` resolves pack scripts via `contexts/<pack>.json` → `script_prefix`.

**DuckDB log template (optional `/ship` for batch/sync cards):**

```sql
SELECT phase, verdict, COUNT(*) AS n
FROM read_csv_auto('state/logs/metrics-baseline/*.csv')
GROUP BY 1, 2;
```

---

## Systematic debugging

Before proposing a fix (`systematic-debugging` skill):

1. Reproduce the bug reliably
2. Form hypotheses; test one at a time
3. Trace root cause (not symptoms)
4. Minimal fix + verification
5. Refactor only if needed

---

## Day-to-day productivity

| Habit | Benefit |
|-------|---------|
| **One chat per task** | Clean context; less drift |
| **Few `@` files** | Focus; less noise for the agent |
| **grep before glob** | Cheap search before reading a lot |
| **Plan before build** | `/model` Plan → Execute plan on non-trivial work |
| **Prove before ship** | `/ship` implicit verify; READY required |
| **Close the loop** | `/close` then new chat for the next item |
| **Vault for secrets** | Never leak credentials in committed `.env` |
| **Library docs via Context7** | Up-to-date API without guessing |
| **Caveman lite default** | Shorter status replies; full prose when ambiguity matters |
| **Ponytail-lite on Execute** | Smallest correct diff; reuse stdlib/native before new deps |
| **Sync after domain edits** | `sync-cursor.ps1` keeps `.cursor/` aligned with git |

---

## This folder (`docs/`)

| File | Content |
|------|---------|
| [`index.md`](./index.md) | Index and layout overview |
| [`context-model.md`](./context-model.md) | Parent/child domain model |
| [`add-child-context.md`](./add-child-context.md) | Scaffold a new child domain |
| [`productivity-tools.md`](./productivity-tools.md) | This document — design goals + agnostic setup |

---

## COST 0 install audit

Run locally after `install.ps1` or when onboarding a machine:

```powershell
.\scripts\productivity-audit.ps1
```

| Layer | Tool | Validate |
|-------|------|----------|
| COST 0 | Git | `git --version` |
| COST 0 | GitHub CLI | `gh --version` + `gh auth status` |
| COST 0 | Bun | `bun --version` or `%USERPROFILE%\.bun\bin\bun.exe` |
| COST 0 | LanceDB | `engine/context-engine/node_modules/@lancedb/lancedb` |
| COST 0 | Memory index | `state/memory/octo-cluster/vector/lancedb` |
| COST 0 | grep / rg | `Select-String` or `rg --version` (optional) |
| COST 0 | Repo verify | `repo-policies/<repo>.yaml` -> `/ship` verification phase |

**Rule:** fix MISSING before `/model` Execute plan on platform cards. WARN on `gh auth` is acceptable for local-only work.

### `/model` Plan — index pre-check (platform)

Before Phase A Plan on non-trivial work:

```powershell
# Once per day (or after memory/doc edits)
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline start-workspace -Action run

# Or quick validate only
cd "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\engine\context-engine"
bun run validate octo-cluster
```

Cursor Compute index covers codebase exploration; LanceDB covers harness scripts + memory for `core-context-search`.

---

## Platform context acceptance

Open `octo-cluster.code-workspace` (`AI_EXECUTION_CONTEXT=platform`).

| Scenario | Pass criteria |
|----------|---------------|
| Single-root workspace | `octo-cluster.code-workspace` with `AI_EXECUTION_CONTEXT=platform` |
| Pack isolation | `invoke-pipeline scan discover` → `enabled_capability_packs: ["core"]` only |
| No private pack on ship | `invoke-pipeline ship discover` → core providers only |
| Repo verify | `repo-policies/octo-cluster.yaml` commands run on `/ship` verification |
| Full loop | `/start-workspace` or `/start-workspace` -> `/scan` -> `/model` -> Execute -> `/ship` -> `/close` |
| Productivity audit | `.\scripts\productivity-audit.ps1` -> READY |

See also [`decoupling-map.md`](./decoupling-map.md) and [`context-model.md`](./context-model.md).

---

## Repository policies (F4)

Git delivery and scoped verify commands live in `repo-policies/` — core scripts never hardcode repo-specific rules.

| File | Role |
|------|------|
| `default.yaml` | Base git + `verify.enabled` |
| `octo-cluster.yaml` | Direct-to-main; context-engine validate + core grep gates |
| `consumer-demo.yaml` | Example: feature branch + PR; `go build` / `go vet` |

Ship orchestration: **verification** phase runs policy commands via `repo-policy-verify` provider; **git** phase reads policy only.

