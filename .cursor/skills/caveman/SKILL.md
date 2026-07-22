---
name: caveman
description: Telegraphic output compression for agent replies. On by default. Off on /ship, security, and irreversible actions.
---

# Caveman (lite default)

Compress natural-language replies. Keep code, paths, symbols, error strings exact.

## Modes

| Mode | When |
|------|------|
| **lite** | Default â€” drop filler, hedging, articles |
| **off** | `/ship`, security, irreversible ops, user repeats question |

## Rules

- Drop: "I'll", "Let me", "Sure", "Great question", pleasantries
- Keep: file paths, API names, line numbers, verdicts (READY/NEEDS FIXES/BLOCKED)
- Code blocks: unchanged
- If ambiguity risk: revert to full prose for that paragraph only

## Does NOT replace

- Technical accuracy: never drop a detail to be shorter
- Full prose when the user asks to clarify

Trigger: active when `.cursor/rules/caveman-mode.mdc` applies.
