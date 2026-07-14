# Onboarding — octo-cluster (platform)

Full setup guide. Quick start: [README.md](../../README.md).

Read [EOS](../governance/eos.md) for project conventions.

## Portability

| Supported | Not supported |
|-----------|---------------|
| Linux (Ubuntu 24.04 official), macOS, Windows | iOS / mobile CLI harness |
| Native bootstrap via `install.ps1` / `install.sh` | Rewriting harness in bash |
| Dev Container (optional future) | |

Harness orchestration runs on **PowerShell 7 (`pwsh`)** everywhere. Context engine runs on **Bun**. Bash shims (`scripts/octo`) are optional ergonomics only.

## Native bootstrap (canonical)

### Prerequisites

| Item | How |
|------|-----|
| Git | [git-scm.com](https://git-scm.com/downloads) |
| PowerShell 7 | [PowerShell releases](https://github.com/PowerShell/PowerShell/releases) |
| Bun | [bun.sh](https://bun.sh) |
| GitHub CLI (optional, for `/ship`) | [cli.github.com](https://cli.github.com/) |

### First setup

```bash
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
```

**Windows:** `pwsh -File install.ps1`  
**Linux/macOS:** `chmod +x install.sh scripts/octo scripts/octo-domain && ./install.sh`

Then:

```powershell
pwsh scripts/sync-cursor.ps1
cd engine/context-engine && bun install && bun run validate octo-cluster
pwsh scripts/productivity-audit.ps1
```

Optional: `gh auth login` once for PR flow in `/ship`.

Expected audit: `[READY]` with optional `gh auth` WARN until you log in.

### Environment

Set in install scripts or your IDE workspace:

- `OCTO_CLUSTER` → clone root
- `AI_EXECUTION_CONTEXT=platform`

| Task | Command |
|------|---------|
| Pipeline discover | `pwsh octo.ps1 -Pipeline scan -Action discover` |
| Start workspace | `pwsh octo.ps1 -Pipeline start-workspace -Action run` |
| Validate harness | `cd engine/context-engine && bun run validate octo-cluster` |
| Sync adapter after editing `domains/` | `pwsh scripts/sync-cursor.ps1` |
| Health check | `pwsh scripts/productivity-audit.ps1` |

Optional: add this clone as a root in your consumer-managed IDE workspace (local vault, product repos, etc.).

## Dev Container (optional future)

Not shipped in this repo yet. Use native bootstrap above. See [oss-workstation-setup.md](./oss-workstation-setup.md) for a manual Ubuntu workstation path.

```bash
# Ubuntu example — see docs/guides/oss-workstation-setup.md
sudo apt install -y git curl ripgrep
# pwsh: https://learn.microsoft.com/powershell/scripting/install/install-ubuntu
# bun: curl -fsSL https://bun.sh/install | bash
# gh: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
chmod +x install.sh scripts/octo scripts/octo-domain
./install.sh
export OCTO_CLUSTER="$(pwd)"   # add to ~/.bashrc for persistence
./scripts/octo -Pipeline scan -Action discover
```

## Workspace

IDE workspace files (`.code-workspace`) are **consumer-managed** — outside this repository. Set `OCTO_CLUSTER` and `AI_EXECUTION_CONTEXT` in `terminal.integrated.env.windows` when opening integrated terminals.

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
| install bootstrap + audit | OK |
| invoke-pipeline + capabilities | OK |
| repo-policies verify | OK |
| LanceDB memory + code (cap 80) | OK |
| Cursor hooks | **empty** (platform) |

## Cursor hooks

Platform: `domains/core/hooks/hooks.platform.json` → `{}` (no Write block).

Child domains merge hooks via `sync-cursor.ps1 -Domain <pack>`.

If Write is blocked: `pwsh scripts/sync-cursor.ps1` + `pwsh scripts/validate-cursor-hooks.ps1`

## Recommended extensions

PowerShell · YAML — see [`.vscode/extensions.json`](../../.vscode/extensions.json)

## Next step

Scaffold your capability pack: [add-child-context.md](./add-child-context.md)
