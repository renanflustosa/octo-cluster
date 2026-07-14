# OSS workstation setup — Ubuntu 24.04 + Ollama CPU

100% open-source dev stack for octo-cluster: **VSCodium + Continue + Ollama + Dev Container**.

Hardware reference (Ryzen 3 2200G, 32 GB RAM, Vega 8 iGPU): use **CPU inference only** — ignore GPU/ROCm on integrated AMD.

See also: [onboarding.md](./onboarding.md) (Dev Container entry), [plan-oss-workstation.md](../temp/plan-oss-workstation.md) (model prompt).

---

## Phase 1 — Backup and Ubuntu install (manual)

Complete **before** wiping Windows.

### 1.1 Backup checklist

- [ ] `C:\GitHub\` (all clones, especially `octo-cluster`)
- [ ] Local gitignored vault / secrets (copy to external drive — never commit)
- [ ] `~/.ssh/` and GPG keys
- [ ] `gh auth status` — re-run `gh auth login` on Ubuntu after install
- [ ] Browser bookmarks, password manager export
- [ ] Optional: `.\scripts\workstation-inventory.ps1 -Json` → save JSON for comparison

### 1.2 Ubuntu 24.04 LTS (full disk)

1. Create boot USB: [Ubuntu 24.04 LTS desktop](https://ubuntu.com/download/desktop)
2. Boot USB → **Erase disk and install Ubuntu** (single boot, no Windows)
3. Enable **Install third-party software** (AMD firmware)
4. Create user; enable **disk encryption** only if you accept recovery risk
5. Reboot; run updates:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl ripgrep build-essential
```

6. Performance (optional):

```bash
sudo apt install -y cpupower
sudo cpupower frequency-set -g performance 2>/dev/null || true
```

### 1.3 Clone octo-cluster

```bash
mkdir -p ~/GitHub
git clone https://github.com/renanflustosa/octo-cluster.git ~/GitHub/octo-cluster
cd ~/GitHub/octo-cluster
```

---

## Phase 2 — OSS stack (run in order)

### 2.1 Docker Engine

Official steps: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

Quick path (after adding Docker apt repo per docs):

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo usermod -aG docker "$USER"
newgrp docker
docker run hello-world
```

### 2.2 Ollama + model (CPU)

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Tune for 4-thread CPU / 32 GB RAM:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_NUM_THREADS=4"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=5m"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Pull default model (~2 GB):

```bash
ollama pull qwen2.5-coder:3b
ollama run qwen2.5-coder:3b "Reply OK if you can read this."
```

Optional upgrade (slower on 4T CPU): `ollama pull qwen2.5-coder:7b`

### 2.3 VSCodium + extensions

```bash
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
  | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/vscodium.gpg >/dev/null
echo 'deb [ signed-by=/etc/apt/trusted.gpg.d/vscodium.gpg ] https://download.vscodium.com/debs vscodium main' \
  | sudo tee /etc/apt/sources.list.d/vscodium.list
sudo apt update && sudo apt install -y codium
```

Extensions (Open VSX inside VSCodium):

| Extension | ID |
|-----------|-----|
| Dev Containers | `ms-vscode-remote.remote-containers` |
| Continue | `Continue.continue` |
| PowerShell | `ms-vscode.powershell` |
| YAML | `redhat.vscode-yaml` |

### 2.4 Continue config

Copy template from repo:

```bash
mkdir -p ~/.continue
cp ~/GitHub/octo-cluster/adapters/continue/config.json ~/.continue/config.json
```

**Inside Dev Container** (Ollama on host), edit `apiBase`:

```json
"apiBase": "http://host.docker.internal:11434"
```

In Continue settings: enable **terminal / command** tools (Agent mode) so the model can run `pwsh scripts/productivity-audit.ps1` with your approval.

Disable tab autocomplete in Continue if not needed (not a project priority).

### 2.5 octo-cluster local bootstrap

1. Clone `octo-cluster` and run `./install.sh` (or `pwsh install.ps1` on Windows)
2. `pwsh scripts/sync-cursor.ps1`
3. `cd engine/context-engine && bun run validate octo-cluster`

Verify:

```bash
pwsh octo.ps1 -Pipeline scan -Action discover
pwsh scripts/productivity-audit.ps1
```

**Note:** Dev Container is not shipped in this repo — use native bootstrap above.

---

## Phase 3 — octo-cluster integration

| Goal | How |
|------|-----|
| Custom commands | Read `domains/core/commands/`; run via `pwsh octo.ps1 -Pipeline <phase> -Action run` |
| Large context | **First** `cd engine/context-engine && bun run search octo-cluster --query "..."`; then ask Continue |
| Memory / RAG | LanceDB index via harness; `bun run index-incremental octo-cluster --kind memory` |
| Git gates | `boundary-audit.ps1` via pre-commit hooks (installed by post-create) |
| OS agent | Continue terminal → `pwsh`, `bash`, `git`, `bun` — approve each command |

### Context flow (COST 0 first)

```text
User request → grep / LanceDB search → small chunks to LLM → terminal exec if needed
```

---

## Validation checklist (/ship)

Run on Ubuntu after full setup:

```bash
docker run hello-world
cd ~/GitHub/octo-cluster/engine/context-engine && bun run validate octo-cluster
cd ~/GitHub/octo-cluster && pwsh scripts/productivity-audit.ps1
cd ~/GitHub/octo-cluster && pwsh scripts/boundary-audit.ps1
time ollama run qwen2.5-coder:3b "Summarize octo-cluster in one sentence."
```

Continue manual test: ask *"Run pwsh scripts/productivity-audit.ps1 and show the result"* — approve terminal execution.

**Done when:** productivity audit `[READY]`, validate 0 failed, Ollama first reply under ~30s for short prompt, Continue runs at least one harness script.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Continue cannot reach Ollama in container | Set `apiBase` to `http://host.docker.internal:11434`; ensure Ollama runs on host (`systemctl status ollama`) |
| Docker permission denied | `sudo usermod -aG docker $USER` → log out/in |
| post-create fails on sync | Ensure `pwsh` in container (Dev Container feature); re-run `pwsh scripts/sync-cursor.ps1` |
| Ollama slow | Stay on `qwen2.5-coder:3b`; close browsers; `OLLAMA_MAX_LOADED_MODELS=1` |
| GPU / ROCm | **Not supported** for Vega 8 APU — stay CPU-only |

---

## Out of scope

- Tab autocomplete / Tabby
- Windows / WSL maintenance
- Cursor proprietary IDE
- GPU tuning (ROCm)
