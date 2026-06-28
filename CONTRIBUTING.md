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

1. One concern per PR when possible.
2. Run local verify before opening:
   - `bun run validate octo-cluster` (context-engine)
   - `.\scripts\productivity-audit.ps1` (optional smoke)
3. Do not commit secrets, `.env`, or `state/memory/` contents.
4. Edit **source** under `domains/` / `capabilities/` — not generated `.cursor/` (sync regenerates it).

## Code style

- **Scripts:** PowerShell 5.1+; prefer existing helpers in `scripts/_env.ps1`.
- **Context engine:** Bun/TypeScript; match surrounding patterns.
- **Docs:** English in root README; PT docs under `docs/` are fine.

## Issues

Use GitHub Issues for bugs and harness ideas. Include OS, IDE adapter (e.g. Cursor), and the output of `invoke-pipeline … -Action discover` when relevant.

## Security

See [SECURITY.md](./SECURITY.md) — do not open public issues for undisclosed vulnerabilities.
