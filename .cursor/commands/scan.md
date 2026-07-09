# scan

**Skip** if scan done this chat — use prior output. Model: session default (Auto).

**User message = ticket source:** `/scan TICKET-123 description` — no carry-forward paste.

**Discover (once per thread):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline scan -Action discover
```

Read `PIPELINE_SKILL` once.

**Harness (run)** — pass ticket id so pack providers can resolve the card (tracker-agnostic):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline scan -Action run -Ticket "<TICKET>"
```

Optional: `-TicketUrl "<https://…/ISSUE-123/…>"` for slug title when the pack provider has no API key.

If harness prints `TICKET_CARD=<path>`, read that JSON before scoping (title, description, url). If no providers / no card file, use the user message only.

Then as needed:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo-domain.ps1" -Name context-search -ScriptArgsJson '{"Query":"<terms>"}'
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo-domain.ps1" -Name read-gate -Path "<file>"
```

On Linux/macOS you may use `./scripts/octo` instead of `pwsh ... octo.ps1` when `OCTO_CLUSTER` is set.

Update `state/memory/<profile>/current_task.md` (≤200 tokens).

**Usage baseline (best-effort, for token metrics at `/close`):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo-run.ps1" -RelativePath eval/metrics/stamp-usage-baseline.ps1 -Ticket "<TICKET>" -Profile "<profile>"
```

**Output:** Objective, Scope, Git, Risks, Next — **≤6 bullets**.

**Playbook:** resolve `PIPELINE_SKILL` from discover output (typically `core-adaptive-loop` or pack overlay).
