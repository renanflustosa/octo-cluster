# Architecture — tool-agnostic AI workspace

This repository is a **tool-agnostic AI workspace platform** with a Cursor adapter today.

## Principles

- `domains/core/` is the generic harness source of truth.
- `capabilities/` holds pack-specific pipeline manifests, providers, and skills.
- `contexts/` selects which packs apply (repo ownership, memory profile, docs root).
- `domains/<pack>/` holds legacy overlays: rules, hooks, scripts, docs.
- `adapters/` translate core + capabilities into tool-specific outputs (future).
- `.cursor/` is generated; never edit by hand.
- Tool integrations are disposable; core knowledge is permanent.

## Key layers

| Layer | Path | Role |
|-------|------|------|
| **Core** | `domains/core/` | Generic commands, rules, synced skills, harness scripts |
| **Capabilities** | `capabilities/<pack>/` | Pipeline manifests, `skill.md`, ship providers |
| **Contexts** | `contexts/*.json` | Enabled packs, `ship_repositories`, `docs_root`, `script_prefix` |
| **Child domain** | `domains/<pack>/` | Rules, hooks, pack scripts, docs |
| **Adapter** | `scripts/sync-cursor.ps1` | Generates `.cursor/` (core commands/skills + child rules/hooks) |
| **Tools** | `engine/`, `state/`, `eval/` | Context engine, memory, promptfoo |
| **Generated** | `.cursor/`, `generated/` | Tool-facing artifacts |

## Runtime dispatch

```text
AI_EXECUTION_CONTEXT → contexts/<id>.json
  → invoke-pipeline.ps1 -Action discover → PIPELINE_SKILL (capabilities/.../skill.md)
  → invoke-pipeline.ps1 -Action run       → providers (discover-capabilities.ps1)
  → invoke-domain-script.ps1              → domains/<pack>/scripts/<prefix>-*.ps1
```

Use `AI_EXECUTION_CONTEXT` only — older pack-selector env vars are removed by `scripts/migrate-octo-cluster.ps1`.

## Adapter strategy

- Each adapter must be isolated.
- Adapters do not contain business knowledge.
- Core and capability assets remain reusable across all tools.
- `.cursor/` is the current Cursor adapter output; `generated/` is the explicit target for multi-tool sync.

## Transition status

1. ✅ Core loop commands decoupled (`invoke-pipeline.ps1`)
2. ✅ Capability packs replace hardcoded domain ship discovery
3. ✅ Skills: core-only sync; pack skills in `capabilities/`
4. 🔄 `adapters/` directory for explicit multi-tool generation
5. 🔄 Full doc migration off legacy pack-selector env vars
