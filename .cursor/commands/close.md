# close

**Agent mode** — archive ticket, compact memory, reindex. Model: `composer-2.5-fast`.

**Discover (once per thread):**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline close -Action discover
```

Read `PIPELINE_SKILL` once.

**Run:**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline close -Action run
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo.ps1" -Pipeline close -Action run -Ticket "<optional>"
```

Ticket defaults from `current_task.md` CARD when `-Ticket` is omitted.

Do **not** pass `-ScriptArgs @{ ... }` through `powershell -File` (hashtables do not cross process boundaries). Use flat `-Ticket` or `-ScriptArgsJson '{"Ticket":"<id>"}'`.

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
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:OCTO_CLUSTER/octo-run.ps1" -RelativePath eval/metrics/measure-card-lite.ps1 -Ticket "<ticket>" -RepoRoot "<git-root>" -Arm ponytail-lite -ShipVerdict READY
```

**Playbook:** resolve `PIPELINE_SKILL` from discover output.
