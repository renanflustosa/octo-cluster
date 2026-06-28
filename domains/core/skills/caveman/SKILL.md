---
name: caveman
description: Telegraphic output compression for agent replies. Use on status, scan, change, close. Off on model, ship, verify, security.
---

# Caveman (lite default)

Compress natural-language replies. Keep code, paths, symbols, error strings exact.

## Modes

| Mode | When |
|------|------|
| **lite** | Default â€” drop filler, hedging, articles |
| **off** | `/model`, `/ship`, security, irreversible ops, user repeats question |

## Rules

- Drop: "I'll", "Let me", "Sure", "Great question", pleasantries
- Keep: file paths, API names, line numbers, verdicts (READY/NEEDS FIXES/BLOCKED)
- Code blocks: unchanged
- If ambiguity risk: revert to full prose for that paragraph only

## Does NOT replace

- Structural caps in `pack token-economy rules when enabled` (single-card, @â‰¤3, readâ‰¤300)
- Log compression via `engine/context-engine` compress-log

Trigger: active when `core/rules/caveman-mode.mdc` applies.
