# Linear workspace setup — Octo Cluster

One-time configuration for the `octo-cluster` Linear workspace. MCP cannot enable cycles or GitHub integration — complete these steps in the Linear UI.

## Team: Octo Cluster

**Settings → Team → Octo Cluster**

### Cycles

1. Enable **Cycles**
2. Duration: **1 week**
3. Start day: **Monday**
4. Cooldown: optional (disabled recommended for free tier)

### Estimates

Enable estimates mapped to days: `1` = 1 day, `2` = 2 days, `3` = 3 days. Split any issue estimated above 3 days.

### Workflow

Target states (add **In Review** if missing):

```text
Backlog → Todo → In Progress → In Review → Done
```

Current default may omit **In Review**. Add via **Team settings → Workflow**.

### GitHub integration

**Settings → Integrations → GitHub**

1. Connect `renanflustosa/octo-cluster`
2. Enable auto-link branches and auto-close on merge
3. Linear auto-branch prefix: `oct-` (rename to EOS pattern before merge — see [eos.md](./eos.md#branch-naming-standard))

### Initiatives (15)

Create in **Initiatives** (UI only — MCP cannot create initiatives):

| Initiative |
|------------|
| Engineering Standards & Governance |
| Kernel Architecture |
| Memory |
| Context Engineering |
| RAG |
| Token Optimization |
| MCP Integration |
| Agent Orchestration |
| Evaluation & Benchmarking |
| Observability |
| Developer Experience |
| Documentation |
| Open Source Governance |
| CI/CD |
| Security |

Link all initiatives to project **Octo Cluster EOS v1.0.0**.

### Project

Project **Octo Cluster EOS v1.0.0** is created via MCP. Verify it is linked to team Octo Cluster and initiatives above.

### Labels

Domain and work-type labels are created via MCP. Rules:

- Exactly **1 domain label** per issue (`kernel`, `memory`, `governance`, …)
- Optional work-type label (`docs`, `ci`, `chore`, …)
- `ai-ready` when Definition of Ready is complete

### Weekly ritual

- **Monday:** assign DoR-complete issues to current cycle (max 5–8)
- **Friday:** project status update; roll incomplete issues forward or split

See [eos.md](./eos.md) for full operating rules.
