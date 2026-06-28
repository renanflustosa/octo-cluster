# Full harness metrics — weekly (productivity-audit + budget + safety + SQLite snapshot).
param(
    [switch]$Force,
    [switch]$SkipPromptfoo,
    [string]$Profile = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')

$root = Get-OctoClusterRoot
if (-not $Profile) {
    $ctx = Get-ShipExecutionContext
    $Profile = if ($ctx.memory_profile) { [string]$ctx.memory_profile } else { 'octo-cluster' }
}

$memRoot = Get-MemoryRoot -Profile $Profile
$stampFile = Join-Path $memRoot 'last-metrics-full.txt'
$today = (Get-Date).ToUniversalTime()

if (-not $Force -and (Test-Path $stampFile)) {
    $last = (Get-Content $stampFile -Raw).Trim()
    try {
        $lastDt = [datetime]$last
        if (($today - $lastDt).TotalDays -lt 7) {
            Write-Host "[measure-harness-full] skipped (last run $last, use -Force)" -ForegroundColor DarkGray
            exit 0
        }
    } catch { }
}

# Inline harness checks (productivity-audit, budget, safety)
$checks = @()
function Add-Check { param([string]$Id, [bool]$Ok, [string]$Detail = '')
    $script:checks += [ordered]@{ id = $Id; ok = $Ok; detail = $Detail }
}

$auditOk = 0; $auditWarn = 0; $auditTotal = 0
$auditScript = Join-Path $root 'scripts\productivity-audit.ps1'
if (Test-Path $auditScript) {
    $auditRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript -Json 2>&1
    $auditText = if ($auditRaw -is [System.Array]) { ($auditRaw | Out-String).Trim() } else { [string]$auditRaw }
    try {
        $audit = $auditText | ConvertFrom-Json
        $items = @($audit)
        foreach ($r in $items) {
            if (-not $r.status) { continue }
            $auditTotal++
            if ($r.status -eq 'OK') { $auditOk++ }
            elseif ($r.status -eq 'WARN') { $auditWarn++ }
        }
        Add-Check -Id 'productivity_audit' -Ok ($auditWarn -eq 0 -and $auditOk -ge ($auditTotal * 0.8)) -Detail "ok=$auditOk warn=$auditWarn"
    } catch {
        Add-Check -Id 'productivity_audit' -Ok $false -Detail 'parse failed'
    }
}

$commandsLines = 0; $skillsLines = 0; $budgetAlerts = @()
$budgetScript = Join-Path $root 'domains\core\scripts\core-context-budget.ps1'
if (Test-Path $budgetScript) {
    $budgetRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $budgetScript -Json 2>&1
    $budgetText = if ($budgetRaw -is [System.Array]) { ($budgetRaw | Out-String).Trim() } else { [string]$budgetRaw }
    try {
        $budget = $budgetText | ConvertFrom-Json
        $commandsLines = [int]$budget.commands_lines
        $skillsLines = [int]$budget.skills_lines
        $budgetAlerts = @($budget.alerts)
        Add-Check -Id 'context_budget' -Ok ($budgetAlerts.Count -eq 0) -Detail ("alerts={0}" -f $budgetAlerts.Count)
    } catch {
        Add-Check -Id 'context_budget' -Ok $false -Detail 'parse failed'
    }
}

$safetyScript = Join-Path $root 'eval\agentic\score-safety.py'
if (Test-Path $safetyScript) {
    $py = (Get-Command python -ErrorAction SilentlyContinue)
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($py) {
        & $py.Source $safetyScript --selftest 2>&1 | Out-Null
        Add-Check -Id 'agentic_safety_selftest' -Ok ($LASTEXITCODE -eq 0)
    } else {
        Add-Check -Id 'agentic_safety_selftest' -Ok $false -Detail 'python missing'
    }
}

if (-not $SkipPromptfoo) {
    $pf = Join-Path $root 'capabilities\core\ship\providers\run-promptfoo.ps1'
    if (Test-Path $pf) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $pf 2>&1 | Out-Null
        Add-Check -Id 'promptfoo' -Ok ($LASTEXITCODE -eq 0)
    }
}

$okCount = @($checks | Where-Object { $_.ok }).Count
$score = if ($checks.Count -gt 0) { [math]::Round(100 * $okCount / $checks.Count) } else { 0 }

$snapshot = [ordered]@{
    recorded_at     = $today.ToString('o')
    harness_score   = $score
    checks_ok       = $okCount
    checks_total    = $checks.Count
    commands_lines  = $commandsLines
    skills_lines    = $skillsLines
    audit_ok        = $auditOk
    audit_warn      = $auditWarn
    details_json    = ($checks | ConvertTo-Json -Compress)
}

$pyScript = Join-Path $root 'engine\metrics\metrics_db.py'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if ($python -and (Test-Path $pyScript)) {
    $jsonFile = Join-Path ([System.IO.Path]::GetTempPath()) "octo-harness-$([Guid]::NewGuid().ToString('N')).json"
    try {
        ($snapshot | ConvertTo-Json -Compress -Depth 5) | Set-Content -Path $jsonFile -Encoding UTF8 -NoNewline
        & $python.Source $pyScript insert-harness --json-file $jsonFile
    } finally {
        Remove-Item $jsonFile -Force -ErrorAction SilentlyContinue
    }
}

Set-Content -Path $stampFile -Value $today.ToString('o') -Encoding UTF8

Write-Host "== measure-harness-full ==" -ForegroundColor Cyan
Write-Host ("score: {0}/100 ({1}/{2})" -f $score, $okCount, $checks.Count)
foreach ($c in $checks) {
    $mark = if ($c.ok) { '[ok]' } else { '[!!]' }
    Write-Host ("  {0} {1}" -f $mark, $c.id)
}

# SQL trends summary
$reportScript = Join-Path $PSScriptRoot 'report.ps1'
if (Test-Path $reportScript) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $reportScript -Last 5
}

exit 0
