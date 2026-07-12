# Capability packs

| Path | Tracked | Purpose |
|------|---------|---------|
| `capabilities/core/` | yes | Public core loop (scan, model, ship, close) |
| `capabilities/_private/<pack>/` | **gitignored** | Consumer-specific pipelines and skills |
| `registry.yaml` | yes | Public packs only (`core`) |
| `registry.local.yaml` | **gitignored** | Merge private pack paths on your machine |

Setup for a private consumer pack:

1. Copy `registry.local.yaml.example` → `registry.local.yaml` and register your pack.
2. Copy `contexts/runtime/consumer-pack.example.json` → `contexts/runtime/<pack-id>.local.json` and adjust env vars.
3. Scaffold `capabilities/_private/<pack>/` and `domains/_private/<pack>/` locally — see [add-child-context.md](../docs/guides/add-child-context.md).
4. Run `sync-cursor.ps1 -Domain <pack>` — do **not** commit generated `.cursor/` child rules to the public repo.

**Ship auto-close (optional):** enable `git.auto_close_after_ship` in repo policy; add a private pack provider with `phase: close` on the ship pipeline (e.g. mark tracker Done). Core runs memory close via `core-close.ps1` after successful git delivery when `CARD:` is set.

Public export (`scripts/export-public.ps1`) and `.gitignore` exclude private overlays by design.
