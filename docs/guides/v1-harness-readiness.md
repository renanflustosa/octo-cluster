# V1 harness readiness (Win11 + Cursor)

Operational certainty checklist for Octo Cluster V1: **maximize harness quality** and **minimize token cost** in the Win11 + Cursor scope. Scorecard: [ADR-006](../adr/ADR-006-harness-tool-cluster.md).

Related: [harness-tool-cluster.md](./harness-tool-cluster.md), [agent-pre-push.md](../governance/agent-pre-push.md), [ADR-005](../adr/ADR-005-okf-session-index.md) (OKF sessionStart deferred).

## Quick validate

```powershell
pwsh scripts/productivity-audit.ps1 -Workstation
pwsh eval/metrics/report.ps1 -CompareCombinations -Last 5
pwsh scripts/boundary-audit.ps1
```

Statuses: **OK** (automated green) · **WARN** (manual or optional) · **GAP** (must fix for V1 confidence).

## Config stack (high → low)

| # | Layer | Expected | How to verify |
|---|-------|----------|---------------|
| 1 | OS / tools / env | OK | `productivity-audit.ps1 -Workstation` — git, pwsh 7+, Bun, Python, ripgrep, `OCTO_CLUSTER`, `AI_EXECUTION_CONTEXT=platform` |
| 2 | Workspace folders | WARN | Multi-root: octo-cluster ± private vault. Never index or commit `secrets/`. Workspace files are consumer-managed (outside this repo) |
| 3 | Cursor settings | WARN | User/workspace: project hooks enabled; do not disable `.cursor/hooks.json`. Avoid token-heavy always-on features without bakeoff evidence |
| 4 | Extensions | OK | [`.vscode/extensions.json`](../../.vscode/extensions.json) — PowerShell + YAML only (keep noise low) |
| 5 | MCP servers | WARN | Local Cursor MCP config (not in public tree). Enable only needed servers; auth OK; no secrets in prompts. Private trackers via pack/MCP, not core |
| 6 | Hooks | OK | Platform hooks empty by design (`hooks.platform.json` → `{}`). `validate-cursor-hooks.ps1` must pass. **Do not** enable OKF `sessionStart` injection (ADR-005) |
| 7 | Rules / skills / commands | OK | Edit `domains/core/`, then `pwsh scripts/sync-cursor.ps1`. Do not hand-edit generated `.cursor/` as source of truth |
| 8 | Runtime JSON | OK | [`contexts/runtime/platform.json`](../../contexts/runtime/platform.json) has `combination_id` + `harness_tools`. Overrides: `platform.local.json` (gitignored) |
| 9 | Memory / RAG | OK | Audit `context_engine` + `memory_index`. Reindex: `bun run index-incremental octo-cluster --kind memory` from `engine/context-engine` |
| 10 | Eval / metrics | OK | `/scan` stamps usage baseline; `/close` prints `combination_id` + `harness_score`; rank with `report.ps1 -CompareCombinations` |

## What V1 optimizes

| Maximize harness | Minimize tokens |
|------------------|-----------------|
| Phase loop, gates, boundary-audit | caveman + ponytail-lite |
| LanceDB + read-gate / grep-first | Card-lite + combination bakeoff |
| Agent pre-push checklist | Empty session hooks (no fragile inject) |

## Out of scope (V1)

- Porting OpenSRE or mega-brain runtimes
- OKF `sessionStart` as default
- Full Claude/Ubuntu adapter (stub only under `adapters/claude/`)
- Enforcing every `harness_tools` toggle in code (V1.1)

## After green audit

1. Run cards with labeled `combination_id` ([bakeoff protocol](../../eval/agentic/protocol/combination-bakeoff.md)).
2. Promote winners into runtime defaults only with evidence.
3. Follow [agent-pre-push.md](../governance/agent-pre-push.md) before every push.
