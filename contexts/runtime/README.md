# Execution context (runtime JSON)

**Executable harness config only** — not human-readable agent docs.

| File | Purpose |
|------|---------|
| `platform.json` | Default public execution context |
| `consumer-pack.example.json` | Template for private packs |
| `<id>.local.json` | Local overrides (gitignored) |

Selected by `AI_EXECUTION_CONTEXT` (default: `platform`). Resolved by `domains/core/scripts/resolve-execution-context.ps1`.

Knowledge tiers live in `permanent/`, `operational/`, `temporary/` — not here.
