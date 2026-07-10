# Agent pre-push checklist

Mandatory short checklist before `git push` or opening a PR. Inspired by OpenSRE `CI.md` brevity — Octo-native commands only.

English-only public tree. Run from repo root with `OCTO_CLUSTER` set.

## Required (every push)

```powershell
# 1) Boundary (consumer names must not enter the public tree)
pwsh scripts/boundary-audit.ps1 -Staged
# Before push (full tree):
pwsh scripts/boundary-audit.ps1

# 2) Cursor hooks still valid JSON / scripts
pwsh scripts/validate-cursor-hooks.ps1

# 3) Productivity harness (COST 0)
pwsh scripts/productivity-audit.ps1
```

If you edited `domains/` or `capabilities/`:

```powershell
pwsh scripts/sync-cursor.ps1
```

If you touched `engine/context-engine` or runtime contexts:

```powershell
cd engine/context-engine
bun run validate octo-cluster
```

## Before `/ship` or PR

- [ ] Conventional Commit message
- [ ] Linked issue / ticket id in branch or PR body
- [ ] No secrets, tokens, or consumer-specific names in tracked files
- [ ] Ship gates green (repo-verify / promptfoo as configured)

## Do not

- Bypass git hooks (`--no-verify`) unless explicitly approved
- Enable OKF `sessionStart` hooks without revisiting [ADR-005](../adr/ADR-005-okf-session-index.md)
- Hand-edit generated `.cursor/` as source of truth

## Related

- [V1 harness readiness](../guides/v1-harness-readiness.md)
- [public-framework-boundary.md](../guides/public-framework-boundary.md)
- [EOS](./eos.md)
