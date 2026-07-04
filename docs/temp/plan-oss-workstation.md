# /model — Workstation OSS + modelo local mínimo (prompt temporário)

**Modo:** Plan only — sem código, sem commits, sem instalar nada até aprovar o plano.

**Projeto ativo:** octo-cluster — harness com Dev Container (`.devcontainer/`), context-engine (Bun + LanceDB), pipeline `pwsh octo.ps1`.

**Uso:** colar no chat com `/model` ou `@docs/temp/plan-oss-workstation.md`.

---

## Objetivo

Definir um stack **100% open source** para dev + IA local que:

1. Rode um **modelo minimamente funcional** nas limitações reais de hardware (VRAM, RAM, CPU).
2. Priorize **agente que interage com o SO** (executar scripts, instalar deps, analisar pastas, ler contextos grandes) — **não** autocomplete, **não** gerar sites do zero.
3. Permita **comandos customizáveis** (loop `/scan` → `/model` → `/ship`, scripts `.ps1`/shell do octo-cluster).
4. Seja viável com **octo-cluster** (Dev Container, sync `.cursor/`, LanceDB, hooks).

---

## Restrições explícitas

| Prioridade alta | Prioridade baixa / fora de escopo |
|-----------------|-----------------------------------|
| IA executando comandos no OS (PowerShell, bash, git, bun) | Autocomplete estilo Copilot |
| Ler/analisar contextos grandes (RAG, grep, LanceDB) | Gerar sites/apps do zero |
| Customizar commands/rules/skills | UX idêntica ao Cursor Agent/Composer |
| Otimizar VRAM/RAM/CPU para inferência local | Dual boot imediato sem análise |
| Stack OSS: **VSCodium + Continue + Ollama + Dev Container** | Cursor proprietário como destino final |

---

## Hardware snapshot (coletado 2026-07-03)

> Re-executar `.\scripts\workstation-inventory.ps1 -Json` se a máquina mudou.

| Componente | Valor |
|------------|-------|
| CPU | AMD Ryzen 3 2200G — 4 cores / 4 threads, ~3.5 GHz |
| RAM | **32 GB** (2×16 GB @ 3200 MHz) — ~22 GB livres no snapshot |
| GPU | **AMD Radeon Vega 8** (iGPU integrada) — WMI ~2048 MB shared |
| Disco C: | 446 GB total, **316 GB livres** |
| OS | Windows 10 Pro 64-bit (build 19045) |
| WSL | v2, **Ubuntu** registrado (Stopped) |
| Docker | Desktop no startup; CLI ainda não no PATH |
| Ollama | Não instalado |
| Harness | git, gh, bun, rg, pwsh — `[READY]` via `install.ps1` |

### Implicações para o plano (pré-análise — validar no /model)

- **32 GB RAM** — excelente para inferência **CPU** com modelos 7B quantizados (Q4); principal trunfo da máquina.
- **Vega 8 iGPU** — VRAM compartilhada, **sem ROCm/CUDA confiável no Windows**; não contar com aceleração GPU para Ollama. Plano deve assumir **CPU-first** ou testar ROCm só se migrar para **Linux nativo** (ainda limitado em APU).
- **Ryzen 3 2200G (4T)** — modelos grandes (13B+) serão lentos; preferir **3B–7B coder** quantizados.
- **Docker pendente** — Dev Container bloqueado até Docker Desktop rodar; WSL Ubuntu já existe.

---

## Fase 0 — Atualizar inventário (se stale)

```powershell
cd C:\GitHub\octo-cluster
.\scripts\workstation-inventory.ps1 -Json
.\scripts\productivity-audit.ps1
# AMD GPU — sem nvidia-smi; opcional no Linux: rocm-smi
wsl -l -v
docker version 2>$null
ollama list 2>$null
```

---

## Decisões a tomar no plano

### 1. Linux host

- **Default:** Ubuntu 24.04 LTS (alinha com `.devcontainer/devcontainer.json`).
- **Alternativa desktop simples:** Linux Mint 22.
- Comparar **WSL2 Ubuntu (já instalado)** vs **Linux nativo/dual boot** — recomendar dual boot só se ganho claro (menos overhead que Win + Docker Desktop + WSL) **e** se ROI compensar format/partição.

