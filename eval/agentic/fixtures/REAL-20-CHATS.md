# Real 20-chat bakeoff (operator + optional SDK)

True harness A/B needs **one Cursor Agent chat per card×arm** (20 chats).  
Toggles in `platform.local.json` do **not** rewrite an already-running chat’s rules — each chat must start **after** the arm overlay is copied.

## Why not one mega-chat

This IDE session already loads full `.cursor/` rules (caveman/ponytail/etc.). Switching `combination_id` mid-chat only labels metrics; it does **not** simulate `nada` vs `compress-on`.

## Fast path A — Cursor SDK (automated)

1. Set user env `CURSOR_API_KEY` (Cursor dashboard / API keys).
2. From repo root:

```powershell
pwsh eval/agentic/fixtures/run-real-20-sdk.ps1
```

(Requires `@cursor/sdk` + network. Script is best-effort; see script header.)

## Fast path B — Manual 20 chats (recommended without API key)

For each row below:

1. Run the **Arm setup** command once per arm (before that arm’s five chats).
2. **New Agent chat** (Composer/Agent).
3. Paste the **Prompt**.
4. Let the agent finish the tiny docs edit.
5. Run **Close measure** (or `/close` if your loop is wired).
6. Do **not** reuse the same chat for another card.

### Arm setup commands

```powershell
# nada
Copy-Item eval\agentic\fixtures\runtime-arms\nada.json contexts\runtime\platform.local.json -Force
pwsh eval\agentic\fixtures\prepare-bakeoff-chat.ps1 -Arm nada -Card BC-01

# baseline
Copy-Item eval\agentic\fixtures\runtime-arms\baseline.json contexts\runtime\platform.local.json -Force

# compress-on
Copy-Item eval\agentic\fixtures\runtime-arms\compress-on.json contexts\runtime\platform.local.json -Force

# octo-full
Copy-Item eval\agentic\fixtures\runtime-arms\octo-full.json contexts\runtime\platform.local.json -Force
```

Before each card, refresh baseline stamp:

```powershell
pwsh eval\agentic\fixtures\prepare-bakeoff-chat.ps1 -Arm <arm> -Card <BC-0N>
```

After each card (from repo root):

```powershell
pwsh eval\metrics\measure-card-lite.ps1 -Ticket "<BC-0N>-<arm>" -CombinationId <arm> -RepoRoot $PWD -BaseRef HEAD -ShipVerdict READY
```

Or use `/close` with ticket `BC-0N-<arm>` if `current_task` is set.

### Chat matrix (paste prompts from fixtures)

| # | Arm | Card | Prompt file |
|---|-----|------|-------------|
| 1–5 | nada | BC-01…05 | `eval/agentic/fixtures/bakeoff-cards/BC-0N.md` |
| 6–10 | baseline | BC-01…05 | same |
| 11–15 | compress-on | BC-01…05 | same |
| 16–20 | octo-full | BC-01…05 | same |

Between arms, restore edited docs if the previous arm already applied the same edit:

```powershell
# only if files were modified and you need a clean target for the next arm
git checkout -- docs/guides/v1-harness-readiness.md eval/metrics/README.md 2>$null
# untracked files: re-copy from git is N/A — keep a backup or re-apply from originals in fixtures notes
```

For **untracked** targets (`v1-harness-readiness.md`, etc.), before each arm copy from a stash folder or undo the one-line edit so the next agent still has work to do.

### Rank

```powershell
pwsh eval\metrics\report.ps1 -CompareCombinations -Last 40
```

## Winner rule

ADR-006: highest mean `harness_score`; no `gate_pass` regression vs `baseline`; ties → lower tokens (or `|diff_net|` if usage skipped).
