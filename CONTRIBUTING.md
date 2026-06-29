# Contributing to Octo Cluster

Thanks for helping make the harness better for everyone.

## What belongs in the public repo

| ✅ Core repo | ❌ Keep in your fork / private pack |
|-------------|-------------------------------------|
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

## Pull requests

1. **Target branch:** `develop` for features and fixes; `main` only for release merges from `develop`.
2. **Title:** [Conventional Commits](https://www.conventionalcommits.org/) in English — e.g. `feat:`, `fix:`, `docs:`, `chore:`.
3. One concern per PR when possible.
4. Run local verify before opening:
   - `bun run validate octo-cluster` (context-engine)
   - `.\scripts\productivity-audit.ps1` (optional smoke)
5. Do not commit secrets, `.env`, or `state/memory/` contents.
6. Edit **source** under `domains/` / `capabilities/` — not generated `.cursor/` (run `.\scripts\sync-cursor.ps1` after domain edits).
7. Adapted skills must stay attributed — see [THIRD_PARTY.md](./THIRD_PARTY.md).

## Commits and releases

- **Commits:** short Conventional Commits in English (`fix: null-safe exit codes`).
- **CHANGELOG:** [Keep a Changelog](https://keepachangelog.com/) in [CHANGELOG.md](./CHANGELOG.md); release-please updates it on `main`.
- **Branches:** `develop` = integration; `main` = stable tags (`v0.x.x`) via PR only.
- **Roadmap:** [ROADMAP.md](./ROADMAP.md) for planned work — do not overclaim in README.

## Code style

- **Scripts:** PowerShell 5.1+; prefer existing helpers in `scripts/_env.ps1`.
- **Context engine:** Bun/TypeScript; match surrounding patterns.
- **Docs:** English in root README; PT docs under `docs/` are fine.

## Issues

Use GitHub Issues for bugs and harness ideas. Include OS, IDE adapter (e.g. Cursor), and the output of `invoke-pipeline … -Action discover` when relevant.

## Security

See [SECURITY.md](./SECURITY.md) — do not open public issues for undisclosed vulnerabilities.
