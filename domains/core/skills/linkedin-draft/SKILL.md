---
name: linkedin-draft
description: Generate bilingual LinkedIn drafts (en-US + pt-BR) with images from an active harness card. Use when /linkedin runs. Simple language plus technical open-knowledge layer; ethical reach hooks; semi-auto publish via private API provider.
---

# LinkedIn draft (v2)

Generate two LinkedIn posts + two feed images from the active card. Run **before** `/close`.

## Role

Growth technical writer + product engineer for **Octo Cluster** — MIT, local-first, IDE-agnostic harness. Each card is a shareable story for a **broad dev audience** (curious about AI, not only senior engineers).

## Brand voice

- **Free and democratic** — open knowledge, reproducible workflows, no gatekeeping.
- **Build in public** — concrete changes, not hype.
- **Simple first** — plain language hooks; explain acronyms when used (e.g. COST-0 = zero API cost).
- **Evidence-based** — only facts from sources (git, card, chat, metrics).

Card work leads; Octo Cluster framing supports the lesson — not a product pitch.

## Dual-layer post template (each language)

1. **Hook** (1 line) — short, scroll-stopping, **simple words**.
2. **Simple paragraph** (2–3 sentences) — what happened and why a non-expert should care.
3. **What we learned** — 2–3 bullets (`•`); technical, open-knowledge.
4. **What we shipped** — 2–3 bullets; outcome-oriented, card-scoped.
5. **Why it matters** — 1 sentence; OSS, reproducibility, democratization.
6. **Question CTA** — invite comments.
7. **Hashtags** — 3–5 on the last line (also list separately in Metadata).

## Hashtag playbook

Anchor tags to the card topic — no irrelevant viral tags.

| Tier | en-US examples | pt-BR examples |
|------|----------------|----------------|
| Broad | `#OpenSource` `#AI` `#DeveloperTools` | `#OpenSource` `#IA` `#FerramentasDev` |
| Niche | `#BuildInPublic` `#AIEngineering` `#DevEx` | `#BuildInPublic` `#EngenhariaDeSoftware` |

Max 5 tags per post. Prefer relevance over volume.

## LinkedIn formatting

- First line must work before "see more" (≤120 chars ideal).
- Blank line between sections; scannable bullets.
- ≤3000 characters per post.
- Public links in Metadata only (not body), unless one public URL adds clear value.

## Bilingual rules

| Locale | Style |
|--------|--------|
| **en-US** | Direct, professional, accessible dev LinkedIn |
| **pt-BR** | Conversational technical Portuguese — not mirrored English |

Same facts; different hooks, CTAs, and hashtags.

## Image generation (2 images: EN + PT)

Use **GenerateImage** twice (once per locale overlay).

| Field | Value |
|-------|-------|
| Aspect ratio | `16:9` (LinkedIn feed) |
| Overlay text | ≤8 words; hook from card in target language |
| Style | Minimal flat vector, dark navy `#0a1628`, bold white headline, high contrast, mobile-readable |
| Branding | Optional `reference_image_paths: ["assets/branding/logo-primary.png"]` |
| Content | Reflect card insight — **no invented metrics or numbers** |
| Filename | `<ticket>-en-<YYYYMMDD-HHmm>.png` and `<ticket>-pt-<YYYYMMDD-HHmm>.png` |
| Save dir | `state/memory/<profile>/linkedin-drafts/` |

**Image prompt template:**

```text
LinkedIn feed banner, minimal flat vector, dark navy background (#0a1628), bold white headline text: "<overlay>". Subtle open-source tech aesthetic, high contrast, readable on mobile. Small abstract terminal or code motif. No fake statistics. No company logos except generic OSS motif.
```

## Manifest JSON

After generating posts and images, write `state/memory/<profile>/linkedin-drafts/<ticket>-<YYYYMMDD-HHmm>.manifest.json`:

```json
{
  "ticket": "<id>",
  "profile": "<profile>",
  "timestamp": "<YYYYMMDD-HHmm>",
  "posts": { "en": "<full EN text without duplicating hashtag line if already in post>", "pt": "<full PT text>" },
  "images": { "en": "<absolute or repo-relative path>", "pt": "<path>" },
  "hashtags": { "en": ["#OpenSource", "..."], "pt": ["#OpenSource", "..."] },
  "public_links": ["https://github.com/renanflustosa/octo-cluster"]
}
```

## Sanitization

Strip or omit silently:

- Private tracker URLs and opaque issue IDs
- Employer, client, product, vault, workspace names
- Credentials, API keys, internal codenames
- Metrics not in session sources

**Public links allowed:** GitHub repo, public docs, public PR URLs.

## Metrics

Include token/diff numbers **only** when `measure-card-lite` provided them. Never put numbers on generated images.

## Output contract

```markdown
## LinkedIn draft — EN-US

<simple paragraph + technical bullets + question + hashtags>

## LinkedIn draft — PT-BR

<simple paragraph + technical bullets + question + hashtags>

## Images

- EN: state/memory/<profile>/linkedin-drafts/<ticket>-en-<ts>.png
- PT: state/memory/<profile>/linkedin-drafts/<ticket>-pt-<ts>.png

## Publish (semi-auto) — two-turn chat flow

**Turn 1** (`/linkedin publish`): run `show-linkedin-preview.ps1`; status `preview_ready`; stop and ask user to reply `publicar`.

**Turn 2** (user says `publicar`): run `invoke-linkedin-publish.ps1 -Confirm -AllLocales`.

Publish block in agent output:

- Status: draft_only | preview_ready | published | partial | failed | manual_required
- Action required: none | reply `publicar` | set LINKEDIN_TOKEN_FILE
- EN: ok | failed — reason
- PT: ok | failed — reason
- Manifest: state/memory/\<profile\>/linkedin-drafts/\<ticket\>-\<ts\>.manifest.json
- Result: state/memory/\<profile\>/linkedin-drafts/\<ticket\>-\<ts\>-publish-result.json

Preflight checks (no secret reads): publish provider discovered; `LINKEDIN_TOKEN_FILE` set and file exists.

Optional legacy browser preview: `open-linkedin-preview.ps1 -Browser` only when user requests `browser`.

## Metadata

- Card: <id or sanitized title>
- Sources: <list or partial>
- Hashtags EN: <list>
- Hashtags PT: <list>
- Public links only: <urls or none>
```

## Quality bar

- [ ] Simple-language hook and paragraph present in both locales.
- [ ] Technical bullets distinct from implementation bullets.
- [ ] Card-specific content — not generic Octo marketing.
- [ ] Two images generated and paths recorded in manifest.
- [ ] Consumer boundary clean.

## Do not

- Read secrets, vault paths, or MCP tokens in the agent turn (publish provider reads token via env).
- Invent metrics or engagement claims.
- Expand to other social networks.
- Promise 100% autopost without user confirm in preview.
