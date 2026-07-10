# Third-Party Notices

Octo Cluster is licensed under the [MIT License](LICENSE) © Renan Lustosa.

This file lists external projects that contributed **adapted code or skills**, **concept inspiration**, or **runtime dependencies**. When in doubt, prefer the upstream license text.

---

## Adapted skills and eval (MIT — retain copyright notice)

| Asset | Upstream | License | Local path |
|-------|----------|---------|------------|
| **systematic-debugging** (SKILL + supporting docs: root-cause-tracing, defense-in-depth, condition-based-waiting, tests) | [obra/superpowers](https://github.com/obra/superpowers) | [MIT](https://github.com/obra/superpowers/blob/main/LICENSE) | [`domains/core/skills/systematic-debugging/`](domains/core/skills/systematic-debugging/) |
| **ponytail-lite** (minimal implementation ladder) | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | [MIT](https://github.com/DietrichGebert/ponytail/blob/main/LICENSE) | [`domains/core/skills/ponytail-lite/`](domains/core/skills/ponytail-lite/) |
| **agentic eval** (LOC scoring pattern, manual A/B protocol) | [ponytail benchmarks/agentic](https://github.com/DietrichGebert/ponytail/blob/main/benchmarks/agentic/README.md) | [MIT](https://github.com/DietrichGebert/ponytail/blob/main/LICENSE) | [`eval/agentic/`](eval/agentic/) |

---

## Concept-inspired (no substantial code copy)

| Idea | Reference | Local note |
|------|-----------|------------|
| L0/L1/L2 memory tiering | [OpenViking](https://github.com/OpenViking/OpenViking) | DIY implementation in [`engine/context-engine/src/memory-compact.ts`](engine/context-engine/src/memory-compact.ts) |

---

## Runtime dependencies (npm)

Bundled via `engine/context-engine/package.json`. See upstream licenses for full text.

| Package | SPDX | Used for |
|---------|------|----------|
| [`@lancedb/lancedb`](https://www.npmjs.com/package/@lancedb/lancedb) | Apache-2.0 | Embedded vector store |
| [`@xenova/transformers`](https://www.npmjs.com/package/@xenova/transformers) | Apache-2.0 | Local embeddings |

---

## Integrated tools (not bundled)

These are **external CLI/runtime dependencies** of the harness, not derived source code:

| Tool | Role |
|------|------|
| [Cursor](https://cursor.com/) | Primary IDE adapter today (`scripts/sync-cursor.ps1`) |
| [Bun](https://bun.sh/) | Context-engine runtime |
| [GitHub CLI (`gh`)](https://cli.github.com/) | PR and release flow in `/ship` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Grep-first token economy |
| [LanceDB](https://lancedb.com/) | Vector search (via npm package) |
| [Promptfoo](https://www.promptfoo.dev/) | Optional eval gate |
| [Ollama](https://ollama.com/) | Optional local LLM (install helper only) |

---

## Original Octo Cluster assets

| Asset | Path | License |
|-------|------|---------|
| Brand logos and icons | [`assets/branding/`](assets/branding/) | MIT (same as project) |

The following are original work © Renan Lustosa under the project MIT license, unless noted above:

- Skills: `caveman`, `core-adaptive-loop`, `core-ship`, `code-review`, `systematic-debugging`, `ponytail-lite`
- Rules, commands, and harness scripts under `domains/core/`, `scripts/`, `capabilities/core/`
- Context engine (`engine/context-engine/`) — original TypeScript; uses npm deps listed above
- Ship pipeline, repo policies, metrics scaffold (`eval/metrics/`)
