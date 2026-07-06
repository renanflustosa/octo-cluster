# Path resolution

How Octo Cluster discovers its installation root across shells, IDEs, and agent runtimes.

## Root cause (prior behavior)

Documented commands used:

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 ...
```

The **outer shell** expands `$env:OCTO_CLUSTER` before PowerShell runs `-File`. When the session variable is empty — common in Cursor agent shells, external tools, and fresh terminals before workspace env loads — the path collapsed to `\scripts\invoke-pipeline.ps1` and failed.

Integrated terminals opened from `octo-cluster.code-workspace` worked because `terminal.integrated.env.windows` sets session `OCTO_CLUSTER`. Agent execution and non-IDE shells did not inherit that.

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Documented entry (octo.ps1 / octo-domain.ps1 / octo-run.ps1) │
└────────────────────────────┬────────────────────────────────┘
                             │ -File path from User-level OCTO_CLUSTER
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  scripts/_load-env.ps1  →  scripts/_env.ps1                 │
│  Get-OctoClusterRoot()                                      │
└────────────────────────────┬────────────────────────────────┘
                             │
         Resolution order (first valid install.ps1 or install.sh marker):
         1. Session  $env:OCTO_CLUSTER
         2. Walk up from executing script ($PSScriptRoot)
         3. User     [Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User')
         4. Machine  [Environment]::GetEnvironmentVariable('OCTO_CLUSTER','Machine')
         5. Sibling  <parent-of-preferred>/octo-cluster
```

**Single source of truth:** `scripts/_env.ps1` — all PowerShell harness scripts dot-source this via `_load-env.ps1`.

**TypeScript context-engine:** `engine/context-engine/src/lib/paths.ts` — walks up to `install.ps1` or `install.sh` when `process.env.OCTO_CLUSTER` is unset or invalid.

## Supported usage models

| Model | Session env | User env | Works in agent shells |
|-------|-------------|----------|------------------------|
| Dev Container (recommended) | set automatically | optional | yes |
| `install.sh` (Linux/macOS native) | set in shell | optional | yes with `export OCTO_CLUSTER` |
| `install.ps1` (Windows host optional) | optional | set | yes |
| `octo-cluster.code-workspace` only | set in IDE terminal | may be unset | no — run install once |
| Full `-File` path to `octo.ps1` | not required | not required | yes (self-locating) |

Dev Container or `./install.sh` / `install.ps1` is the bootstrap step for reliable agent + external shell usage.

## Entry points

| Script | Delegates to |
|--------|----------------|
| `octo.ps1` | `scripts/invoke-pipeline.ps1` |
| `octo-domain.ps1` | `scripts/invoke-domain-script.ps1` |
| `octo-run.ps1` | any script under the root (`eval/metrics/...`) |
| `scripts/octo` (bash shim) | `octo.ps1` via `pwsh` |
| `scripts/octo-domain` (bash shim) | `octo-domain.ps1` via `pwsh` |

## Documented command pattern

Use **User-level** env in `-File` paths (never session-only `$env:OCTO_CLUSTER` in outer `-File` arguments):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline scan -Action discover
```

Self-locating fallback (no env required):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\octo-cluster\octo.ps1" -Pipeline scan -Action discover
```

## Script arguments through `-File`

Hashtables **do not survive** `powershell -File` process boundaries (`-ScriptArgs @{ ... }` becomes the string `System.Collections.Hashtable`).

| Instead of | Use |
|------------|-----|
| `-ScriptArgs @{ Ticket = "X" }` | `-Ticket X` or omit (read from `current_task.md`) |
| `-ScriptArgs @{ Path = "..." }` | `-Path "..."` on `octo-domain.ps1` |
| `-ScriptArgs @{ SkipIndex = $true }` | `-SkipIndex` switch on `octo.ps1` |
| Complex nested args | `-ScriptArgsJson '{"key":"value"}'` |

Entry scripts invoke harness scripts **in-process** (no nested `powershell -File`) so merged hashtables work internally after flat/JSON args are parsed at the boundary.

## Error remediation

When resolution fails, scripts throw:

```text
OCTO_CLUSTER could not be resolved.
Remediation:
  1. Run install.ps1 from your clone root
  2. Open octo-cluster.code-workspace (integrated terminals)
  3. Invoke octo.ps1 with a full -File path
```

## Migration impact

- **Breaking:** none for scripts already invoked via `-File` under `scripts/` (self-locating).
- **Documentation:** all commands/skills now reference `octo.ps1` + User env subexpression.
- **Existing users:** re-run `install.ps1` if User env is missing; no code changes in product repos.
- **Multi-workspace:** child workspace files should keep `"OCTO_CLUSTER": "${workspaceFolder:octo-cluster}"` for integrated terminals; `install.ps1` still required for agents.

## Validation checklist

Run after clone or path-resolution changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\scripts\test-octo-path-resolution.ps1"
```

Manual checks:

- [ ] Fresh clone → `install.ps1` → User env set
- [ ] New external PowerShell: `$env:OCTO_CLUSTER` empty → `octo.ps1` discover still works via User env subexpression
- [ ] Cursor agent shell: `/scan` discover command succeeds
- [ ] Workspace integrated terminal: session env + User env both valid
- [ ] `bun run validate octo-cluster` from context-engine without session env
- [ ] `productivity-audit.ps1 -Workstation` reports OCTO_CLUSTER OK
