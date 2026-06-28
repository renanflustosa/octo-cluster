## Summary

<!-- What changed and why (harness / core / docs / pack)? -->

## Test plan

- [ ] `bun run validate octo-cluster` (if context-engine touched)
- [ ] `.\scripts\sync-cursor.ps1` (if domains/ or capabilities/ touched)
- [ ] Other: <!-- gates, productivity-audit, … -->

## Checklist

- [ ] No secrets or employer-specific identifiers in core paths
- [ ] Edited source under `domains/` / `capabilities/`, not hand-edited `.cursor/`
