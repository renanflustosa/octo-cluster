# Optional hooks (not enabled by default)

These examples are **not** loaded until you copy them into `.cursor/hooks.json` at the repo root (or merge with your existing hooks).

Requires Cursor with [Agent Hooks](https://cursor.com/docs/agent/hooks) support.

## Secret-scan hook (`beforeShellExecution`)

Blocks shell commands that would commit or print likely secret files (`.env`, credentials JSON).

### Install

```powershell
Copy-Item examples/hooks/hooks.secret-scan.example.json .cursor/hooks.json
```

Or merge the `hooks` entry from that file into your existing `.cursor/hooks.json`.

### Files

| File | Purpose |
| --- | --- |
| [hooks.secret-scan.example.json](hooks.secret-scan.example.json) | Hook registration |
| [secret-scan-hook.ps1](secret-scan-hook.ps1) | stdin/stdout JSON handler |

### Test locally

```powershell
'{"command":"git add .env"}' | pwsh -NoProfile -File examples/hooks/secret-scan-hook.ps1
# Expect: deny or block response on stdout (see hook script)
```

## Consumer boundary overlay

For public frameworks, keep real client/product names out of tracked files:

1. Copy [../boundary-patterns.example.yaml](../boundary-patterns.example.yaml) to `boundary-patterns.local.yaml` (gitignored).
2. Add regex patterns for names that must never appear in public git.
3. Run `pwsh -File scripts/boundary-audit.ps1` before ship.

Use a **private multi-root workspace folder** for consumer-specific rules — never commit consumer identifiers to this public repo.

## Subagents (optional)

Cursor **nightly** may support `.cursor/agents/` for isolated sub-tasks. Not bundled here — see [INSPIRATIONS.md](../INSPIRATIONS.md) and Cursor docs for your channel.
