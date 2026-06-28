# close

**Agent mode** — archive ticket, compact memory, reindex. Model: session default (Auto).

**Discover (once per thread):**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline close -Action discover
```

Read `PIPELINE_SKILL` once.

**Run:**

```powershell
powershell -File $env:OCTO_CLUSTER\scripts\invoke-pipeline.ps1 -Pipeline close -Action run -ScriptArgs @{
  Ticket = "<optional>"
}
```

Ticket defaults from `current_task.md` CARD: when omitted.

**Actions:**
- Archive ticket to `state/memory/<profile>/tickets/`
- Compact memory via context-engine
- Incremental LanceDB reindex
- Wipe `current_task.md`

**Output:** ≤5 lines. Start **NEW chat** → `/scan <next-ticket>`.

**Optional metrics (automatic when baseline exists):**

Close runs `measure-card-lite.ps1` → SQLite `state/metrics/metrics.db` (tokens delta + diff LOC).

Manual override:

```powershell
powershell -File $env:OCTO_CLUSTER\eval\metrics\measure-card-lite.ps1 `
  -Ticket "<ticket>" -RepoRoot "<git-root>" -Arm ponytail-lite -ShipVerdict READY
```

**Playbook:** resolve `PIPELINE_SKILL` from discover output.
