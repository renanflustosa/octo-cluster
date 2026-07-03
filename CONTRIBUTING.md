# Contributing to Octo Cluster

Thanks for helping make the harness better for everyone.

Read the [Engineering Operating System (EOS)](./docs/governance/eos.md) before contributing.

## What belongs in the public repo

| Core repo | Keep in your fork / private pack |
|-----------|----------------------------------|
| `domains/core/` — agnostic rules, skills, scripts | Company-specific repos, credentials, client names |
| `capabilities/core/` — generic providers | Proprietary issue-tracker routing |
| `engine/`, `scripts/`, `eval/` harness | Private `domains/<pack>/` in your fork |
| Docs without employer-specific vocabulary | Internal architecture, prod URLs, secrets |

**Promotion rule:** if two or more packs need the same behavior → open a PR to core. If it names one product or legacy stack → keep it in a capability pack.

## Development setup

```powershell
git clone https://github.com/renanflustosa/octo-cluster.git
cd octo-cluster
.\install.ps1
.\scripts\sync-cursor.ps1   # after editing domains/ or capabilities/
cd engine\context-engine
bun run validate octo-cluster
```

## Public framework boundary (mandatory)

Octo Cluster is a **consumer-agnostic public framework**. Consumer names (clients, products, private repos, vaults, workspaces) are treated like credential leaks and must never appear in tracked files.

Before every commit and push:

```powershell
.\scripts\boundary-audit.ps1          # full tracked scan
.\scripts\boundary-audit.ps1 -Staged  # pre-commit scope
```

Install git hooks (also runs from `install.ps1`):

```powershell
.\scripts\install-git-hooks.ps1
```

Hooks run `boundary-audit` automatically. CI runs the same gate on every PR. See [public-framework-boundary.md](./docs/guides/public-framework-boundary.md).

## Branches

Pattern: `<type>/<issue#>-<short-description>`

```text
feat/42-add-memory-compaction
fix/201-fix-rag-cache
docs/45-update-onboarding
```

Target `develop` for features and fixes; `main` only for release merges from `develop`.

## Pull requests

1. **Title:** [Conventional Commits](https://www.conventionalcommits.org/) in English — e.g. `feat:`, `fix:`, `docs:`.
2. **Related issue:** include `Fixes #NNN` in PR body (see [PR template](./.github/PULL_REQUEST_TEMPLATE.md)).
3. One concern per PR when possible.
4. Run local verify before opening:
   - `bun run validate octo-cluster` (context-engine)
   - `.\scripts\productivity-audit.ps1` (optional smoke)
5. Do not commit secrets, `.env`, or `state/memory/` contents.
6. Edit **source** under `domains/` / `capabilities/` — not generated `.cursor/` (run `.\scripts\sync-cursor.ps1` after domain edits).
7. Adapted skills must stay attributed — see [THIRD_PARTY.md](./THIRD_PARTY.md).

## Commits and releases

- **Commits:** Conventional Commits in English (`fix(memory): null-safe exit codes`).
- **CHANGELOG:** [Keep a Changelog](https://keepachangelog.com/) in [CHANGELOG.md](./CHANGELOG.md); release-please updates it on `main`.
- **Branches:** `develop` = integration; `main` = stable tags (`v0.x.x`) via PR only.
- **Releases:** SemVer 2.0.0 via release-please — see [ADR-002](./docs/adr/ADR-002-adopt-semantic-versioning.md).

## Code style

- **Scripts:** PowerShell 5.1+; prefer existing helpers in `scripts/_env.ps1`.
- **Context engine:** Bun/TypeScript; match surrounding patterns.
- **Docs:** English only in project artifacts.

## Issues

**Public tracker:** [GitHub Issues](https://github.com/renanflustosa/octo-cluster/issues).

Open an issue before large changes when possible. Use [GitHub Milestones](https://github.com/renanflustosa/octo-cluster/milestones) for release planning.

For bugs, use the GitHub bug report template. Include OS, IDE adapter, and `invoke-pipeline … -Action discover` output when relevant.

## Security

See [SECURITY.md](./SECURITY.md) — do not open public issues for undisclosed vulnerabilities.

## Code of conduct

See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).
