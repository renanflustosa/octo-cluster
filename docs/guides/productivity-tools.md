# Productivity tools — agnostic stack

> Local AI development harness — works for any project via capability packs.

## Canonical loop

```text
/scan → /model → Execute plan → /ship → /close
```

Meta: `/prompt` (rewrite only). Also: `/review`, `/debug`.

Full operational contract: [`contexts/operational/agent-loop.md`](../../contexts/operational/agent-loop.md).

## Token cost layers

```text
[COST 0]     hooks, sync, git, gh, bun test, LanceDB search, grep, gate scripts
[COST LOW]   Ask mode, scoped review
[COST HIGH]  Plan + Execute plan, /ship, /debug when reproduction is hard
```

Prefer the cheapest layer that finishes the job.

## Core vs packs

| CORE | Capability pack |
|------|-----------------|
| Agnostic loop + `/debug` `/review` `/prompt` | Repo ownership, issue-tracker routing |
| caveman, ponytail-lite, systematic-debugging | Pack scripts + providers |
| `domains/core/` → sync → `.cursor/` | `capabilities/<pack>/` |

**Promotion rule:** if two or more packs need the same behavior → move it to CORE.

## Sync

Edit source under `domains/core/` and `capabilities/`. Run `pwsh scripts/sync-cursor.ps1`. Do not hand-edit `.cursor/` as source of truth.

## Deeper reference

- [`context-model.md`](./context-model.md)
- [`onboarding.md`](./onboarding.md)
- [`public-framework-boundary.md`](./public-framework-boundary.md)
- [`docs/index.md`](../index.md)
