# Memory relationship provenance

Lightweight convention for labeling **how** a relationship between two concepts was established in agent memory or context notes. Inspired by Graphify edge confidence ([graphify-analysis](./graphify-analysis.md)); **no graph store required**.

Related: [add-child-context](./add-child-context.md) §6, [eval/README](../../eval/README.md), [ADR-005](../adr/ADR-005-okf-session-index.md).

## Purpose

Agents and maintainers often link files, modules, or facts in `state/memory/<profile>/` or profile `context/*.md`. Provenance labels make it clear whether a link is explicit in source, deduced from evidence, or uncertain. This complements LanceDB chunk retrieval — it does not replace semantic search.

## Labels

| Label | Meaning | Use when |
|-------|---------|----------|
| **EXTRACTED** | Relationship is explicitly stated in source | Import, call, config reference, documented dependency, quoted line |
| **INFERRED** | Reasonable deduction from evidence | grep/LanceDB hit chain, naming convention, phase-loop ordering, single-hop call graph |
| **AMBIGUOUS** | Uncertain; needs human review | Cross-repo guess, stale memory, conflicting search results, indirect coupling |

## Syntax

In markdown memory or context files, tag the relationship inline or on the line below:

```markdown
core-context-search → engine/context-engine (EXTRACTED: import in core-context-search.ps1)
scan-bootstrap → invoke-pipeline (INFERRED: both referenced in agent-loop.md)
pack-X ↔ core-Y (AMBIGUOUS: naming similarity only — verify before /ship)
```

Keep labels on relationship lines only. Do not tag every sentence in `current_task.md`.

## Octo examples

1. **EXTRACTED** — `domains/core/scripts/core-scan-bootstrap.ps1` invokes `invoke-pipeline.ps1` because the script file contains `&` or dot-source to that path.
2. **INFERRED** — `context-search` depends on LanceDB because `harness-catalog.yaml` lists both under search/ctx classes and `engine/context-engine/README.md` describes the vector store.
3. **AMBIGUOUS** — A capability pack "might" share code with core because both mention "scan" in filenames; grep did not show a direct import.

## Rules for agents

1. Prefer **EXTRACTED** when you can cite a file path and symbol (grep/read-gate).
2. Use **INFERRED** for evidence chains; note the tool used (grep, context-search, LanceDB).
3. Use **AMBIGUOUS** when acting would be risky (ship, refactor, delete); ask or narrow scope.
4. Do not upgrade INFERRED to EXTRACTED without reading the source file.
5. LanceDB hits are retrieval evidence, not provenance — still label the *relationship* you infer from chunks.

## What this is not

- Not a graph database, MCP tool, or LanceDB schema change
- Not required on every memory file — use when documenting non-obvious dependencies or cross-module links
- Not a substitute for boundary-audit or read-gate before edits

## Validation

```powershell
Test-Path docs/guides/memory-provenance.md
pwsh scripts/boundary-audit.ps1
```
