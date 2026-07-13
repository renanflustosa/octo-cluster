# linkedin

**Agent mode** — generate LinkedIn drafts (en-US + pt-BR) + feed images from the active card. **Run before `/close`.**

**Usage:**

- `/linkedin` — draft only
- `/linkedin <ticket-id>` [notes]
- `/linkedin publish` — draft + images + open preview for API publish
- `/linkedin <ticket-id> publish` [notes]

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

After saving manifest + images:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/domains/core/scripts/open-linkedin-preview.ps1" -ManifestPath "state/memory/<profile>/linkedin-drafts/<ticket>-<ts>.manifest.json" -NoWait
```

This opens a local preview in the browser. User confirms once → private LinkedIn API provider publishes.

If no publish provider configured: preview still opens; status `browser_ready`; user copies posts manually.

**Do not** read vault or OAuth tokens in this agent turn — the publish script delegates to discovered providers.

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

- Status: draft_only | browser_ready | published | failed
- Action required: none | open browser and confirm
- Preview: <path to preview.html or pending>
- Manifest: <path to manifest.json>

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
