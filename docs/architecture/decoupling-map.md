# Decoupling map — core vs capability packs

How the **platform** context stays isolated from optional capability packs.

## Summary

| Area | Platform status |
|------|-----------------|
| Core scripts (`core-*.ps1`) | Agnostic — no pack vocabulary |
| `_env.ps1` | Resolves `OCTO_CLUSTER` only |
| `install.ps1` | Platform onboarding |
| `validate.ts` / code index | Profile `octo-cluster`, scoped cap 80 files |
| `sync-cursor.ps1` | Core commands/skills; optional `-Domain` for child rules/hooks |
| Private pack paths | Not loaded when pack disabled in `contexts/*.json` |

## Capability discovery

| Behavior | Platform | Pack enabled |
|----------|------------|--------------|
| `Get-DiscoveredCapabilities` | Core pack only | + pack when in `enabled_capability_packs` |
| Ship providers | `repo-policy-verify`, `promptfoo-eval` | Pack gates when manifest + ownership match |

## Context-engine

| Component | Platform |
|-----------|----------|
| `collectCodeSources` | Scoped dirs under octo-cluster, max 80 files |
| `validate.ts` default profile | `octo-cluster` |
| `resolveShipRepositoryRoots` | Reads `contexts/platform.json` |

## Repository policies

| File | Platform use |
|------|--------------|
| `default.yaml` | Base merge |
| `octo-cluster.yaml` | Self-verify on ship |
| `openpolvo.yaml` | Optional sample for Go monorepos |

See [`context-model.md`](./context-model.md).
