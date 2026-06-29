# Third-party attributions

Octo Cluster is [MIT licensed](./LICENSE). This file lists external projects that inspired or contributed adapted material. **Original harness code, scripts, and docs not listed here are © Renan Lustosa under MIT.**

When you copy or adapt permissively licensed material, keep the upstream copyright notice and license text with the copy. See each upstream `LICENSE` for full terms.

---

## Adapted agent skills (MIT)

| Octo Cluster path | Relationship | Upstream | License |
|-------------------|--------------|----------|---------|
| [`domains/core/skills/systematic-debugging/`](domains/core/skills/systematic-debugging/) | Adapted — 4-phase root-cause debugging process, supporting techniques (`root-cause-tracing.md`, `defense-in-depth.md`, `condition-based-waiting.md`, examples) | [obra/superpowers](https://github.com/obra/superpowers) — [`skills/systematic-debugging/`](https://github.com/obra/superpowers/tree/main/skills/systematic-debugging) | [MIT](https://github.com/obra/superpowers/blob/main/LICENSE) |
| [`domains/core/skills/ponytail-lite/SKILL.md`](domains/core/skills/ponytail-lite/SKILL.md) | Adapted — minimal implementation ladder (YAGNI / reuse-before-write); not a verbatim copy | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | [MIT](https://github.com/DietrichGebert/ponytail/blob/main/LICENSE) |
| [`domains/core/rules/ponytail-lite.mdc`](domains/core/rules/ponytail-lite.mdc) | Companion rule for `ponytail-lite` skill | Same as above | MIT |

**Note:** `systematic-debugging` still references upstream Superpowers skill IDs (`superpowers:test-driven-development`, `superpowers:verification-before-completion`) in prose. Octo Cluster does not bundle those skills; install [Superpowers](https://github.com/obra/superpowers) separately if you want them.

---

## Adapted eval / metrics (MIT)

| Octo Cluster path | Relationship | Upstream | License |
|-------------------|--------------|----------|---------|
| [`eval/agentic/README.md`](eval/agentic/README.md), [`eval/agentic/score-diff.ps1`](eval/agentic/score-diff.ps1) | Inspired — LOC scoring for manual A/B pilots | [ponytail `benchmarks/agentic`](https://github.com/DietrichGebert/ponytail/tree/main/benchmarks/agentic) | MIT |

---

## Concept inspiration (no code copied)

| Idea in Octo Cluster | Reference | Notes |
|----------------------|-----------|-------|
| L0 / L1 / L2 memory tiering & decay (`engine/context-engine/src/memory-compact.ts`) | [volcengine/OpenViking](https://github.com/volcengine/OpenViking) | **Concept only** — DIY markdown tiers in local `state/memory/`; no OpenViking source in this repo. Upstream is [AGPL-3.0](https://github.com/volcengine/OpenViking/blob/main/LICENSE). |

---

## Bundled npm dependencies (`engine/context-engine`)

Installed via `bun install` under `engine/context-engine/node_modules/`. Run `bun pm ls` in that folder for the resolved tree.

| Package | Use | Typical license |
|---------|-----|-----------------|
| [@lancedb/lancedb](https://github.com/lancedb/lance) | Embedded vector store | Apache-2.0 |
| [@xenova/transformers](https://github.com/xenova/transformers.js) | Local embedding model (no API) | Apache-2.0 |

Transitive licenses live in each package’s `node_modules/<pkg>/LICENSE` (or `package.json` `license` field).

---

## Optional harness tools (not shipped)

Referenced in docs, rules, or install scripts; downloaded separately by the user:

| Tool | Link | Role in Octo Cluster |
|------|------|----------------------|
| [Bun](https://bun.sh) | https://bun.sh | Context-engine runtime |
| [GitHub CLI (`gh`)](https://cli.github.com) | https://github.com/cli/cli | PR flow in `/ship` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | https://github.com/BurntSushi/ripgrep | Grep-first token economy |
| [Promptfoo](https://github.com/promptfoo/promptfoo) | https://github.com/promptfoo/promptfoo | Optional eval gate (`eval/promptfoo/`) |
| [Ollama](https://ollama.com) | https://github.com/ollama/ollama | Optional local models (pack policy) |
| [Cursor](https://cursor.com) | — | IDE adapter target (`.cursor/` generated from `domains/`) |

---

## Original Octo Cluster components

Not derived from the projects above (unless noted):

- `domains/core/skills/` — `caveman`, `core-adaptive-loop`, `core-ship`, `minimal-review`, `find-skills`, `code-review`, `simplify` (original or Cursor-ecosystem patterns without upstream copy in repo)
- `engine/context-engine/` — LanceDB + FTS hybrid indexer/search (original TypeScript)
- `scripts/`, `capabilities/`, `repo-policies/`, `eval/metrics/` (except agentic scoring noted above)

If you believe an attribution is missing, open an issue or PR.
