# Migração Windows → Ubuntu 24.04 LTS — backup + instalação

**Temporário** — executar na ordem. Após instalar Ubuntu, continuar em [`oss-workstation-setup.md`](../guides/oss-workstation-setup.md) (Fase 2).

**Máquina de referência:** Ryzen 3 2200G · 32 GB RAM · ~446 GB disco · Windows 10 → **Ubuntu 24.04 LTS full disk**

---

## Prompt (opcional — colar no chat antes do backup)

```text
Audite meu PC Windows antes de apagar o sistema. Liste o que falta no backup:

1. Pastas em C:\GitHub\ e outros clones git fora dela
2. Pasta local de secrets (personal-vault) — só caminhos, nunca valores
3. ~/.ssh, chaves GPG, .gitconfig
4. gh auth, tokens em .env / .env.local nos repos
5. Cursor/VS Code settings úteis
6. Inventário: .\scripts\workstation-inventory.ps1 -Json

Saída: checklist pass/fail + destino do backup + riscos se eu instalar Ubuntu hoje.
```

---

## Avisos críticos

| Aviso | Detalhe |
|-------|---------|
| **O pendrive de instalação será apagado** | Gravar Ubuntu no USB **apaga** tudo nele. Backup **não** pode ficar só no pendrive. |
| **Destino do backup** | Outro HD/partição, NAS, ou nuvem **criptografada** (OneDrive com zip senha, etc.). |
| **Full disk** | Instalação “apagar disco e instalar Ubuntu” remove **Windows e todos os dados em C:**. |
| **Secrets** | `personal-vault` e `.env` — copiar para mídia **local criptografada**; nunca commitar no GitHub. |
| **gh / SSH** | No Ubuntu você roda `gh auth login` e pode reutilizar `~/.ssh` se copiar a pasta. |

---

## Fase 1 — Backup (Windows, antes de gravar o USB)

Marque cada item. Destino sugerido: `D:\backup-migracao-2026\` (ajuste se usar outro disco).

### 1.1 Repos Git e projetos

```powershell
# Listar clones
Get-ChildItem C:\GitHub -Directory | Select-Object Name, FullName

# Copiar árvore inteira (inclui .git; demora)
$dest = "D:\backup-migracao-2026\GitHub"
New-Item -ItemType Directory -Force -Path $dest
robocopy C:\GitHub $dest\GitHub /E /XD node_modules .next dist build target /R:2 /W:5
```

**Incluir obrigatoriamente:**

- [ ] `C:\GitHub\octo-cluster` (harness + `state\memory` se quiser índice LanceDB local)
- [ ] Demais pastas em `C:\GitHub\`
- [ ] Outros clones fora de `GitHub\` (buscar: pastas com `.git` no perfil)

```powershell
Get-ChildItem -Path C:\Users\$env:USERNAME -Filter .git -Recurse -Directory -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Parent -Unique | Select-Object FullName
```

### 1.2 Secrets locais (nunca no Git)

- [ ] Pasta **personal-vault** (secrets, `ai-context`, `http/`)
- [ ] Todos os arquivos `.env`, `.env.local`, `*.pem`, credenciais soltas nos repos

```powershell
# Ajuste o caminho da vault se diferente
$vault = "C:\GitHub\personal-vault"   # ou C:\personal-vault
if (Test-Path $vault) {
  robocopy $vault D:\backup-migracao-2026\personal-vault /E /R:2 /W:5
}
```

### 1.3 Identidade dev (SSH, Git, GitHub)

```powershell
$bk = "D:\backup-migracao-2026\dotfiles"
New-Item -ItemType Directory -Force -Path $bk
Copy-Item "$env:USERPROFILE\.ssh" $bk\ssh -Recurse -ErrorAction SilentlyContinue
Copy-Item "$env:USERPROFILE\.gitconfig" $bk\ -ErrorAction SilentlyContinue
Copy-Item "$env:USERPROFILE\.git-credentials" $bk\ -ErrorAction SilentlyContinue
gh auth status 2>&1 | Out-File $bk\gh-auth-status.txt
git config --global --list | Out-File $bk\git-config-global.txt
```

- [ ] Exportar chaves SSH (já em `.ssh`)
- [ ] Anotar e-mail/nome do `git config --global` (para recriar no Ubuntu)

### 1.4 Inventário e harness (referência)

```powershell
cd C:\GitHub\octo-cluster
.\scripts\workstation-inventory.ps1 -Json -OutFile D:\backup-migracao-2026\workstation-inventory.json
.\scripts\productivity-audit.ps1 | Out-File D:\backup-migracao-2026\productivity-audit.txt
```

### 1.5 Opcional mas recomendado

- [ ] Bookmarks navegador (export HTML)
- [ ] Senhas — export do gerenciador (Bitwarden, etc.)
- [ ] `octo-cluster.code-workspace` (gitignored, se existir)
- [ ] Fotos/documentos pessoais em `Documents`, `Desktop`, `Downloads` importantes
- [ ] Licenças/seriais de software pagos (se houver)

### 1.6 Verificação final do backup

```powershell
Get-ChildItem D:\backup-migracao-2026 -Recurse | Measure-Object -Property Length -Sum |
  Select-Object @{N='SizeGb';E={[math]::Round($_.Sum/1GB,2)}}
