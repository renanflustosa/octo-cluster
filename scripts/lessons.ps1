#Requires -Version 7.0
<#
.SYNOPSIS
  Automatic lessons from Bash "failed -> worked" pairs, for Claude Code hooks. Evidence only, no LLM.
.DESCRIPTION
  Hook actions read the hook JSON on stdin (wired by hooks/hooks.json through hooks/lessons.sh):
    fail  PostToolUseFailure/Bash: remember the failed command for this session.
    ok    PostToolUse/Bash: pair a recent failure with a similar command that worked; check overrides.
    pre   PreToolUse/Bash: deny, once per session, a command an active lesson warns about, naming the fix.
    edit  PostToolUse/Edit|Write: drop this session's pending failures (the fix was in the code).
  Manual actions: list | forget <key>.

  Why it does not compound errors, bloat context or keep stale rules:
  - A lesson is born only from a real exit code != 0 followed, with no file edit in between, by a
    similar command that exited 0. It turns active only when the same pair shows up in 2 sessions.
  - Nothing is loaded at session start; a lesson reaches Claude only when its command is about to run.
  - One lesson per command key (newest evidence replaces it), at most 100, dropped after 60 days
    unused, when the warned command works again, or after 2 successful overrides.
  Data lives in $env:CLAUDE_PLUGIN_DATA (plugin) or ~/.octo-cluster, never in a repo. Commands that
  look like they carry secrets are never stored.
.EXAMPLE
  pwsh -File scripts/lessons.ps1 list
  pwsh -File scripts/lessons.ps1 forget 'npx tsc'
#>
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('fail', 'ok', 'pre', 'edit', 'list', 'forget')]
    [string]$Action,
    [Parameter(Position = 1)]
    [string]$Key,
    [string]$DataDir = $(if ($env:CLAUDE_PLUGIN_DATA) { $env:CLAUDE_PLUGIN_DATA } else { Join-Path $HOME '.octo-cluster' })
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$PromoteAfterSessions = 2
$RetireAfterOverrides = 2
$PendingTtlSec = 15 * 60
$SessionTtlSec = 24 * 3600
$ExpireSec = 60 * 86400
$MaxLessons = 100
$MaxPending = 5
$MinSimilarity = 0.25      # failed vs. worked command: same tool, same target
$SameFixSimilarity = 0.6   # two fixes count as the same lesson evidence
# Exploration commands exit non-zero for "nothing found"; that is not a lesson about the environment.
$IgnoredPrograms = @('ls', 'cat', 'head', 'tail', 'find', 'grep', 'egrep', 'rg', 'test', '[', '[[', 'echo',
    'printf', 'which', 'where', 'command', 'type', 'wc', 'diff', 'stat', 'true', 'false', 'cd', 'exit')
$SecretPattern = '(?i)token|secret|passw|api[_-]?key|apikey|authorization|bearer|cookie|credential|://[^/\s:@]+:[^/\s@]+@|[A-Za-z0-9_\-]{32,}|(?:^|\s)-p\S'

$LessonsPath = Join-Path $DataDir 'lessons.json'
$SessionsPath = Join-Path $DataDir 'sessions.json'
$KeysPath = Join-Path $DataDir 'keys.txt'      # grep -E prefilter used by hooks/lessons.sh
$PendingFlag = Join-Path $DataDir 'pending'    # exists while any session has a pending failure

