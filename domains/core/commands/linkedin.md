# linkedin

**Agent mode** — generate LinkedIn drafts (en-US + pt-BR) + feed images from the active card. **Run before `/close`.**

**Usage:**

- `/linkedin` — draft only
- `/linkedin <ticket-id>` [notes]
- `/linkedin publish` — draft + images + **chat preview** (reply `publicar` to publish both locales)
- `/linkedin <ticket-id> publish` [notes]
- `/linkedin publish browser` — optional legacy HTML preview (debug only)

`/close` wipes `current_task.md`. If `CARD: (none)` and no ticket arg, stop with a short error.

**Read once:** `domains/core/skills/linkedin-draft/SKILL.md`

---

## Collect context (in order)

1. **Resolve ticket** — arg from user message, else `CARD:` in `state/memory/<profile>/current_task.md` (see `domains/core/scripts/core-task-memory.ps1`). Profile from execution context or default `octo-cluster`.
2. **Card JSON** — `state/memory/<profile>/ticket-card.json` if exists.
3. **Current task** — `state/memory/<profile>/current_task.md`.
4. **Git** — `git diff`, `git diff --stat`, `git log -5 --oneline` in active repo.
5. **Chat** — discoveries, decisions, blockers from this session.
6. **User notes** — optional text (exclude the word `publish` from notes).
7. **Metrics (optional)** — only if `measure-card-lite` ran this session.

**Fallbacks:** no `ticket-card.json` → task + chat + git; partial card → `Sources: partial`; private URLs → omit from post body.

---

## Generate posts

Follow `linkedin-draft` skill:

- **Dual layer:** simple-language hook/paragraph + technical open-knowledge bullets.
- en-US and pt-BR as **native variants** (not literal translation).
- Anchor in this card's work — no generic fluff.
- ≤3000 characters per post.
- List hashtags separately in Metadata per locale.

---

## Generate images

1. Derive overlay text per locale (≤8 words) from the card hook.
2. Call **GenerateImage** twice (`aspect_ratio: "16:9"`).
3. Optional reference: `assets/branding/logo-primary.png`.
4. Save to `state/memory/<profile>/linkedin-drafts/<ticket>-en-<YYYYMMDD-HHmm>.png` and `-pt-<ts>.png`.

---

## Persist

1. Write markdown draft: `state/memory/<profile>/linkedin-drafts/<ticket>-<YYYYMMDD-HHmm>.md` (full output contract below).
2. Write manifest JSON: `state/memory/<profile>/linkedin-drafts/<ticket>-<YYYYMMDD-HHmm>.manifest.json` (schema in skill).

Create the directory if missing (`state/**` is gitignored).

---

## Publish (when message contains `publish`)

Two-turn chat flow — **no browser by default**.

### Turn 1 — preview (`/linkedin publish`)

After saving manifest + images, run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/domains/core/scripts/show-linkedin-preview.ps1" -ManifestPath "state/memory/<profile>/linkedin-drafts/<ticket>-<ts>.manifest.json"
```

Show a **short chat preview** (~15–25 lines):

- Hook EN + hook PT (first line of each post)
- Image basenames
- Preflight status (`PREFLIGHT_OK`, `PREFLIGHT_REASON`)
- Instruction: **Responda `publicar` para publicar EN e PT**

Status: `preview_ready`. If `PREFLIGHT_OK=false`, explain fix (e.g. set `LINKEDIN_TOKEN_FILE` to vault token path) — **do not read secrets**.

**Stop and wait** for user confirmation. Do not publish in turn 1.

### Turn 2 — publish (user replies `publicar` or `approve`)

Only after explicit user confirmation:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/domains/core/scripts/invoke-linkedin-publish.ps1" -ManifestPath "state/memory/<profile>/linkedin-drafts/<ticket>-<ts>.manifest.json" -Confirm -AllLocales
```

Report per-locale result from JSON output (`en` / `pt`: ok or error). Status: `published` | `partial` | `failed` | `manual_required`.

### Optional browser preview (legacy/debug)

When user message includes `browser`:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/domains/core/scripts/open-linkedin-preview.ps1" -ManifestPath "..." -Browser
```

**Do not** read vault or OAuth tokens in the agent turn — publish scripts delegate to discovered providers.

---

## Output contract

```markdown
## LinkedIn draft — EN-US

<full post, ≤3000 chars>

## LinkedIn draft — PT-BR

<full post, ≤3000 chars>

## Images

- EN: <path>
- PT: <path>

## Publish (semi-auto)

- Status: draft_only | preview_ready | published | partial | failed | manual_required
- Action required: none | reply `publicar` to confirm | set LINKEDIN_TOKEN_FILE
- EN: ok | failed — <reason>
- PT: ok | failed — <reason>
- Manifest: <path to manifest.json>
- Result: <path to publish-result.json after publish>

## Metadata

- Card: <id>
- Sources: <list>
- Hashtags EN: <list>
- Hashtags PT: <list>
- Public links only: <urls or none>
```

---

## Rules

- Never read `secrets/`, vault paths, or MCP tokens in the agent turn.
- Never paste private consumer names or private issue IDs into posts or committed files.
- Public links only in Metadata.
- Provider publish only via `invoke-linkedin-publish.ps1` discovery — not inline API calls.
- Do not expand to other social networks.
