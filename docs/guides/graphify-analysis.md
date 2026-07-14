# Graphify pattern analysis

Competitive / pattern analysis of [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) (MIT) against Octo Cluster EOS initiatives. Docs-only; no upstream code vendored.

Related: [ADR-005 OKF session index](../adr/ADR-005-okf-session-index.md), [eval/](../../eval/README.md), [tool-impact-protocol](./tool-impact-protocol.md), [opensre-analysis](./opensre-analysis.md), [harness-catalog.yaml](../architecture/harness-catalog.yaml).

## Purpose

Evaluate whether Graphify — a local knowledge-graph builder for code, docs, PDFs, and images — fits Octo Cluster's memory/RAG stack (`engine/context-engine/`, LanceDB, harness search tools) or should remain an external optional tool measured via TIP before any promotion.

## Implementation (analysis method)

1. Read upstream README, [ARCHITECTURE.md](https://github.com/Graphify-Labs/graphify/blob/v8/ARCHITECTURE.md), license, install path, and integration surfaces (Claude Code skill, CLI, `--mcp`, `--wiki`).
2. Cross-check repo authenticity (stars vs commits, org lineage, maintainer activity).
3. Compare to Octo paths: `engine/context-engine/`, `domains/core/scripts/core-context-search.ps1`, `state/memory/`, [eval/README.md](../../eval/README.md), [harness-catalog.yaml](../architecture/harness-catalog.yaml).
4. Score checklist rows and EOS initiatives; draft follow-up issues (titles only).

Snapshot date: 2026-07-14. Upstream default branch: `v8`.

## Usage

Use this guide when deciding whether to pilot Graphify via TIP, borrow patterns (provenance labels, wiki navigation), or reject integration. Do not port Graphify into `domains/core/` without a new ADR and license review.

## Validation

```powershell
Test-Path docs/guides/graphify-analysis.md
# Manual: every checklist row has a verdict; EOS table has 15 rows; >=3 follow-up drafts
pwsh scripts/boundary-audit.ps1
```

## Limitations

- Analysis is pattern-level; no hands-on TIP bakeoff in this card.
- Token-reduction claims (71.5x) are upstream-reported; Octo has not independently verified on octo-cluster corpus.
- Graphify doc/image extraction requires Claude API calls during indexing — cost model differs from LanceDB local embeddings.
- Multimodal and graph-query features are not exercised against Octo profiles in this spike.

---

## Upstream summary

| Attribute | Value |
|-----------|-------|
| License | MIT |
| Runtime | Python 3.10+ (`pip install graphifyy`; PyPI name pending reclaim) |
| Stack | NetworkX, Leiden (graspologic), tree-sitter, Claude (vision for docs/PDFs/images), vis.js |
| Outputs | `graph.json`, `GRAPH_REPORT.md`, interactive HTML, Obsidian vault, optional `--wiki`, `--mcp` stdio server |
| Primary surface | Claude Code `/graphify` skill; CLI usable standalone |
| Indexing model | Extract nodes/edges → build graph → cluster → analyze (god nodes, surprising connections) |
| Query types | `query`, `path`, `explain` — structural/graph traversal, not chunk retrieval |
| Windows | Supported; PATH note for Python Scripts in README |

### Repo authenticity due diligence

| Signal | Observation | Risk |
|--------|---------------|------|
| Stars | ~86k (Jul 2026) | **High suspicion** — disproportionate vs org age and niche scope |
| Org / repo age | Graphify-Labs org; repo created 2026-04-03 | Young; viral growth possible but unverified |
| Commits / activity | Daily commits Jul 2026; issue/PR volume high (~530 open) | **Active codebase** — not a static README project |
| Contributors | Primary: `safishamsi` (~800 commits); small contributor tail | Real maintenance; not anonymous dump |
| Lineage | README CI badge still references `safishamsi/graphify`; canonical repo is `Graphify-Labs/graphify` (same repo ID) | Personal → org migration; not a unrelated fork |
| Security posture | Recent XSS fix in `graph.html`; `security.py` validation module | Treat local HTML reports as untrusted when ingesting hostile corpora |

**Verdict on authenticity:** Codebase and maintenance appear genuine; **star count should not drive adoption decisions**. Prefer TIP evidence and hands-on pilot over social proof.

---

## License posture

| Item | Upstream | Octo Cluster | Note |
|------|----------|--------------|------|
| Repository | MIT | MIT (project) | Compatible for *ideas*; copying code needs attribution in `THIRD_PARTY.md` |
| This analysis | — | Docs only | No code copied → **no** `THIRD_PARTY.md` change |
| Future code adopt | MIT | Must record NOTICE | Gate any paste behind license checklist |

Per-recommendation license: **cite-only** unless marked Adopt with code path (none below require vendoring today).

---

## Analysis checklist

| # | Topic | Upstream signal | Octo target | Verdict | License |
|---|--------|-----------------|-------------|---------|---------|
| 1 | Indexing model (graph vs chunks) | NetworkX graph with EXTRACTED/INFERRED/AMBIGUOUS edge confidence | LanceDB vectors + SQLite FTS hybrid ([`search.ts`](../../engine/context-engine/src/search.ts)) | **Reject** replace — different query semantics (path/explain/community vs chunk hit) | Cite-only |
| 2 | Code structure extraction | tree-sitter AST + call-graph second pass | `symbol-search`, `chunk-code` in context-engine | **Adapt** — provenance labels for inferred relationships; defer porting extractors | Cite-only |
| 3 | Semantic / keyword retrieval | Graph traversal + community reports + `GRAPH_REPORT.md` | `context-search`, `grep-first`, read-gate | **Keep** Octo stack for agent loop; graph is complementary, not substitute | Cite-only |
| 4 | Memory persistence | `graph.json` + SHA256 cache under `graphify-out/` | `state/memory/<profile>/` + LanceDB (gitignored) | **Defer** — separate store; do not merge into profile memory without ADR | Cite-only |
| 5 | Multimodal (PDF, images) | Claude vision extraction | Not supported in context-engine | **Defer** (pack-only) — child contexts with doc corpora may benefit later | Cite-only |
| 6 | Agent integration | Claude Code skill; optional `--mcp` stdio | Cursor + PS harness; MCP via capability packs | **Hold (TIP)** — pilot `--mcp` locally before catalog promote | Cite-only |
| 7 | Indexing cost | Claude API for doc/image passes; code path AST-only on `--watch` | Local nomic embeddings + incremental index | **Hold** — measure index cost vs LanceDB on same corpus before adoption | Cite-only |
| 8 | Token economics | Claims 71.5x vs raw read on 52-file corpus | card-lite at `/close`, usage-baseline | **Hold (TIP)** — needs paired BC run; do not promote on upstream benchmark alone | Cite-only |

### Checklist notes

- **Reject** wholesale: replace LanceDB, port Python graph pipeline into `domains/core/`, commit `graphify-out/` to public tree.
- Overlap with [ADR-005](../adr/ADR-005-okf-session-index.md): Graphify's `--wiki` index is an offline navigation artifact — similar *intent* to deferred OKF compact index, different format (graph communities vs frontmatter concepts). Keep LanceDB for on-demand search.
- Overlap with [eval/README.md](../../eval/README.md): policy remains **Keep DIY LanceDB** until external tool proves savings without quality loss.

---

## EOS initiatives map (15)

| Initiative | Graphify overlap | Verdict | Target path (if act) |
|------------|------------------|---------|----------------------|
| Engineering Standards & Governance | MIT license, SECURITY.md upstream | **Adapt** | Document external-tool evaluation template (this guide) |
| Kernel Architecture | Python skill + graph store | **Reject** port | Keep `domains/core` + packs (ADR-003) |
| Memory | Persistent `graph.json` across sessions | **Defer** | `state/memory/` gitignored overlay only if piloted |
| Context Engineering | `--wiki` agent-crawlable index | **Adapt** | Pattern for L1 navigation docs, not hook injection |
| RAG | GraphRAG-style community summaries | **Defer** | LanceDB remains primary ([eval README](../../eval/README.md)) |
| Token Optimization | Upstream token benchmark module | **Hold (TIP)** | `eval/metrics/` paired BC run |
| MCP Integration | `--mcp` stdio server | **Hold (TIP)** | Local pack overlay; add TIP isolation row |
| Agent Orchestration | `/graphify` slash skill | **Defer** | Octo phase loop unchanged; optional pack skill |
| Evaluation & Benchmarking | `benchmark.py`, worked examples | **Adapt** | Borrow corpus-vs-subgraph comparison idea for eval fixtures |
| Observability | Local HTML report only | **Reject** (product) | No fleet/graph daemon in core |
| Developer Experience | `pip install graphifyy`; Windows PATH notes | **Defer** | Document in private maintainer overlay if piloted |
| Documentation | GRAPH_REPORT.md auto-summary | **Adapt** | Inspiration for memory summary artifacts |
| Open Source Governance | High star count; young org | **Adapt** | Due-diligence checklist for viral OSS (this section) |
| CI/CD | Upstream pytest per module | **Defer** | No change to Octo CI from this spike |
| Security | XSS in local HTML; URL fetch validation | **Adapt** | Treat third-party graph HTML as untrusted; cite `security.py` patterns |

---

## Overall recommendation

| Layer | Verdict | Rationale |
|-------|---------|-----------|
| **Replace LanceDB / context-engine** | **Reject** | Different retrieval model; eval policy keeps DIY stack |
| **Promote to harness catalog default** | **Reject** | No TIP evidence; Claude indexing cost; Cursor adapter unproven |
| **Hold for TIP pilot** | **Hold** | Optional `--mcp` or CLI on octo-cluster fixture subset; compare tokens + gate_pass vs baseline |
| **Adapt patterns** | **Adapt** | EXTRACTED/INFERRED/AMBIGUOUS provenance; `--wiki` navigation; community/god-node summaries |
| **External research artifact** | **Done** | This document |

---

## Follow-up issue drafts

Tracker-agnostic titles (EOS naming: `[domain] imperative + object`). Create as separate cards; split if >3 days.

1. **`[eval] run TIP pilot for graphify MCP on BC card suite`**  
   Objective: Paired baseline vs graphify-on arms on BC-01…BC-05; record harness_score and token delta in metrics.db.

2. **`[rag] add graphify row to TIP isolation matrix`**  
   Objective: Document ON/OFF steps for `--mcp` in [tool-impact-protocol](./tool-impact-protocol.md) without committing local MCP config.

3. **`[context] document EXTRACTED-vs-INFERRED provenance for memory edges`**  
   Objective: Lightweight pattern in memory/context docs inspired by Graphify confidence labels — no graph store required.

4. **`[memory] evaluate wiki-style L1 navigation index for profiles`**  
   Objective: Prototype agent-crawlable `index.md` per profile community (offline artifact, gitignored) — borrow `--wiki` idea only.

5. **`[security] add third-party HTML report handling note to agent guidance`**  
   Objective: Agents opening local graph HTML from untrusted corpora treat output as untrusted (XSS precedent in upstream #1838).

---

## Recommended priority

| Priority | Action | Why |
|----------|--------|-----|
| P1 | Issues 2–3 | Cheap documentation; improves eval discipline without runtime change |
| P2 | Issue 1 | TIP pilot only if graph queries become a recurring need |
| P3 | Issues 4–5 | Nice patterns; easy to over-scope |

**Do not:** port Graphify into `domains/core/`, replace LanceDB, promote on star count alone, or commit `graphify-out/` / API keys to the public tree.
