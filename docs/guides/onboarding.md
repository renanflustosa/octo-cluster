# Onboarding — octo-cluster (platform)

Full setup guide. Quick start: [README.md](../../README.md).

Read [EOS](../governance/eos.md) for project conventions.

## Prerequisites

| Item | How |
|------|-----|
| Git | [git-scm.com](https://git-scm.com/download/win) |
| Bun, gh, ripgrep | `.\install.ps1` (direct download, no winget) |
| Go (optional) | `.\scripts\install-go.ps1` — [go.dev](https://go.dev/dl/) |
| Ollama (optional) | `.\scripts\install-ollama.ps1` |
| WSL2 Ubuntu (optional) | `.\scripts\install-wsl.ps1` |
| Docker Desktop (optional) | `.\scripts\install-docker.ps1` |
| Cursor | Copy `octo-cluster.code-workspace.example` → `octo-cluster.code-workspace` (or run `.\install.ps1`) |

After install: `gh auth login` (once). Verify: `.\scripts\productivity-audit.ps1`

## Workspace

`octo-cluster.code-workspace` — single-root with the CORE harness (seeded from `.example`; gitignored).

Optional: add sibling folders (your app, local gitignored vault) in your local workspace copy.

Terminal env:

- `AI_EXECUTION_CONTEXT=platform`
- `OCTO_CLUSTER` → clone root

## CORE loop (optional)

```text
/start-workspace → /scan 8CL-xxx description → /model → Execute plan → /ship → /close
```

| Phase | Harness |
|-------|---------|
| start-workspace | `invoke-pipeline -Pipeline start-workspace -Action run` |
| scan | bootstrap + `current_task.md` (≤200 tokens) |
| model | Plan without code; Execute only planned files |
| ship | verify (repo-policy) + gates + git policy |
| close | archive + reindex memory |

**Discover (once per thread):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))\octo.ps1" -Pipeline scan -Action discover
```

## Issue tracker (Linear)

Primary tracker: [Linear `octo-cluster`](https://linear.app/octo-cluster) (`8CL-xxx`).

Platform context: `/scan` does **not** create issues — pass the ID (`/scan 8CL-123 description`). Use Linear MCP or UI to read/update issues.

Branch pattern: `feat/8CL-123-short-description` — see [EOS](../governance/eos.md).

Private capability packs may add routing — see [add-child-context.md](./add-child-context.md).

## Token economy (COST 0 first)

```text
[COST 0]  hooks, sync, git, gh, bun test, LanceDB, grep, gate scripts
[COST LOW] Ask mode, scoped review
[COST HIGH] Plan + Execute, /ship when reproduction is hard
```

CORE rules:

- 1 chat = 1 work item
- `@` ≤ 3 · Read ≤ 300 lines
- grep before broad Glob/Read
- **caveman** lite on status (off on `/model`, `/ship`, security)
- **ponytail-lite** minimal implementation ladder

**Measure improvement:** [`eval/metrics/README.md`](../../eval/metrics/README.md) · [`metrics-kernel.md`](../architecture/metrics-kernel.md)

## Harness level (platform)

| Layer | Status |
|-------|--------|
| install + audit | OK |
| invoke-pipeline + capabilities | OK |
| repo-policies verify | OK |
| LanceDB memory + code (cap 80) | OK |
| Cursor hooks | **empty** (platform) |

## Cursor hooks

Platform: `domains/core/hooks/hooks.platform.json` → `{}` (no Write block).

Child domains merge hooks via `sync-cursor.ps1 -Domain <pack>`.

If Write is blocked: `.\scripts\sync-cursor.ps1` + `.\scripts\validate-cursor-hooks.ps1`

## Recommended extensions

PowerShell · YAML — see `octo-cluster.code-workspace`

## Next step

Scaffold your capability pack: [add-child-context.md](./add-child-context.md)

Linear workspace setup: [linear-workspace-setup.md](../governance/linear-workspace-setup.md)
