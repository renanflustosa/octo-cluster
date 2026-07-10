# Cycle 2 — MVP Linear prompt (Octo Cluster EOS v1.0.0)

> Prompt otimizado para planejar o Cycle 2 no Linear. Prazo: **19 de julho de 2026**. Plataforma MVP: **Windows 11 + Cursor**.
>
> Uso: copie a seção **Prompt otimizado** para um novo chat no modo **PLAN** ou **AGENT**.

---

## Modo recomendado

**PLAN**

### Motivo

O pedido não é implementar código agora — é **planejar o MVP**, **priorizar escopo até 19/07/2026**, **criar cards no Linear (Cycle 2)** e **definir métricas de harness/token**. Isso exige análise do repositório, trade-offs de escopo, sequenciamento e DoR/DoD antes de qualquer execução.

---

## Premissas de desacoplamento

Desacoplamento orienta *como* entregar o MVP; **não expande** o escopo IN do Cycle 2.

Artefatos canônicos: [ADR-003](../adr/ADR-003-provider-agnostic-architecture.md), [ADR-004](../adr/ADR-004-use-github-issues-as-public-work-tracker.md), [ADR-006](../adr/ADR-006-harness-tool-cluster.md), [decoupling-map.md](../architecture/decoupling-map.md), [context-model.md](../architecture/context-model.md), [`platform.json`](../../contexts/runtime/platform.json).

| Premissa | MVP (Cycle 2) | Futuro (pós-19/07, só documentar) |
|----------|---------------|-----------------------------------|
| **Core agnóstico** | Cursor+Win11 como *adapter* validado; zero vocab Linear/Cursor hardcoded em `domains/core/` | 2º adapter (Claude/Ubuntu stub → implementação) |
| **Capability packs** | Linear/issue routing via MCP/pack privado; ship providers descobertos por manifest | Novos packs sem tocar kernel |
| **Trackers** | Cards Cycle 2 no Linear (privado); tree público permanece GitHub Issues (ADR-004) | Sync manual ou pack — nunca IDs privados no público |
| **Harness tools** | Catálogo + toggles documentados; bakeoff por `combination_id`; não enforcement total | ON/OFF real de todos toggles (V1.1+) |
| **Runtime dispatch** | `platform.json` + override local; packs desabilitados = não carregados | Child contexts / multi-pack |
| **Geração IDE** | Editar `domains/core/` + sync; `.cursor/` gerado | Adapters adicionais plugáveis |
| **Promoção para core** | Só se ≥2 packs precisarem; senão fica no pack | Regra explícita nos cards “pack vs core” |
| **Consumer boundary** | boundary-audit zero violations; nomes consumidor fora do tree | Idem — não relaxar no MVP |

Readiness layers ↔ boundary: camadas 5 (MCP) e 7 (rules/skills) são **pack/adapter**; camadas 1, 6, 8, 10 são **core**; 2–3 são **adapter + operador local**.

---

## OpenSRE e MegaBrain — Adapt vs Port

Referências: [opensre-analysis.md](./opensre-analysis.md), [ADR-005](../adr/ADR-005-okf-session-index.md), [ADR-006](../adr/ADR-006-harness-tool-cluster.md) §6.

| Fonte | Veredicto Cycle 2 | Onde no Octo | Ação no planning |
|-------|-------------------|--------------|------------------|
| OpenSRE `TokenUsage` / measured vs estimated | **Adapt** (IN) | `eval/metrics/` card-lite | Card token economy |
| OpenSRE `CI.md` brevity | **Adapt** (parcial — já existe) | [agent-pre-push.md](../governance/agent-pre-push.md) | Card: referenciar no loop `/ship` + AGENTS.md |
| OpenSRE tool-integration checklist | **Adapt** (IN) | capability packs / MCP docs | Card docs/pack |
| OpenSRE synthetic eval fixtures | **Adapt** (IN se ≤3d) | `eval/agentic/`, promptfoo | Card eval |
| OpenSRE masking / redaction | **Adapt** (IN docs) | boundary + SECURITY.md | Card security/docs |
| OpenSRE fleet daemon / runtime port | **Reject** | — | Fase E only |
| MegaBrain OKF `sessionStart` injection | **Defer** (ADR-005) | `session_hooks: false` | OUT explícito + card deferral |
| MegaBrain OKF offline index (POC) | **Defer** (pós-MVP) | `eval/okf-session-poc/` | Fase E; toggle `okf_index` permanece false |
| MegaBrain plugin port | **Reject** | — | OUT + boundary |

