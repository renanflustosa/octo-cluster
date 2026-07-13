# Context model — execution context and capability packs

`octo-cluster` uses a **core + capability packs** layout. The core (`domains/core/`) holds universal productivity assets. Capability packs (`capabilities/<pack>/`, optional `domains/<name>/`) extend the core with project-specific behavior.

---

## Layers

| Layer | Path | Role |
|-------|------|------|
| **Core** | `domains/core/` | Rules, skills, commands usable in any workspace |
| **Capability packs** | `capabilities/core/`, `capabilities/my-company/`, … | Pipeline manifests + providers |
| **Legacy child** | `domains/my-company/`, … | Domain rules, hooks, pack scripts |
| **Execution context** | `contexts/runtime/*.json` | Enabled packs, memory profile, repo ownership |
| **Generated** | `.cursor/` | IDE output — **never edit by hand** |
| **Shared infra** | `engine/`, `state/`, `scripts/` | Context-engine, memory, sync |

---

## Merge rules (sync)

1. **Commands:** core-only → `domains/core/commands/` → `.cursor/commands/`
2. **Skills:** core-only → `domains/core/skills/` → `.cursor/skills/`
3. **Rules + hooks:** core + active child domain
4. **Pack skills:** runtime via `invoke-pipeline.ps1 -Action discover` (`PIPELINE_SKILL`)
5. After editing `domains/` or `capabilities/` → [`sync-cursor.ps1`](../scripts/sync-cursor.ps1)

---

## Active execution context

| Mechanism | Detail |
|-----------|--------|
| **Primary** | `AI_EXECUTION_CONTEXT` in workspace file |
| **Default** | `platform` when unset |
| **Override** | `.\scripts\sync-cursor.ps1 -Domain my-company` (rules/hooks) |
| **Manifest** | `.cursor/domain.manifest.json` |

Context files: `contexts/runtime/platform.json`, `contexts/runtime/my-company.json`, …

---

## Pipeline dispatch

[`scripts/invoke-pipeline.ps1`](../scripts/invoke-pipeline.ps1):

```text
invoke-pipeline.ps1 -Pipeline scan|model|ship|... -Action discover|run
  → PIPELINE_SKILL
  → providers via discover-capabilities.ps1
```

---

## Related docs

- [`add-child-context.md`](./add-child-context.md)
- [`productivity-tools.md`](./productivity-tools.md)
