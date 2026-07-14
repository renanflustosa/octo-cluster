# Add a new capability pack / child context

Step-by-step guide for adding a company or project to `octo-cluster`.

---

## 1. Execution context

Add `contexts/runtime/my-company.json`:

```json
{
  "id": "my-company",
  "workspace_id": "my-company-main",
  "enabled_capability_packs": ["core", "my-company"],
  "memory_profile": "my-company",
  "docs_root": "domains/my-company/docs",
  "script_prefix": "my-company",
  "ship_repositories": ["my-product-api", "my-product-web"]
}
```

| Field | Purpose |
|-------|---------|
| `enabled_capability_packs` | Which packs merge at runtime (`core` always first) |
| `memory_profile` | Default `state/memory/<profile>/` |
| `docs_root` | Pack docs for context-engine (`packDocsRoot`) |
| `script_prefix` | Child script naming: `domains/<pack>/scripts/<prefix>-<gate>.ps1` |
| `ship_repositories` | Repo ownership filter for pack providers/skills |

Register the pack in [`capabilities/registry.yaml`](../capabilities/registry.yaml):

```yaml
packs:
  my-company:
    path: capabilities/my-company
```

---

## 2. Capability pack layout

Copy scaffold:

```
capabilities/_template/   →   capabilities/my-company/
```

Minimum layout:

```
capabilities/my-company/
├── scan/manifest.yaml      # skill: skill.md
├── model/manifest.yaml
├── ship/manifest.yaml
│   └── providers/          # optional gate scripts
├── close/manifest.yaml
└── skills/                 # auxiliary triggers (optional)
    ├── manifest.yaml
    └── branch-and-scope/skill.md
```

Each pipeline `manifest.yaml`:

```yaml
id: my-company-scan
pipeline: scan
skill: skill.md
```

Place playbook content in `capabilities/my-company/<pipeline>/skill.md` (canonical). Do **not** rely on syncing pack skills to `.cursor/skills/`.

Optional: child packs may extend daily bootstrap via `domains/<pack>/scripts/<prefix>-start-workspace.ps1` (invoked internally by `invoke-domain-script -Name start-workspace` — not a user-facing pipeline).

---

## 3. Legacy child domain (rules, hooks, scripts)

```
domains/my-company/
├── domain.json
├── README.md
├── docs/
├── rules/
├── hooks/            # optional
└── scripts/          # <script_prefix>-*.ps1 wrappers
```

Core loop commands sync from `domains/core/commands/` automatically. Do **not** duplicate core commands or core skills.

| Folder | Add when… |
|--------|-----------|
| `rules/` | Repo globs, vocabulary, structural budgets |
| `hooks/` | Cursor or git hooks specific to this pack |
| `scripts/` | Gate/bootstrap scripts referenced by capability providers |
| `docs/` | Workflow, repos, architecture, glossary |

Optional legacy shims: `domains/my-company/skills/*/SKILL.md` redirecting to `capabilities/my-company/...` (for old paths only).

---

## 4. Workspace file

Create a `.code-workspace` in your **consumer-managed** location (local vault, product mono-repo, etc.) — not in this repository:

```json
{
  "folders": [
    { "path": "../../octo-cluster", "name": "octo-cluster" },
    { "path": "../local-secrets", "name": "local-secrets" }
  ],
  "settings": {
    "terminal.integrated.env.windows": {
      "OCTO_CLUSTER": "${workspaceFolder:octo-cluster}",
      "AI_EXECUTION_CONTEXT": "my-company"
    }
  }
}
```

Document the mapping in your consumer docs and [`docs/index.md`](./index.md) (context JSON only — no workspace paths in this repo).

---

## 5. Sync and discover

```powershell
cd "$([Environment]::GetEnvironmentVariable('OCTO_CLUSTER','User'))"
$env:AI_EXECUTION_CONTEXT = "my-company"
.\scripts\sync-cursor.ps1 -Domain my-company
.\scripts\invoke-pipeline.ps1 -Pipeline scan -Action discover
```

Verify:

- `.cursor/domain.manifest.json` — `skillsPolicy: core-only`
- `.cursor/capabilities-skills.json` — pipeline skills for your context
- `PIPELINE_SKILL` points to `capabilities/my-company/.../skill.md` when repo is in `ship_repositories`

---

## 6. Memory and RAG (optional)

| Concern | Pattern |
|---------|---------|
| **Agent memory** | `state/memory/<profile>/` |
| **Semantic search** | Shared [`engine/context-engine/`](../engine/context-engine/) — `docs_root` from context JSON |
| **Secrets** | Local gitignored vault (e.g. `.env.local`) — never commit credentials |

---

## 7. Checklist

- [ ] `contexts/runtime/<id>.json` with unique `id`
- [ ] Pack registered in `capabilities/registry.yaml`
- [ ] Pipeline manifests + `skill.md` under `capabilities/<pack>/`
- [ ] Workspace sets `AI_EXECUTION_CONTEXT`
- [ ] No duplication of `domains/core/` assets
- [ ] Global docs remain company-agnostic
- [ ] Sync run; `capabilities-skills.json` updated
- [ ] Entry in [`docs/index.md`](./index.md) (runtime context only)

---

## Rename a scaffold

1. Rename `domains/company2/` → `domains/my-company/`
2. Rename `capabilities/` pack if created; update `contexts/runtime/*.json` and registry
3. Rename workspace file; set `AI_EXECUTION_CONTEXT`
4. Run sync with the new id
