# Harness tool cluster

Modular catalog of **free/local** harness and cost tools, plus an experiment protocol to pick the best combination by evidence.

Canonical decision: [ADR-006](../adr/ADR-006-harness-tool-cluster.md). Inventory: [harness-catalog.yaml](../architecture/harness-catalog.yaml). V1 certainty checklist: [v1-harness-readiness.md](./v1-harness-readiness.md). Pre-push: [agent-pre-push.md](../governance/agent-pre-push.md).

## Tool Impact Protocol (external tools)

For MCP servers, IDE extensions, CLIs, and other **third-party** tools: [tool-impact-protocol.md](./tool-impact-protocol.md) (paired A/B, promote/reject before catalog changes).

## 4-way bakeoff (harness + token consumption)

Protocol: [combination-bakeoff.md](../../eval/agentic/protocol/combination-bakeoff.md) (arms: `nada` / `baseline` / `compress-on` / `octo-full`).

- Cards: `eval/agentic/fixtures/bakeoff-cards/BC-01.md` … `BC-05.md`
- Runtime overlays: `eval/agentic/fixtures/runtime-arms/*.json` → copy to `contexts/runtime/platform.local.json`
- Rank: `pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50`

## Purpose

1. Inventory what already exists (do not install every free tool).
2. Toggle combinations via runtime JSON (`combination_id` + `harness_tools`).
3. Measure each card into SQLite; rank with `report.ps1 -CompareCombinations`.
4. Keep core IDE-agnostic; Cursor+Windows first; Claude+Ubuntu via adapters later.

## Implementation

| Layer | Path |
|-------|------|
| Catalog | `docs/architecture/harness-catalog.yaml` |
| Runtime toggles | `contexts/runtime/platform.json` (`combination_id`, `harness_tools`) |
| Metrics | `eval/metrics/measure-card-lite.ps1`, `report.ps1`, `engine/metrics/` |
| Bakeoff | `eval/agentic/protocol/combination-bakeoff.md` |
| Claude stub | `adapters/claude/README.md` |

Defaults match today’s platform behavior (LanceDB on, caveman/ponytail on, OKF index off, session hooks off).

## Usage

```powershell
# Inspect / set combination (edit runtime JSON or use a .local.json overlay)
# combination_id: baseline | compress-on | ...

# After cards close:
pwsh eval/metrics/report.ps1 -Last 20
pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50
```

Bakeoff steps: [combination-bakeoff.md](../../eval/agentic/protocol/combination-bakeoff.md).

## Validation

```powershell
Test-Path docs/adr/ADR-006-harness-tool-cluster.md
Test-Path docs/architecture/harness-catalog.yaml
pwsh eval/metrics/report.ps1 -Last 5
pwsh scripts/boundary-audit.ps1
```

## Limitations

- MVP documents toggles; not every `harness_tools.*` flag is enforced in code yet (phase 2).
- Cursor usage may be `skipped` — ranking still uses LOC + gates.
- Claude adapter is contract-only until phase 3.

## Related

- [tool-impact-protocol.md](./tool-impact-protocol.md)
- [metrics-kernel.md](../architecture/metrics-kernel.md)
- [token-metrics-baseline.md](./token-metrics-baseline.md)
- [opensre-analysis.md](./opensre-analysis.md)
- [ADR-005](../adr/ADR-005-okf-session-index.md)
