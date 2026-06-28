# Onboarding — octo-cluster (platform)

Guia completo para novo dev. Resumo rápido: [README.md](../README.md).

## Pré-requisitos

| Item | Como |
|------|------|
| Git | [git-scm.com](https://git-scm.com/download/win) — manual |
| Bun, gh, ripgrep | `.\install.ps1` (download direto, **sem winget**) |
| Go (opcional) | `.\scripts\install-go.ps1` — [go.dev](https://go.dev/dl/) |
| Ollama (opcional) | `.\scripts\install-ollama.ps1` |
| WSL2 Ubuntu (opcional) | `.\scripts\install-wsl.ps1` |
| Docker Desktop (opcional) | `.\scripts\install-docker.ps1` |
| Cursor | Abrir `octo-cluster.code-workspace` |

Após install: `gh auth login` (uma vez). Verificar: `.\scripts\productivity-audit.ps1`

## Workspace

`octo-cluster.code-workspace` — single-root com o harness CORE.

Opcional: adicione pastas irmãs (seu app, vault local gitignored) no workspace multi-root.

Env no terminal:

- `AI_EXECUTION_CONTEXT=platform`
- `OCTO_CLUSTER` → raiz do clone octo-cluster

## Loop CORE (opcional)

```text
/start-workspace → /scan → /model → Execute plan → /ship → /close
```

| Fase | Harness |
|------|---------|
| start-workspace | `invoke-pipeline -Pipeline start-workspace -Action run` |
| scan | bootstrap + `current_task.md` (≤200 tokens) |
| model | Plan sem código; Execute só arquivos do plano |
| ship | verify (repo-policy) + gates + git policy |
| close | archive + reindex memory |

**Discover (1× por thread):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline scan -Action discover
```

## Issue tracker (Linear / Jira / …)

Contexto **platform**: `/scan` **não cria** card — passe o ID (`/scan PROJ-123 descrição`). Use MCP ou API do seu tracker para ler/atualizar issues.

Capability packs privados podem adicionar roteamento e gates — ver [add-child-context.md](./add-child-context.md).

## Token economy (COST 0 first)

```text
[COST 0]  hooks, sync, git, gh, bun test, LanceDB, grep, gate scripts
[COST LOW] Ask mode, review escopado
[COST HIGH] Plan + Execute, /ship quando reprodução é difícil
```

Regras CORE:

- 1 chat = 1 work item
- `@` ≤ 3 · Read ≤ 300 linhas
- grep antes de Glob/Read amplo
- **caveman** lite em status (off em `/model`, `/ship`, security)
- **ponytail-lite** escada de implementação mínima

**Medir melhoria:** [`eval/metrics/README.md`](../eval/metrics/README.md) · [`docs/metrics-kernel.md`](./metrics-kernel.md)

## Harness level (platform)

| Camada | Status |
|--------|--------|
| install + audit | OK |
| invoke-pipeline + capabilities | OK |
| repo-policies verify | OK |
| LanceDB memory + code (cap 80) | OK |
| Cursor hooks | **vazio** (platform) |

## Cursor hooks

Platform: `domains/core/hooks/hooks.platform.json` → `{}` (zero bloqueio Write).

Child domains merge hooks via `sync-cursor.ps1 -Domain <pack>`.

Se Write for bloqueado: `.\scripts\sync-cursor.ps1` + `.\scripts\validate-cursor-hooks.ps1`

## Extensões recomendadas

PowerShell · YAML — ver `octo-cluster.code-workspace`

## Próximo passo

Scaffold seu capability pack: [add-child-context.md](./add-child-context.md)
