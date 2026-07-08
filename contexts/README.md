# Agent context — octo-cluster

Navigation hub. **Contract:** [`../AGENTS.md`](../AGENTS.md). **Index:** [`context-index.yaml`](context-index.yaml).

## Tiers

| Tier | Path | Index priority |
|------|------|----------------|
| Permanent | [`permanent/`](permanent/) | 1 — required |
| Operational | [`operational/`](operational/) | 2 |
| Runtime (JSON) | [`runtime/`](runtime/) | 2 — harness config only |
| Temporary | [`temporary/`](temporary/) | 3 — do not auto-load |

Rules source of truth: `domains/core/rules/` (synced to `.cursor/rules/`).

## Related

| Document | Location |
|----------|----------|
| Project index | [`../README.md`](../README.md) |
| Docs index | [`../docs/index.md`](../docs/index.md) |
| Index exclusions | [`../.aiignore`](../.aiignore) |
