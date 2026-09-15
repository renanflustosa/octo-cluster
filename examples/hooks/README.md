# Optional hooks (not enabled by default)

These examples are **not** loaded until you register them in your tool's hook config.

## Secret-scan hook

Blocks shell commands that would commit or print likely secret files (`.env`, credentials JSON). One script, two protocols:

| Tool | Event | Register |
| --- | --- | --- |
| Cursor ([Agent Hooks](https://cursor.com/docs/agent/hooks)) | `beforeShellExecution` | `Copy-Item examples/hooks/hooks.secret-scan.example.json .cursor/hooks.json` |
| Claude Code ([Hooks](https://code.claude.com/docs/en/hooks)) | `PreToolUse` (Bash, PowerShell) | Merge [claude-settings.secret-scan.example.json](claude-settings.secret-scan.example.json) into `.claude/settings.json` (or `settings.local.json`) |

Or merge the `hooks` entry into your existing config.

In Claude Code the script stays silent on allowed commands, so normal permission prompts still apply.

### Files

| File | Purpose |
| --- | --- |
| [hooks.secret-scan.example.json](hooks.secret-scan.example.json) | Cursor registration |
| [claude-settings.secret-scan.example.json](claude-settings.secret-scan.example.json) | Claude Code registration |
| [secret-scan-hook.ps1](secret-scan-hook.ps1) | stdin/stdout JSON handler |

### Test locally

```powershell
'{"command":"git add .env"}' | pwsh -NoProfile -File examples/hooks/secret-scan-hook.ps1
'{"hook_event_name":"PreToolUse","tool_input":{"command":"cat .env"}}' | pwsh -NoProfile -File examples/hooks/secret-scan-hook.ps1
# Expect: deny response on stdout for both
```

## Consumer boundary overlay

For public frameworks, keep real client/product names out of tracked files:

1. Copy [../boundary-patterns.example.yaml](../boundary-patterns.example.yaml) to `boundary-patterns.local.yaml` (gitignored).
2. Add regex patterns for names that must never appear in public git.
3. Run `pwsh -File scripts/boundary-audit.ps1` before ship.

Use a **private multi-root workspace folder** (Cursor) or hub folder (Claude Code) for consumer-specific rules — never commit consumer identifiers to this public repo.

## Subagents (optional)

Cursor may support `.cursor/agents/`; Claude Code supports `.claude/agents/`. Not bundled here — see [INSPIRATIONS.md](../INSPIRATIONS.md).
