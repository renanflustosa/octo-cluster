# Octo Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Local, IDE-agnostic harness for AI-assisted development: RAG + memory, token economy, repo-policy delivery, and local verify gates in one workspace folder. Cheap local layers (grep, LanceDB, scripts, gates) run first; the model is used only when judgment is required.

> Cursor is supported today via generated adapters (`.cursor/`). Other IDEs can add a folder adapter the same way.

## Quick start

Prerequisites: [Git](https://git-scm.com/downloads), [PowerShell 7](https://github.com/PowerShell/PowerShell/releases), [Bun](https://bun.sh), and [GitHub CLI](https://cli.github.com/) (`gh`) for `/ship`.

```bash
git clone https://github.com/renanflustosa/octo-cluster.git <clone-root>
cd <clone-root>
```

- **Windows:** `pwsh -File install.ps1`
- **Linux/macOS:** `./install.sh`

Then sync the adapter, validate, and smoke test:

```powershell
pwsh scripts/sync-cursor.ps1
cd engine/context-engine && bun run validate octo-cluster
pwsh octo.ps1 -Pipeline scan -Action discover
```

`install.*` set `OCTO_CLUSTER` to the repo root. Add this folder as a root in your local multi-root workspace (vault, product repos) — never commit workspace files here.

Full setup: [onboarding](./docs/guides/onboarding.md).

## Commands (optional loop)

One chat ≈ one work item. Routine edits need no command.

```text
/scan → /model → Execute → /ship → /close
```

Also available: `/review` (PR review), `/debug` (systematic troubleshooting), `/prompt` (rewrite a prompt without executing it).

## Delivery (`/ship`)

`verify → gate → deliver`, driven by `repo-policies/` — no project vocabulary hardcoded in core. Delivery is script-only (LLM budget = 1, the verdict):

- feature branch → PR against `base_branch` → **auto-merge**; remote branch deleted on merge
- returns after enabling auto-merge; `-WaitForMerge` to block until merge, `-FullVerify` for all policy checks
- ship any repo with `-RepoPath <path>` (policy from its `.octo/repo-policy`); portable via `OCTO_CLUSTER` + `gh auth login` (scopes `repo`, `workflow`)

## Layout

```text
domains/core/   rules, skills, commands, harness scripts (source of truth)
capabilities/   pack manifests + pipeline providers
contexts/       agent context tiers + runtime JSON
engine/         context-engine (Bun + LanceDB)
scripts/        sync, invoke-pipeline, install helpers
.cursor/        synced from domains/core/ — edit domains/, then sync
```

Agents start at [`AGENTS.md`](./AGENTS.md) and [`contexts/context-index.yaml`](./contexts/context-index.yaml).

## More

- Full docs index: [`docs/index.md`](./docs/index.md)
- Governance (EOS): [`docs/governance/eos.md`](./docs/governance/eos.md)
- Contributing + public boundary: [`CONTRIBUTING.md`](./CONTRIBUTING.md)

## License

[MIT](./LICENSE) © Renan Lustosa — see [THIRD_PARTY.md](./THIRD_PARTY.md) for adapted skills and dependencies.