### 2. Stack OSS editor + IA

| Camada | Candidato OSS |
|--------|----------------|
| Editor | VSCodium + Dev Containers |
| IA in-editor | Continue.dev |
| Runtime local | Ollama |
| Autocomplete | **Skip** (não prioritário) |
| Agent CLI / OS | Continue agent + terminal integrado; comparar **Aider** para exec shell |

Confirmar: Dev Container, `pwsh octo.ps1`, `bun run validate octo-cluster`.

### 3. Modelo local — matriz (ajustar ao hardware acima)

| Cenário | Modelo | Quant | Notas para esta máquina |
|---------|--------|-------|-------------------------|
| **Recomendado inicial** | `qwen2.5-coder:3b` ou `1.5b` | Q4_K_M | CPU, 32 GB RAM — resposta aceitável |
| Intermediário | `qwen2.5-coder:7b` | Q4_K_M | CPU-only; usar `num_ctx` moderado (8k–16k) |
| Evitar no início | 13B+, modelos multimodal | — | 4T CPU + sem GPU dedicada |
| GPU (só se Linux+ROCm viável) | 7B com layers parciais | Q4 | Vega 8 — expectativa baixa; validar antes |

Parâmetros Ollama a definir: `OLLAMA_NUM_PARALLEL`, `num_ctx`, threads CPU (=4), `OLLAMA_MAX_LOADED_MODELS=1`.

### 4. Integração octo-cluster

- Caminho oficial: **Dev Container** (`.devcontainer/post-create.sh`).
- Commands/skills: adaptador VSCodium vs terminal + `octo.ps1`.
- LanceDB/context-engine = camada **COST 0** antes do LLM.
- Manter hooks + `boundary-audit`.

### 5. Otimização de recursos

- Fechar apps GPU/RAM antes de inferência; **um modelo carregado por vez**.
- Contexto grande → LanceDB + grep + read-gate; **não** colar repo inteiro no prompt.
- Docker Desktop consome RAM — no Linux nativo preferir **Docker Engine**.
- Considerar inferência leve (3B) para comandos OS; reservar 7B para análise pontual.

---

## Alternativas a comparar (rejeitar com motivo)

- Cursor proprietário (fora — meta OSS)
- NixOS / Arch (complexidade alta)
- Modelos 32B+ (invável neste hardware)
- Tabby / autocomplete self-hosted (baixa prioridade)
- API cloud paga como solução principal (só fallback opcional)

---

## Saída esperada do /model (≤80 linhas)

1. **Hardware summary** — confirmar snapshot acima
2. **Verdict** — viável / limite / inviável para "agente + OS"
3. **Stack** — OS + editor + IA + container (uma linha cada)
4. **Modelo Ollama exato** — nome, quant, `num_ctx`, CPU vs GPU
5. **Passos numerados** — instalação (sem executar)
6. **Integração octo-cluster**
7. **Trade-offs** vs Cursor (honesto)
8. **Validação** — audit, `ollama run`, Continue tool call, `octo.ps1 -Pipeline scan`
9. **Target files** — se mudanças no repo
10. **Forbidden / out-of-scope**

---

## Critério de sucesso

Com stack OSS, no hardware **real**:

- Abrir octo-cluster no Dev Container
- IA **executa** script (`productivity-audit`, `sync-cursor`, instalar dep)
- LanceDB/grep antes de LLM para contexto grande
- Modelo local responde em tempo **aceitável** (ex.: &lt;30s na 1ª resposta, prompt ~500 tokens, modelo 3B CPU)

**Não é sucesso:** autocomplete rápido, gerar SPA, parity 1:1 com Cursor Composer.

---

## Notas do autor (contexto original)

- Linux: Ubuntu 24.04 LTS (ou Mint se desktop mais simples).
- "Hardware mais forte" = **otimizar VRAM/RAM/CPU** para modelo minimamente funcional — não overclock.
- Cursor 100% OSS: **VSCodium + Continue + Ollama + Dev Container** — analisar GPU fraca **antes** de decidir (feito no snapshot).
- O que importa: **customizar comandos** + IA interagindo com SO (PS1, instalar, analisar pastas, contextos grandes).
- Autocomplete e gerar sites: **irrelevantes**.