**Do not:** port OpenSRE runtime, deploy OpenSRE as dependency, port mega-brain plugin, or enable OKF `sessionStart` as default.

---

## Prompt otimizado

```text
# Role

Você é um **Tech Lead + Product Owner** do projeto **Octo Cluster EOS v1.0.0**, especializado em harness de agentes (Cursor), redução de custo em tokens, segurança OSS, arquitetura **core + capability packs + adapters**, e planejamento ágil no Linear.

# Objetivo

Analisar o repositório **octo-cluster** como um todo (Cycle 1 concluído no Linear) e produzir um **plano de MVP implacável** para **Windows 11 + Cursor**, com **cards prontos para o Cycle 2 no Linear**, garantindo que o projeto chegue **funcional, estável, seguro e sem bugs críticos** até **19 de julho de 2026**.

Entregável principal: **backlog priorizado + especificação completa de cada card** (não apenas títulos).

# Contexto

## Produto

- **Octo Cluster EOS v1.0.0** — harness local de desenvolvimento assistido por IA (tool-agnostic core, adapter MVP = Cursor + Win11).
- Release atual: **v0.1.1**. Próximo alvo público: **v0.2.x** (métricas, CI expandido). Meta estratégica: **v1.0.0** (kernel estável, eval em CI, governança OSS completa).

## Filosofia (obrigatória)

**A Regra do MVP Implacável:** entregar a solução **mais simples** que resolve a dor na v1. Se não puder ser testado em **poucos dias (≤3 dias por card)**, o escopo está grande demais — **cortar ou dividir**.

## Filosofia de desacoplamento (obrigatória)

- **Core** (`domains/core/`, `capabilities/core/`) permanece agnóstico de IDE, tracker e vendor.
- **Cursor + Win11** é o *adapter* MVP validado — não hardcode de Cursor/Linear em scripts core.
- **Linear** e MCPs de tracker ficam em **capability pack / overlay privado** — nunca no tree público (ADR-004).
- **Harness tools** via `combination_id` + `harness_tools` em `platform.json` — preferir toggles/catálogo a `if vendor` espalhado (ADR-006).
- **Promoção para core** só quando ≥2 packs precisarem do mesmo comportamento (ADR-003).
- **OpenSRE / MegaBrain:** **Adapt** padrões nativos Octo; **Reject** runtime ports; **Defer** OKF sessionStart (ADR-005).

## Estado assumido

- Todas as tarefas do **Cycle 1 (Linear)** estão **Done**.
- Cycle 2 começa agora; prazo final do ciclo/projeto: **19/07/2026** (~9 dias úteis a partir de 10/07/2026).
- Tracker privado: **Linear** (team privado). Repositório público usa **GitHub Issues/Milestones** — cards Linear **não** devem vazar identificadores privados para o tree público.

## Artefatos canônicos (ler antes de propor cards)

1. `docs/governance/eos.md` — 15 initiatives, DoR/DoD, naming, max 3 dias/card
2. `ROADMAP.md` — semver ladder até 1.0.0
3. `docs/guides/v1-harness-readiness.md` — 10 camadas de readiness Win11+Cursor
4. `docs/guides/token-metrics-baseline.md` + `eval/metrics/README.md`
5. `docs/adr/ADR-006-harness-tool-cluster.md` + `docs/guides/harness-tool-cluster.md`
6. `docs/adr/ADR-005-okf-session-index.md` — sessionStart **deferido** (não reintroduzir como default)
7. `docs/guides/opensre-analysis.md` — padrões Adapt vs Reject vs Defer
8. `docs/adr/ADR-003-provider-agnostic-architecture.md` + `docs/architecture/decoupling-map.md`
9. `contexts/runtime/platform.json` — `combination_id`, `harness_tools`, `session_hooks: false`
10. Scripts de validação: `productivity-audit.ps1`, `boundary-audit.ps1`, `bun run validate octo-cluster`

## O que V1 maximiza

- Qualidade do harness: phase loop, gates, boundary-audit, LanceDB + grep-first, agent pre-push
- Estabilidade Win11 + Cursor (adapter MVP)

## O que V1 minimiza

- Custo em tokens: caveman + ponytail-lite, card-lite, combination bakeoff, **hooks vazios** (sem injeção frágil)
- Escopo: sem port OpenSRE/mega-brain, sem adapter Claude/Ubuntu completo, sem enforcement total de todos `harness_tools`

# Constraints

1. **Plataforma MVP:** Windows 11 + Cursor apenas.
2. **Prazo hard:** 19/07/2026 — plano deve caber no tempo restante com buffer para estabilização.
3. **Escopo mínimo, qualidade máxima:** preferir menos cards bem feitos a muitos cards superficiais.
4. **Segurança:** respeitar consumer boundary (`scripts/boundary-audit.ps1`), sem secrets no tree, SECURITY.md, OpenSSF posture.
5. **Sem acoplamento de tracker no core:** Linear via MCP/capability pack; core permanece agnóstico (ADR-004).
6. **Core agnóstico:** zero vocab Linear/Cursor/Linear-MCP hardcoded em `domains/core/` ou `core-*.ps1`.
7. **Layer por card:** cada card declara `Layer: core | pack | adapter` — rejeitar cards que misturam camadas sem split.
8. **Harness toggles:** mudanças de ferramentas via `platform.json` / catálogo ADR-006 — não `if vendor` no kernel.
9. **OpenSRE/MegaBrain:** Adapt padrões nativos apenas; Reject ports de runtime; Defer OKF sessionStart.
10. **Cards ≤3 dias cada** — split obrigatório se maior.
11. **1 objetivo por card**, 1 assignee, 1 domain label, initiative EOS atribuída.
12. **Não reabrir decisões deferidas** (ex.: OKF sessionStart) salvo card explícito de reavaliação com evidência nova.
13. **Idioma dos cards:** inglês (convenção EOS para issues/commits/docs).
14. **Modo de trabalho:** analisar repo + Linear; se MCP Linear disponível, inspecionar Cycle 1 Done e estado do Cycle 2; se não, inferir gaps a partir do repo e listar premissas.

# Decision criteria (priorização)

Ordem de desempate para incluir/excluir cards:

1. **Bloqueia v1.0.0 funcional no Win11?** (release gate, CI, harness smoke, boundary)
2. **Respeita fronteira core/pack/adapter?** (sem dívida estrutural; promoção para core justificada)
3. **Mede ou reduz tokens com evidência?** (baseline, bakeoff, report.ps1)
4. **Reduz bugs/risco de regressão?** (testes, audit, pre-push gates)
5. **Melhora DX do loop diário?** (/scan → /ship → /close)
6. **Documentação que desbloqueia adoção segura?** (MCP, hooks, limitações)
7. **Adapt OpenSRE/MegaBrain com path Octo nativo?** (cite-only / Adapt — nunca port runtime)
8. **Nice-to-have / fase 2** → **Out of Cycle 2** ou milestone pós-19/07

# Tarefas (ordem de execução)

## Fase A — Diagnóstico (read-only)

1. Mapear estado atual vs gates de `ROADMAP.md` e `eos.md#semver-path-to-1.0.0`.
2. Rodar ou inferir resultados de:
   - `pwsh scripts/productivity-audit.ps1 -Workstation`
   - `pwsh scripts/boundary-audit.ps1`
   - `bun run validate octo-cluster` (em `engine/context-engine`)