```

- [ ] Tamanho faz sentido (GitHub + vault + dotfiles)
- [ ] Abrir **uma** pasta copiada e confirmar arquivos legíveis
- [ ] Backup **não** está apenas no pendrive que será gravado

---

## Fase 2 — Criar USB bootável (último passo no Windows)

**Download:** [Ubuntu 24.04.3 LTS Desktop ISO](https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.iso) (64-bit)

**Ferramenta:** [Rufus](https://rufus.ie/) (no Windows)

| Campo Rufus | Valor |
|-------------|-------|
| Dispositivo | Seu pendrive |
| Boot selection | DISCO ou ISO → selecione o `.iso` Ubuntu 24.04 |
| Partição | **GPT** |
| Sistema destino | **UEFI (sem CSM)** |
| Gravação | **Iniciar** → “Write in ISO mode” se perguntar |

⚠️ Isso **apaga o pendrive**. Backup já deve estar em outro lugar.

---

## Fase 3 — Boot pelo USB

1. Pendrive conectado; reinicie o PC.
2. Entrar na BIOS/UEFI — tecla comum: **Del**, **F2** ou **F12** (ASUS frequentemente **F2** / **F8** boot menu).
3. **Boot menu** → escolher o USB (UEFI: nome do pendrive).
4. Tela GRUB Ubuntu → **Try or Install Ubuntu** → **Install Ubuntu**.

Se não bootar:

- BIOS → desabilitar **Fast Boot** temporariamente
- **Secure Boot** → pode deixar On (Ubuntu 24.04 costuma funcionar); se falhar, desligar Secure Boot
- Confirmar **UEFI** (não Legacy/CSM só)

---

## Fase 4 — Instalação Ubuntu (assistente gráfico)

Siga na ordem:

| Passo | Escolha |
|-------|---------|
| Idioma | Português (ou English) |
| Teclado | ABNT2 |
| Atualizações | **Instalar atualizações** + **Instalar software de terceiros** (drivers AMD/Wi‑Fi) |
| Tipo instalação | **Apagar disco e instalar Ubuntu** (full disk — remove Windows) |
| Disco | Um disco ~447 GB → confirmar **Install Now** → Continuar |
| Fuso horário | America/Sao_Paulo |
| Usuário | Nome, senha forte, hostname curto (ex.: `polvo`) |
| Aguardar | ~15–40 min; reinicia sozinho |
| Pós-reboot | **Remover pendrive** quando pedir |

---

## Fase 5 — Primeiros comandos no Ubuntu (terminal)

Abra **Terminal** após login:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl ripgrep build-essential

# Restaurar backup (ajuste caminho se backup veio de HD externo montado)
# Ex.: backup em /media/$USER/DISCO/backups/...
mkdir -p ~/GitHub
# cp -a /caminho/do/backup/GitHub/octo-cluster ~/GitHub/

# SSH / git (se copiou dotfiles)
# mkdir -p ~/.ssh && chmod 700 ~/.ssh
# cp -a /caminho/backup/dotfiles/ssh/* ~/.ssh/
# chmod 600 ~/.ssh/id_*

git clone https://github.com/renanflustosa/octo-cluster.git ~/GitHub/octo-cluster
cd ~/GitHub/octo-cluster
gh auth login   # se gh ainda não instalado, ver oss-workstation-setup.md
```

**Próximo guia (Fase 2 OSS):** [`docs/guides/oss-workstation-setup.md`](../guides/oss-workstation-setup.md)

Ordem lá: Docker Engine → Ollama → VSCodium → Continue → **Reopen in Container**.

---

## Fase 6 — Checklist pós-instalação

- [ ] Internet OK (Wi‑Fi/Ethernet)
- [ ] Resolução de tela OK (driver AMD)
- [ ] Backup restaurado (`~/GitHub`, vault local, `~/.ssh`)
- [ ] `git clone` octo-cluster
- [ ] Seguir `oss-workstation-setup.md` § Phase 2
- [ ] VSCodium → Reopen in Container → `post-create.sh` sem erro
- [ ] `pwsh scripts/productivity-audit.ps1` → `[READY]`

---

## Troubleshooting rápido

| Problema | Ação |
|----------|------|
| Não boota USB | Boot menu UEFI; desativar Fast Boot; testar outra porta USB |
| Tela preta AMD | Na instalação escolher “safe graphics”; depois `sudo ubuntu-drivers install` |
| Sem Wi‑Fi | Cabo Ethernet temporário; ou “Additional drivers” |
| Disco não aparece | Verificar cabo SATA / BIOS AHCI |
| Quero voltar Windows | Só com backup + novo install Windows — por isso Fase 1 é obrigatória |

---

## Ordem resumida (executar hoje)

```text
1. Backup → D:\ ou outro disco (NÃO só o pendrive)
2. Verificar backup
3. Rufus → gravar Ubuntu 24.04 ISO no pendrive
4. Reiniciar → boot USB → Install → apagar disco
5. Ubuntu desktop → clone octo-cluster → oss-workstation-setup.md
```

**Tempo estimado:** backup 30–90 min · USB + install 40–60 min · stack OSS 1–2 h.
