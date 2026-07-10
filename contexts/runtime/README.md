# Execution context (runtime JSON)

**Executable harness config only** — not human-readable agent docs.

| File | Purpose |
|------|---------|
| `platform.json` | Default public execution context |
| `consumer-pack.example.json` | Template for private packs |
| `<id>.local.json` | Local overrides (gitignored) |

Selected by `AI_EXECUTION_CONTEXT` (default: `platform`). Resolved by `domains/core/scripts/resolve-execution-context.ps1`.

## Harness experiment fields (ADR-006)

| Field | Purpose |
|-------|---------|
| `combination_id` | Bakeoff arm label persisted on metrics cards (e.g. `baseline`, `compress-on`) |
| `harness_tools` | Boolean map of catalog toggles (defaults = current platform behavior) |

See [harness-tool-cluster.md](../guides/harness-tool-cluster.md) and [harness-catalog.yaml](../architecture/harness-catalog.yaml).

Override locally without editing tracked defaults:

```text
contexts/runtime/platform.local.json  # gitignored
```

Knowledge tiers live in `permanent/`, `operational/`, `temporary/` — not here.