3. Identificar GAPs nas 10 camadas de `v1-harness-readiness.md`.
4. Revisar Cycle 1 (Linear): o que ficou implícito/incompleto?
5. Calcular capacidade: dias úteis até 19/07, assumindo 1 dev + agente, ~1 card ativo por vez.

## Fase B — Definição do MVP até 19/07

1. Declarar **escopo IN** (mínimo para “Octo Cluster EOS v1.0.0” **credível** no Win11) vs **OUT** (v1.1+).
2. Propor **semver realista** para 19/07 (ex.: 0.2.x estável vs 1.0.0) com justificativa honesta — não prometer 1.0.0 se gates não fecham.
3. Definir **Definition of Release** para a data (checklist executável).

## Fase C — Cards Linear Cycle 2

Criar **8–15 cards** (ajustar à capacidade), cada um com template EOS completo (ver seção abaixo no guia).

Incluir obrigatoriamente cards nas categorias:

- **Release & stability** (CI smoke, bug bash, boundary, pre-push)
- **Token economy** (baseline publicado, bakeoff, defaults evidence-based; OpenSRE measured vs estimated Adapt)
- **Harness readiness** (fechar GAPs das 10 camadas)
- **Security** (audit, dependabot, secret hygiene, redaction guidance Adapt)
- **Documentation** (MCP setup, hooks status/limitações, v1 runbook Win11, agent-pre-push wired)
- **Explicit deferrals** (OpenSRE port, mega-brain sessionStart, OKF offline — ADR refs)

