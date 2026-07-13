# README governance + Linear issue naming prompt (Octo Cluster)

> Prompt otimizado para revisar o README, padronizar issues no Linear e garantir o padrão `[domínio] verbo + objeto` em issues futuras.
>
> **Uso:** copie a seção [Prompt otimizado](#prompt-otimizado) (da linha marcada `INÍCIO DO PROMPT` até `FIM DO PROMPT`) para um novo chat no modo **PLAN** ou **AGENT**.

---

## Modo recomendado

**PLAN**

### Motivo

O pedido combina três frentes interdependentes — reestruturação do README, padronização retroativa de todas as issues no Linear e definição de um mecanismo de enforcement para issues futuras — além de decisões de alinhamento com artefatos existentes (`docs/governance/eos.md`, `CONTRIBUTING.md`, ADR-004). Antes de editar arquivos ou renomear cards em massa, é necessário auditar o estado atual, definir domínios canônicos e escolher como garantir o padrão `[domínio] verbo + objeto` de forma sustentável (template Linear, documentação, regras de agente, etc.).

---

## Melhorias realizadas

- Objetivo dividido em três entregas claras: card Linear, padronização retroativa e enforcement futuro
- Contexto enriquecido com artefatos reais do repo (`eos.md` já define o padrão de naming; ADR-004 separa trackers público/privado)
- Premissa explícita de que Linear e GitHub Issues compartilham o mesmo padrão `[domain] imperative verb + object`
- Ordem de execução em fases: auditoria → criação do card âncora → renomeação → enforcement
- Restrição de não renomear em massa sem tabela de mapeamento prévia
- Critérios de sucesso mensuráveis (100% conformidade, 4 seções no README, ≥2 camadas de enforcement)
- Correção do typo "demoderatizar" → "democratizar"
- Alinhamento com convenção English-only do EOS para arquivos públicos
- Regras de segurança do vault e consumer boundary (sem vazar Linear no tree público)
- Formato de resposta definido para facilitar revisão pelo maintainer
- Tom do README especificado: acolhedor, com expectativas claras (modelo SQLite)
- Card âncora com título já no padrão canônico, em inglês, coerente com EOS

---

## Prompt otimizado

<!-- INÍCIO DO PROMPT — copie daqui para o Cursor -->

# Role

Você é um **Tech Lead + Maintainer** do projeto **Octo Cluster** (`c:\octo-cluster`), responsável por governança OSS, documentação pública e operações no **Linear** (tracker privado do time).

# Objetivo

Executar um pacote de trabalho em três partes:

1. **Criar um card no Linear** para revisar o README e explicitar a filosofia de governança do projeto.
2. **Padronizar retroativamente** todas as issues existentes no Linear para o formato `[domínio] verbo + objeto`.
3. **Garantir** que todas as issues futuras no Linear sigam esse padrão de forma sustentável.

# Contexto

## Repositório

- **Repo:** `c:\octo-cluster` (público, MIT, English-only por convenção EOS).
- **README atual:** focado em harness técnico, EOS e GitHub Issues — **não comunica** a missão de democratização de IA nem o modelo de governança estilo SQLite.
- **Artefatos canônicos a alinhar (ler antes de escrever):**
  - `README.md`
  - `CONTRIBUTING.md`
  - `docs/governance/eos.md` — já define naming de issues: `[domain] imperative verb + object`
  - `ROADMAP.md`
  - `docs/adr/ADR-004-use-github-issues-as-public-work-tracker.md` — GitHub Issues = tracker público; Linear = tracker privado do time
- **Integração Linear:** credencial no vault local do maintainer (ler apenas on-demand; nunca colar valores no chat ou no repo público).

## Filosofia que o README deve transmitir

O Octo Cluster é um **meio**, não o **fim**. A missão é:

> Democratizar o acesso à IA generativa de alta qualidade utilizando exclusivamente software open source e ferramentas gratuitas.

Modelo de governança inspirado em projetos como **SQLite**:

- Código 100% open source
- Desenvolvimento transparente
- Roadmap público
- Issues abertas
- Discussões públicas
- Sugestões da comunidade são bem-vindas
- Bugs podem ser reportados por qualquer pessoa
- **Open source ≠ open governance:** arquitetura e decisões técnicas permanecem centralizadas nos maintainers
- PRs podem ser analisados, mas **não há expectativa** de aceitar contribuições externas
- Objetivo: preservar simplicidade, consistência arquitetural, qualidade e velocidade de evolução

Tom: alinhar expectativas desde o início, **sem soar hostil** à comunidade.

## Padrão de títulos de issues (Linear)

Formato obrigatório:

    [domínio] verbo imperativo + objeto

Exemplos canônicos (já em `docs/governance/eos.md`):

- `[governance] add code of conduct`
- `[memory] implement profile compaction`

Regras:

- Domínio em minúsculas, entre colchetes
- Verbo no imperativo (inglês, conforme EOS)
- Objeto claro e específico
- Proibido: títulos vagos (`Fix stuff`, `Improve code`), gerúndios sem verbo imperativo

**Premissa:** o padrão do Linear deve ser **idêntico** ao já documentado no EOS para GitHub Issues, mantendo consistência entre trackers.

# Tarefas e ordem de execução

## Fase 1 — Auditoria (somente leitura)

1. Ler `README.md`, `CONTRIBUTING.md`, `docs/governance/eos.md`, `ROADMAP.md` e ADR-004.
2. Listar **todas as issues** do time/projeto no Linear via MCP ou API.
3. Classificar cada issue:
   - ✅ já conforme `[domínio] verbo + objeto`
   - ⚠️ parcialmente conforme (domínio errado, verbo não imperativo, objeto vago)
   - ❌ não conforme
4. Extrair lista de **domínios canônicos** já em uso + propor domínios faltantes (ex.: `governance`, `docs`, `harness`, `memory`, `eval`, `adapter`, `pack`).
5. Apresentar plano de renomeação (tabela: ID → título atual → título proposto) **antes** de aplicar mudanças em massa.

## Fase 2 — Criar card no Linear (issue âncora)

Criar issue no Linear com:

- **Título:** `[governance] revise README to explicit project governance philosophy`
- **Descrição** (em inglês, alinhada ao EOS), incluindo:

### Objetivos

- Tornar explícita a missão de democratizar acesso à IA generativa com ferramentas gratuitas e open source
- Deixar claro que Octo Cluster é meio, não fim
- Diferenciar open source de open governance

### Entregáveis no README

- Seção **Mission**
- Seção **Principles**
- Seção **Governance** (modelo SQLite: transparente, liderança técnica centralizada)
- Seção **Contributing** alinhada: feedback, issues e discussões incentivados; direção arquitetural com maintainers

### Mensagens-chave (escolher redação final no README)

- "Make high-quality generative AI accessible to anyone using open source software and free tools."
- ou "Democratize access to generative AI through open source software, free infrastructure, and a simple experience."

### Critérios de aceite

- README em inglês, tom acolhedor mas com expectativas claras
- Sem contradição com EOS, CONTRIBUTING, ADR-004 e ROADMAP
- Links cruzados para `docs/governance/eos.md` e `CONTRIBUTING.md`
- Não expor IDs, URLs ou nomes do tracker privado Linear no tree público

## Fase 3 — Padronizar issues existentes no Linear

1. Aplicar renomeações aprovadas na Fase 1.
2. Garantir que cada issue tenha **exatamente 1 label de domínio** coerente com o prefixo `[domínio]` (conforme EOS).
3. Registrar no comentário da issue (se renomeada): `Renamed to match EOS naming: [domain] imperative verb + object` — sem expor segredos.

## Fase 4 — Garantir padrão para issues futuras

Implementar **pelo menos duas** camadas de enforcement (propor e executar):

| Camada | Ação esperada |
|--------|---------------|
| **Linear** | Criar/atualizar **issue template** com título placeholder `[domain] imperative verb + object` + checklist DoR |
| **Documentação** | Reforçar convenção em `docs/governance/eos.md` e, se necessário, `CONTRIBUTING.md` — explicitando que Linear segue o mesmo padrão |
| **Agentes** | Atualizar `AGENTS.md` ou regra em `domains/core/rules/` para que agentes criem issues Linear sempre no formato canônico |
| **Validação** | Script ou checklist manual documentado para revisar título antes de marcar issue como pronta |

**Não basta** renomear issues antigas — deve existir mecanismo verificável para novas issues.

# Restrições

- **English-only** em arquivos versionados do repo público (`README.md`, docs, commits, PRs).
- **Nunca** commitar, colar ou copiar credenciais do vault para o repo público ou chat.
- **Nunca** expor IDs/URLs do Linear no tree público (ADR-004 / consumer boundary).
- **Não** alterar a filosofia técnica do harness nem expandir escopo além do pedido.
- **Não** renomear issues sem apresentar a tabela de mapeamento primeiro (exceto a issue âncora da Fase 2).
- **Não** soar hostil à comunidade no texto do README.
- Corrigir typo conceitual: missão é **democratizar**, não "demoderatizar".
- Respeitar a security policy do vault ao ler credenciais (somente on-demand).

# Critérios de sucesso

1. ✅ Card âncora criado no Linear com título e descrição completos.
2. ✅ **100%** das issues do Linear seguem `[domínio] verbo imperativo + objeto`.
3. ✅ Domínios consistentes entre prefixo do título e label da issue.
4. ✅ README atualizado com seções Mission, Principles, Governance e Contributing.
5. ✅ Mecanismo de enforcement documentado e operacional para issues futuras (template + docs + regra de agente).
6. ✅ Nenhum vazamento de tracker privado ou credencial no repo público.
7. ✅ Relatório final com: issues renomeadas, arquivos alterados, e como validar o padrão em novas issues.

# Formato da resposta esperada

1. **Resumo executivo** (3–5 bullets)
2. **Auditoria Linear** — tabela antes/depois das renomeações
3. **Plano de enforcement** — o que foi implementado em cada camada
4. **Diff conceitual do README** — estrutura das novas seções (ou link para PR/commit)
5. **Checklist de validação** — passos para o maintainer confirmar que tudo está correto

# O que NÃO fazer

- Não executar renomeações em massa sem mostrar o mapeamento primeiro.
- Não inventar domínios sem justificativa ou sem alinhar ao EOS existente.
- Não misturar português no README público.
- Não criar issues Linear com títulos vagos ou fora do padrão.
- Não sincronizar IDs Linear para GitHub Issues automaticamente sem revisar boundary.
- Não alterar credenciais no vault sem pedido explícito do usuário.

<!-- FIM DO PROMPT -->
