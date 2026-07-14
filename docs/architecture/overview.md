# Architecture — tool-agnostic AI workspace

This repository is a **tool-agnostic AI workspace platform** with a Cursor adapter today.

## Principles

- `domains/core/` is the generic harness source of truth.
- `capabilities/` holds pack-specific pipeline manifests, providers, and skills.
- `contexts/` selects which packs apply (repo ownership, memory profile, docs root).
- `domains/<pack>/` holds legacy overlays: rules, hooks, scripts, docs.
- `adapters/` translate core + capabilities into tool-specific outputs (future).
- `.cursor/` is synced from `domains/core/` and **committed for convenience** — edit source in `domains/`, then run sync; do not hand-edit rules/skills/commands in `.cursor/`.
- Tool integrations are disposable; core knowledge is permanent.

## Key layers

| Layer | Path | Role |
|-------|------|------|
| **Core** | `domains/core/` | Generic commands, rules, synced skills, harness scripts |
| **Capabilities** | `capabilities/<pack>/` | Pipeline manifests, `skill.md`, ship providers |
| **Contexts** | `contexts/runtime/*.json` | Enabled packs, `ship_repositories`, `docs_root`, `script_prefix` |
| **Child domain** | `domains/<pack>/` | Rules, hooks, pack scripts, docs |
| **Adapter** | `scripts/sync-cursor.ps1` | Generates `.cursor/` (core commands/skills + child rules/hooks) |
| **Tools** | `engine/`, `state/`, `eval/` | Context engine, memory, promptfoo |
| **Generated** | `.cursor/` | Cursor adapter output (committed; synced from core) |

## Runtime dispatch

```text
AI_EXECUTION_CONTEXT → contexts/runtime/<id>.json
  → invoke-pipeline.ps1 -Action discover → PIPELINE_SKILL (capabilities/.../skill.md)
  → invoke-pipeline.ps1 -Action run       → providers (discover-capabilities.ps1)
  → invoke-domain-script.ps1              → domains/<pack>/scripts/<prefix>-*.ps1
```

Use `AI_EXECUTION_CONTEXT` only — older pack-selector env vars are removed by `scripts/migrate-octo-cluster.ps1`.

## Adapter strategy

- Each adapter must be isolated.
- Adapters do not contain business knowledge.
- Core and capability assets remain reusable across all tools.
- `.cursor/` is the current Cursor adapter output (committed for convenience). Long-term multi-tool target: `generated/<tool>/`.

## Transition status

1. ✅ Core loop commands decoupled (`invoke-pipeline.ps1`)
2. ✅ Capability packs replace hardcoded domain ship discovery
3. ✅ Skills: core-only sync; pack skills in `capabilities/`
4. 🔄 `adapters/` directory for explicit multi-tool generation
5. 🔄 Full doc migration off legacy pack-selector env vars

## Portability contract

**Supported:** desktop OS (Linux Ubuntu 24.04 official, macOS, Windows) via native `pwsh` + Bun.

**Canonical setup:** clone repo → `pwsh install.ps1` (Windows) or `./install.sh` (Linux/macOS) → `pwsh scripts/sync-cursor.ps1` → `cd engine/context-engine && bun run validate octo-cluster`.

**Dev Container:** optional future path — not shipped in this repo yet; use native bootstrap above.

**Out of scope:** iOS/mobile CLI harness (git, Docker, LanceDB, hooks require desktop/server).

**Install markers:** repo root contains `install.sh` and/or `install.ps1`; both resolve `OCTO_CLUSTER`.
