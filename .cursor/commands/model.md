# model

**Plan mode** — design first; **Execute plan** implements. Model: session default (Auto).

## Phase A — Plan (read-only)

No code, no git, no tests, no servers.

**Discover (first model only):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline model -Action discover
```

Read `PIPELINE_SKILL` + `core-adaptive-loop` once.

**Input:** `/scan` output + `current_task.md`. **`invoke-domain-script.ps1 -Name read-gate`** before Read on large files. Read ≤3 impl files.

**Harness:** SQLGlot only when capability docs flag SQL parity. Ollama optional per pack policy.

**Output:** approach · rejected alts · steps · **Target files** · **Forbidden paths** · done · out-of-scope · validation plan — **≤80 lines**, **≤6 todos**.

## Phase B — Execute plan (Agent)

User clicks **Execute plan** after approving Phase A. Same chat (SINGLE CARD MODE).

**Preflight:** pack scope-check script when present — exit 1 = **stop**.

**Rules:** target files from plan only; diff-only; read-gate on unknown files; **no validation** until `/ship`.

**Playbook:** `domains/core/skills/core-adaptive-loop/SKILL.md` · read `ponytail-lite` once — apply ladder before each file edit.

**Index pre-check (platform, before Phase A):** run `/scan` first (implicit daily bootstrap on first scan of the day), or:

```powershell
cd $env:OCTO_CLUSTER\engine\context-engine; bun run validate octo-cluster
```

Ensures LanceDB memory + harness validate before Plan. Cursor index covers codebase exploration separately.