function Get-Now { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

function Read-HookInput {
    [Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw.Trim()) { throw 'lessons.ps1: expected the hook JSON on stdin' }
    $raw | ConvertFrom-Json -AsHashtable
}

function Read-JsonFile([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
        if ($value) { return $value }
    }
    @{}
}

function Write-JsonFile([string]$Path, $Value) {
    $tmp = "$Path.$PID.tmp"
    ConvertTo-Json -InputObject $Value -Depth 8 -Compress | Set-Content -LiteralPath $tmp -Encoding utf8NoBOM
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Get-Words([string]$Segment) {
    $words = @([regex]::Matches($Segment, '"[^"]*"|''[^'']*''|\S+') | ForEach-Object Value)
    $i = 0
    while ($i -lt $words.Count -and $words[$i] -match '^[A-Za-z_][A-Za-z0-9_]*=') { $i++ }  # VAR=value prefix
    , @($words | Select-Object -Skip $i)
}

# The lesson is about the first real command: skip `cd dir &&` and environment-only segments.
function Get-Segment([string]$Command) {
    foreach ($part in ($Command -split '\s*(?:&&|\|\||;|\||\r?\n)\s*')) {
        $words = Get-Words $part
        if ($words.Count -and $words[0] -notin @('cd', 'pushd')) { return ($words -join ' ') }
    }
    ''
}

function Get-Program([string]$Word) {
    $base = ($Word.Trim('"', "'") -split '[\\/]')[-1].ToLowerInvariant()
    $base -replace '\.(exe|cmd|bat)$', ''
}

function Get-Key([string]$Segment) {
    $words = Get-Words $Segment
    if (-not $words.Count) { return '' }
    $program = Get-Program $words[0]
    $sub = $words | Select-Object -Skip 1 | Where-Object { $_ -cmatch '^[a-z][a-z0-9._:-]*$' } | Select-Object -First 1
    if ($sub) { "$program $sub" } else { $program }
}

function Get-TokenSet([string]$Segment) {
    $set = [System.Collections.Generic.HashSet[string]]::new()
    $words = Get-Words $Segment
    if (-not $words.Count) { return , $set }
    [void]$set.Add((Get-Program $words[0]))
    foreach ($word in ($words | Select-Object -Skip 1)) {
        foreach ($part in ($word.ToLowerInvariant() -split '[^a-z0-9_]+')) {
            if ($part.Length -ge 2) { [void]$set.Add($part) }
        }
    }
    , $set
}

function Get-Similarity([string]$A, [string]$B) {
    $setA = Get-TokenSet $A
    $setB = Get-TokenSet $B
    $union = [System.Collections.Generic.HashSet[string]]::new($setA)
    $union.UnionWith($setB)
    if (-not $union.Count) { return 0 }
    $both = [System.Collections.Generic.HashSet[string]]::new($setA)
    $both.IntersectWith($setB)
    $both.Count / $union.Count
}

function Get-Project([string]$Cwd) {
    if (-not $Cwd) { return '' }
    $top = git -C $Cwd rev-parse --show-toplevel 2>$null
    $path = if ($LASTEXITCODE -eq 0 -and $top) { $top } else { $Cwd }
    ($path -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
}

function Get-Session([hashtable]$Sessions, [string]$Id) {
    if (-not $Id) { throw 'lessons.ps1: hook input has no session_id' }
    if (-not $Sessions.ContainsKey($Id)) {
        $Sessions[$Id] = @{ pending = @(); denied = @(); overrides = @(); at = 0 }
    }
    $Sessions[$Id].at = Get-Now
    $Sessions[$Id]
}

function Test-Scope([hashtable]$Lesson, [string]$Cwd) {
    # Seen in 2+ projects: global. Otherwise only where it was learned.
    if (@($Lesson.projects).Count -ge 2) { return $true }
    @($Lesson.projects) -contains (Get-Project $Cwd)
}

function Add-Evidence([hashtable]$Lessons, [hashtable]$Failure, [string]$Fix, [string]$SessionId, [string]$Project) {
    $now = Get-Now
    $lesson = $Lessons[$Failure.key]
    if (-not $lesson -or (Get-Similarity $lesson.fix $Fix) -lt $SameFixSimilarity) {
        # New key, or a different fix: the newest evidence replaces the old lesson.
        $lesson = @{ key = $Failure.key; status = 'candidate'; sessions = @(); projects = @(); created = $now
            denials = 0; overridesOk = 0 }
        $Lessons[$Failure.key] = $lesson
    }
    $lesson.fail = $Failure.seg
    $lesson.code = $Failure.code
    $lesson.error = $Failure.error
    $lesson.fix = $Fix
    $lesson.lastSeen = $now
    if (@($lesson.sessions) -notcontains $SessionId) { $lesson.sessions = @(@($lesson.sessions) + $SessionId | Select-Object -Last 5) }
    if ($Project -and @($lesson.projects) -notcontains $Project) { $lesson.projects = @(@($lesson.projects) + $Project | Select-Object -Last 5) }
    if (@($lesson.sessions).Count -ge $PromoteAfterSessions) { $lesson.status = 'active' }
}

function Save-State([hashtable]$Lessons, [hashtable]$Sessions) {
    $now = Get-Now
    foreach ($k in @($Lessons.Keys)) {
        if ($now - $Lessons[$k].lastSeen -gt $ExpireSec) { $Lessons.Remove($k) }
    }
    if ($Lessons.Count -gt $MaxLessons) {
        $drop = $Lessons.Values | Sort-Object { $_.status -eq 'active' }, { $_.lastSeen } |
            Select-Object -First ($Lessons.Count - $MaxLessons)
        foreach ($lesson in @($drop)) { $Lessons.Remove($lesson.key) }
    }
    $anyPending = $false
    foreach ($id in @($Sessions.Keys)) {
        $session = $Sessions[$id]
        if ($now - $session.at -gt $SessionTtlSec) { $Sessions.Remove($id); continue }
        $session.pending = @($session.pending | Where-Object { $now - $_.at -le $PendingTtlSec })
        if ($session.pending.Count) { $anyPending = $true }
    }
    Write-JsonFile $LessonsPath $Lessons
    Write-JsonFile $SessionsPath $Sessions

    $programs = $Lessons.Values | Where-Object { $_.status -eq 'active' } | ForEach-Object { ($_.key -split ' ')[0] } | Sort-Object -Unique
    $lines = $programs | ForEach-Object { '"command": *"[^"]*' + ($_ -replace '([.^$*+?()[\]{}|\\])', '\$1') + "`n" }
    [IO.File]::WriteAllText($KeysPath, (@($lines) -join ''))  # LF only: grep -f reads CR as part of the pattern
    if ($anyPending) { [IO.File]::WriteAllText($PendingFlag, '') } else { Remove-Item -LiteralPath $PendingFlag -ErrorAction SilentlyContinue }
}

function Invoke-Hook([string]$Name) {
    $hook = Read-HookInput
    $command = if ($hook['tool_input'] -is [hashtable]) { [string]$hook['tool_input']['command'] } else { '' }
    $segment = Get-Segment $command
    if ($Name -ne 'edit' -and -not $segment) { return }
    $key = Get-Key $segment

    $mutex = [System.Threading.Mutex]::new($false, 'octo-cluster-lessons')
    try { $owned = $mutex.WaitOne(5000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { $mutex.Dispose(); throw 'lessons.ps1: timed out waiting for the lessons lock' }
    try {
        $lessons = Read-JsonFile $LessonsPath
        $sessions = Read-JsonFile $SessionsPath
        $session = Get-Session $sessions ([string]$hook['session_id'])
        $lesson = if ($key) { $lessons[$key] } else { $null }
        $output = $null

        switch ($Name) {
            'edit' { $session.pending = @() }

            'fail' {
                if ($hook['is_interrupt'] -or ([string]$hook['error']) -notmatch '^Exit code (\d+)') { break }
                $code = [int]$Matches[1]
                $errorLine = ((([string]$hook['error']) -split '\r?\n') | Select-Object -Skip 1 | Where-Object { $_.Trim() } | Select-Object -First 1)
                $errorLine = if ($errorLine) { $errorLine.Trim() } else { '' }
                if ($errorLine.Length -gt 160) { $errorLine = $errorLine.Substring(0, 160) }
                if (@($session.overrides) -contains $key) {
                    # Lesson was overridden and the command failed again: it still holds.
                    if ($lesson) { $lesson.lastSeen = Get-Now }
                    $session.overrides = @($session.overrides | Where-Object { $_ -ne $key })
                }
                if (($key -split ' ')[0] -in $IgnoredPrograms -or $command -match $SecretPattern -or $errorLine -match $SecretPattern) { break }
                $kept = @($session.pending | Where-Object { $_.seg -ne $segment })
                $session.pending = @(@($kept) + @{ seg = $segment; key = $key; code = $code; error = $errorLine; at = Get-Now } | Select-Object -Last $MaxPending)
            }

            'ok' {
                if ($lesson -and $lesson.status -eq 'active') {
                    if ($lesson.fail -eq $segment) {
                        $lessons.Remove($key)  # the command it warns about works now: stale
                    } elseif (@($session.overrides) -contains $key) {
                        $lesson.overridesOk++
                        if ($lesson.overridesOk -ge $RetireAfterOverrides) { $lessons.Remove($key) }
                    }
                }
                $session.overrides = @($session.overrides | Where-Object { $_ -ne $key })
                # The same command now works on its own (something else fixed it): nothing to learn.
                $session.pending = @($session.pending | Where-Object { $_.seg -ne $segment })
                if ($command -notmatch $SecretPattern) {
                    $match = $session.pending | Where-Object { (Get-Similarity $_.seg $segment) -ge $MinSimilarity } | Select-Object -Last 1
                    if ($match) {
                        $session.pending = @($session.pending | Where-Object { $_.seg -ne $match.seg })
                        Add-Evidence $lessons $match $segment ([string]$hook['session_id']) (Get-Project ([string]$hook['cwd']))
                    }
                }
            }

            'pre' {
                if (-not $lesson -or $lesson.status -ne 'active' -or -not (Test-Scope $lesson ([string]$hook['cwd']))) { break }
                if ($segment -eq $lesson.fix -or (Get-Similarity $segment $lesson.fix) -gt (Get-Similarity $segment $lesson.fail)) { break }
                if (@($session.denied) -contains $key) {
                    if (@($session.overrides) -notcontains $key) { $session.overrides = @(@($session.overrides) + $key) }
                    break
                }
                $session.denied = @(@($session.denied) + $key)
                $lesson.denials++
                $lesson.lastSeen = Get-Now
                $why = if ($lesson.error) { "exit $($lesson.code): $($lesson.error)" } else { "exit $($lesson.code)" }
                $reason = "octo-cluster lesson (seen in $(@($lesson.sessions).Count) sessions): ``$($lesson.fail)`` failed ($why). " +
                    "What worked instead: ``$($lesson.fix)``. If this does not apply here, run your command again unchanged; it is blocked only once per session."
                $output = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } }
            }
        }
        Save-State $lessons $sessions
    } finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
    if ($output) {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        ConvertTo-Json -InputObject $output -Depth 4 -Compress
    }
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

switch ($Action) {
    'list' {
        $lessons = Read-JsonFile $LessonsPath
        if (-not $lessons.Count) { "No lessons yet in $DataDir"; break }
        $lessons.Values | Sort-Object { $_.status -ne 'active' }, { $_.key } | ForEach-Object {
            [pscustomobject]@{ Status = $_.status; Key = $_.key; Sessions = @($_.sessions).Count; Denials = $_.denials; Failed = $_.fail; Worked = $_.fix }
        } | Format-Table -AutoSize -Wrap
    }
    'forget' {
        if (-not $Key) { throw 'lessons.ps1: forget needs the lesson key, e.g. forget ''npx tsc'' (see list)' }
        $lessons = Read-JsonFile $LessonsPath
        if (-not $lessons.ContainsKey($Key)) { throw "lessons.ps1: no lesson with key '$Key' (see list)" }
        $lessons.Remove($Key)
        Save-State $lessons (Read-JsonFile $SessionsPath)
        "Forgot lesson '$Key'"
    }
    default { Invoke-Hook $Action }
}
