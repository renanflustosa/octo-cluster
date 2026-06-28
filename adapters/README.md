# Adapters

This directory holds tool-specific adapter scaffolding.

Each adapter should:

- consume `domains/core/`
- consume `domains/<active-domain>/`
- generate artifacts into `generated/<tool>/`
- avoid business knowledge
- isolate tool-specific mappings and templates

Initial adapters:

- `cursor/`
- `claude-code/`
- `roo-code/`
- `windsurf/`
- `cline/`
- `continue/`
- `aider/`
