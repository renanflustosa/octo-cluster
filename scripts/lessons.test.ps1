#Requires -Version 7.0
<#
.SYNOPSIS
  Scenario test for scripts/lessons.ps1: feeds hook JSON like Claude Code does and checks the lessons.
.EXAMPLE
  pwsh -NoProfile -File scripts/lessons.test.ps1
#>
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'lessons.ps1'
$data = Join-Path ([IO.Path]::GetTempPath()) "octo-lessons-test-$PID"
$cwd = Join-Path $data 'work'
New-Item -ItemType Directory -Force -Path $cwd | Out-Null
$failures = 0

function Send([string]$Action, [string]$Session, [string]$Command, [string]$ErrorText) {
    $hook = @{ session_id = $Session; cwd = $cwd; tool_name = 'Bash'; tool_input = @{ command = $Command } }
    if ($ErrorText) { $hook.error = $ErrorText; $hook.is_interrupt = $false }
    $out = $hook | ConvertTo-Json -Compress | pwsh -NoProfile -NonInteractive -File $script $Action -DataDir $data
    if ($LASTEXITCODE -ne 0) { throw "lessons.ps1 $Action exited $LASTEXITCODE" }
    $out
}
function Lessons { $p = Join-Path $data 'lessons.json'; if (Test-Path $p) { Get-Content $p -Raw | ConvertFrom-Json -AsHashtable } else { @{} } }
function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { "ok   $Name" } else { "FAIL $Name"; $script:failures++ }
}

$bad = 'npx tsc --noEmit'
$good = 'node node_modules/typescript/bin/tsc --noEmit'
$err = "Exit code 127`nbash: npx: command not found"

try {
    Send fail A "cd /repo && $bad" $err | Out-Null
    Send ok A 'git status' | Out-Null
    Send ok A $good | Out-Null
    Check 'pair in one session is only a candidate' ((Lessons)['npx tsc'].status -eq 'candidate')
    Check 'candidate never blocks' (-not (Send pre C $bad))

    Send fail B $bad $err | Out-Null
    Send ok B $good | Out-Null
    Check 'same pair in a 2nd session turns active' ((Lessons)['npx tsc'].status -eq 'active')
    $keys = [IO.File]::ReadAllText((Join-Path $data 'keys.txt'))
    Check 'keys.txt is LF-only grep prefilter' ($keys -match 'npx' -and $keys -notmatch "`r")

    $deny = Send pre C $bad | ConvertFrom-Json
    Check 'active lesson denies with the fix' ($deny.hookSpecificOutput.permissionDecision -eq 'deny' -and $deny.hookSpecificOutput.permissionDecisionReason -match [regex]::Escape($good))
    Check 'the fix itself is never blocked' (-not (Send pre D $good))
    Check 'second attempt in the session is allowed' (-not (Send pre C $bad))
    Send fail C $bad $err | Out-Null
    Check 'failed override keeps the lesson' ((Lessons).ContainsKey('npx tsc'))

    Send pre E $bad | Out-Null
    Send pre E $bad | Out-Null
    Send ok E $bad | Out-Null
    Check 'warned command working again retires the lesson' (-not (Lessons).ContainsKey('npx tsc'))

    Send fail F 'make build' "Exit code 2`nmake: *** [build] Error 1" | Out-Null
    $edit = @{ session_id = 'F'; cwd = $cwd; tool_name = 'Edit'; tool_input = @{ file_path = 'x' } } | ConvertTo-Json -Compress
    $edit | pwsh -NoProfile -NonInteractive -File $script edit -DataDir $data | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "lessons.ps1 edit exited $LASTEXITCODE" }
    Send ok F 'make build -j4' | Out-Null
    Check 'a file edit between failure and success learns nothing' (-not (Lessons).ContainsKey('make build'))

    Send fail G 'ls src' "Exit code 2`nls: cannot access 'src'" | Out-Null
    Send ok G 'ls src/app' | Out-Null
    Check 'exploration commands are ignored' (-not (Lessons).ContainsKey('ls'))

    Send fail H 'curl -H "Authorization: Bearer abc" https://api.example.com' "Exit code 6`ncurl: (6) Could not resolve host" | Out-Null
    Send ok H 'curl -H "Authorization: Bearer abc" https://api.example.org' | Out-Null
    Check 'commands with secrets are never stored' (-not ((Get-Content (Join-Path $data 'lessons.json'), (Join-Path $data 'sessions.json') -Raw) -match 'Bearer'))

    Send fail I 'npm test' "Exit code 1`nError: vitest not found" | Out-Null
    Send ok I 'pnpm exec vitest run' | Out-Null
    Check 'unrelated success does not pair' (-not (Lessons).ContainsKey('npm test'))
} finally {
    Remove-Item -Recurse -Force -LiteralPath $data -ErrorAction SilentlyContinue
}

if ($failures) { Write-Error "$failures lessons check(s) failed" }
'All lessons checks passed'
