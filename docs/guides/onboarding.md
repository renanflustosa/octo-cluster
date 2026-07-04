# Onboarding — octo-cluster (platform)

Full setup guide. Quick start: [README.md](../../README.md).

Read [EOS](../governance/eos.md) for project conventions.

## Dev Container (all platforms)

One path for **Windows, macOS, and Linux**: Docker on the host, Ubuntu inside the container.

### Host prerequisites

| Item | How |
|------|-----|
| Git | [git-scm.com](https://git-scm.com/downloads) |
| Docker | [Docker Desktop](https://docs.docker.com/desktop/) (Windows/macOS) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux) |
| Cursor or VS Code | [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) |

### First open

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
```

1. Open the folder in Cursor.
2. Command palette → **Dev Containers: Reopen in Container** (or accept the prompt).
3. Wait for `.devcontainer/post-create.sh` — installs Bun deps, syncs `.cursor/`, seeds memory, runs `bun run validate octo-cluster`.

After build:

```bash
gh auth login   # once, for PRs and /ship
pwsh scripts/productivity-audit.ps1
```

Expected: `[READY]` with optional `gh auth` WARN until you log in.

### Inside the container

Env is set automatically:

- `OCTO_CLUSTER` → workspace root (`${localWorkspaceFolder}`)
- `AI_EXECUTION_CONTEXT=platform`

| Task | Command |
|------|---------|
| Pipeline discover | `pwsh octo.ps1 -Pipeline scan -Action discover` |
| Start workspace | `pwsh octo.ps1 -Pipeline start-workspace -Action run` |
| Validate harness | `cd engine/context-engine && bun run validate octo-cluster` |
| Sync adapters after editing `domains/` | `pwsh scripts/sync-cursor.ps1` |
| Health check | `pwsh scripts/productivity-audit.ps1` |

Optional: copy `octo-cluster.code-workspace.example` → `octo-cluster.code-workspace` and add sibling folders (your app, local gitignored vault).

## Workspace

`octo-cluster.code-workspace` — single-root with the CORE harness (seeded from `.example`; gitignored).

Optional: add sibling folders (your app, local gitignored vault) in your local workspace copy.

Terminal env (when not using Dev Container — local shell only):

- `AI_EXECUTION_CONTEXT=platform`
- `OCTO_CLUSTER` → clone root

## CORE loop (optional)

```text
/start-workspace → /scan ISSUE-123 description → /model → Execute plan → /ship → /close
```

| Phase | Harness |
|-------|---------|
| start-workspace | `invoke-pipeline -Pipeline start-workspace -Action run` |
| scan | bootstrap + `current_task.md` (≤200 tokens) |
| model | Plan without code; Execute only planned files |
| ship | verify (repo-policy) + gates + git policy |
| close | archive + reindex memory |

**Discover (once per thread):**

```bash
pwsh octo.ps1 -Pipeline scan -Action discover
```

## Issue tracker (GitHub)

Public tracker: [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues).

Platform context: `/scan` does **not** create issues — pass the ID (`/scan ISSUE-123 description`). Use GitHub CLI (`gh issue view`) or the web UI to read/update issues.

Branch pattern: `feat/42-short-description` — see [EOS](../governance/eos.md).

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
| devcontainer bootstrap + audit | OK |
| invoke-pipeline + capabilities | OK |
| repo-policies verify | OK |
| LanceDB memory + code (cap 80) | OK |
| Cursor hooks | **empty** (platform) |

## Cursor hooks

Platform: `domains/core/hooks/hooks.platform.json` → `{}` (no Write block).

Child domains merge hooks via `sync-cursor.ps1 -Domain <pack>`.

If Write is blocked: `pwsh scripts/sync-cursor.ps1` + `pwsh scripts/validate-cursor-hooks.ps1`

## Recommended extensions

PowerShell · YAML — installed via `.devcontainer/devcontainer.json`

## Next step

Scaffold your capability pack: [add-child-context.md](./add-child-context.md)