Cada card deve incluir `Layer: core | pack | adapter`.

Se MCP Linear estiver autenticado: **criar os issues no Cycle 2** com label `ai-ready`, prioridade, dependências e link ao milestone/projeto **Octo Cluster EOS v1.0.0**. Se não: entregar markdown copy-paste pronto para criação manual.

## Fase D — Métricas e experimentos

1. Definir **3–5 KPIs** mensuráveis até 19/07, ex.:
   - `productivity-audit.ps1` score / camadas OK vs GAP
   - `eval/metrics/report.ps1 -CompareCombinations` — combinação vencedora documentada
   - tokens por work item (baseline vs card-lite/ponytail)
   - CI green rate, boundary-audit zero violations
   - tempo médio /scan → /ship por card
2. Amarrar cada KPI a **card(s)** e **comando de validação**.

## Fase E — Roadmap pós-MVP (documentação only)

Lista curta de melhorias **pós-19/07** com techs e esforço — **sem cards no Cycle 2** salvo se desbloqueiam KPI crítico:

- 2º adapter (Claude/Ubuntu stub → implementação)
- Enforcement real de todos `harness_tools` toggles (V1.1)
- OKF offline compact index (mega-brain format; sem sessionStart)
- Promptfoo em CI
- MCPs adicionais via capability packs
- Hooks quando Cursor estabilizar `sessionStart` (reavaliar ADR-005)
- Sync manual tracker pack ↔ GitHub Issues

# Success criteria

1. Plano MVP **cabe no calendário** até 19/07/2026 com buffer ≥1 dia para hardening.
2. Cada card Cycle 2 tem **DoR completo** (pronto para `ai-ready`) + **Layer** declarada.
3. Escopo **explicitamente cortado** — lista OUT clara com referências ADR/ROADMAP.
4. Métricas de **harness ↑** e **tokens ↓** com baselines e targets numéricos ou comparativos (A/B).
5. Zero recomendações que violem **consumer boundary** ou reintroduzam **sessionStart** instável como default.
6. Zero cards que portem OpenSRE/mega-brain runtime ou hardcodem tracker no core.
7. Validação Win11: todo card inclui comandos PowerShell/Bun verificáveis.
8. Se Linear MCP usado: links/IDs dos issues criados; senão: pacote pronto para import.

# Formato de resposta esperado

Responder em **português**, estruturado:

1. **Executive summary** (5–10 linhas)
2. **Gap analysis** (tabela: área | estado | GAP | prioridade)
3. **MVP scope** (IN / OUT) + semver alvo realista para 19/07
4. **Capacity plan** (timeline dia-a-dia ou semana)
5. **Cycle 2 backlog** (cards completos, ordenados P0→P2)
6. **Metrics dashboard** (KPI | baseline | target | owner card)
7. **Risk register** (top 5 + mitigação)
8. **Post-19/07 backlog** (bullet list, esforço T-shirt)
9. **Assumptions & open questions** (se Linear inacessível)

# O que NÃO fazer

- Não implementar código nem commitar no repositório nesta tarefa (planejamento only).
- Não inflar escopo para fechar todos os 15 initiatives — foco no caminho crítico Win11.
- Não criar cards >3 dias ou com múltiplos objetivos.
- Não prometer v1.0.0 sem fechar gates objetivos de `eos.md` e `ROADMAP.md`.
- Não copiar nomes/identificadores de consumidor para artefatos públicos.
- Não sugerir features não testáveis em poucos dias sem split.
- **Anti-patterns de desacoplamento:** hardcode tracker no core; lógica Cursor em `core-*.ps1`; IDs Linear no tree público; `if vendor` espalhado vs toggles/catálogo; port OpenSRE ou mega-brain runtime; promover lógica de pack para core sem ≥2 consumidores.
```

---

## Template EOS por card (Linear)

```markdown
Title: [domain] imperative verb + object

## Context

## Objective (single, measurable)

## Layer

core | pack | adapter

## Scope

### In

### Out

## Inputs

## Outputs

## Dependencies

blockedBy: <private-issue-id> | none

## Acceptance Criteria

- [ ] ...

## Validation

```powershell
# exact commands
pwsh scripts/productivity-audit.ps1 -Workstation
bun run validate octo-cluster
```

## Definition of Done

- [ ] Code implemented
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Acceptance criteria validated
- [ ] CI passing
- [ ] No critical security findings
- [ ] Conventional Commit used
- [ ] PR approved

## Estimate

1-3 days (split if >3)

## Metrics (if applicable)

- combination_id:
- harness_score target:
- token delta target:

## Initiative

(one of 15 EOS initiatives — see docs/governance/eos.md)
```

---

## Referência rápida — 15 EOS initiatives

| Initiative | Scope |
|------------|-------|
| Engineering Standards & Governance | Branch, commit, SemVer, releases, ADRs |
| Kernel Architecture | `domains/core/`, `capabilities/` |
| Memory | `engine/context-engine/`, `state/memory/` |
| Context Engineering | `contexts/`, execution context |
| RAG | context-engine indexing, `engine/indexing/` |
| Token Optimization | caveman/ponytail, `eval/metrics/` |
| MCP Integration | MCP docs, adapters |
| Agent Orchestration | phase commands, core-adaptive-loop |
| Evaluation & Benchmarking | `eval/` |
| Observability | `engine/metrics/` |
| Developer Experience | install, onboarding, adapters |
| Documentation | `docs/` |
| Open Source Governance | root OSS files |
| CI/CD | `.github/workflows/` |
| Security | SECURITY.md, scanning |

---

## Referência rápida — V1 harness readiness (10 camadas)

| # | Layer | Status esperado V1 | Boundary |
|---|-------|-------------------|----------|
| 1 | OS / tools / env | OK — productivity-audit | core |
| 2 | Workspace folders | WARN — multi-root, no secrets | adapter |
| 3 | Cursor settings | WARN — hooks enabled, token-aware | adapter |
| 4 | Extensions | OK — PowerShell + YAML only | adapter |
| 5 | MCP servers | WARN — local config, auth OK | pack |
| 6 | Hooks | OK — empty by design (ADR-005) | core |
| 7 | Rules / skills / commands | OK — sync from domains/core | core |
| 8 | Runtime JSON | OK — platform.json + local override | core |
| 9 | Memory / RAG | OK — context_engine + memory_index | core |
| 10 | Eval / metrics | OK — scan/close + report.ps1 | core |

Validação rápida:

```powershell
pwsh scripts/productivity-audit.ps1 -Workstation
pwsh eval/metrics/report.ps1 -CompareCombinations -Last 5
pwsh scripts/boundary-audit.ps1
```

---

## Referência rápida — semver ladder

| Version | Gate |
|---------|------|
| 0.1.0 | Public harness, basic CI, Cursor validated |
| 0.1.1 | Public framework boundary audit |
| 0.2.x | EOS published, metrics baseline, expanded CI |
| 0.x | ADR process, feature docs, 2nd adapter |
| 1.0.0 | Stable kernel API, eval in CI, full OSS governance |

---

## Out of scope V1 (não reintroduzir no Cycle 2)

- Port OpenSRE ou mega-brain runtimes
- OKF `sessionStart` como default (ADR-005 Deferred)
- Adapter Claude/Ubuntu completo (stub only)
- Enforcement de todos `harness_tools` toggles (V1.1)
- Cloud agents sessionStart injection

---

## Melhorias realizadas

- Guia restaurado após sobrescrita acidental pelo meta-prompt de edição
- Seção **Premissas de desacoplamento** (MVP vs futuro) ancorada em ADR-003/004/006 e decoupling-map
- Seção **OpenSRE e MegaBrain — Adapt vs Port** com tabela acionável para cards
- **Filosofia de desacoplamento** + 5+ constraints operacionais no Prompt otimizado
- Decision criteria inclui fronteira core/pack/adapter e Adapt OpenSRE/MegaBrain
- Template EOS com campo **Layer: core | pack | adapter**
- Fase E alinhada a extensões desacopladas (2º adapter, toggles, OKF offline, MCPs)
- Anti-patterns explícitos (tracker no core, ports runtime, `if vendor`)
- Readiness layers cruzadas com boundary desacoplamento

---

## Próximo passo

1. Abrir novo chat em modo **PLAN** ou **AGENT**
2. Colar a seção **Prompt otimizado** (bloco `text` acima)
3. Autenticar MCP Linear se quiser criação automática dos issues
