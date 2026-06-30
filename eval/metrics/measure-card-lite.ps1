# Lite metrics at /close — Cursor usage delta + diff LOC + budget alerts → SQLite.
param(
    [Parameter(Mandatory = $true)]
    [string]$Ticket,

    [string]$Profile = '',

    [string]$RepoRoot = '',

    [string]$BaseRef = 'develop',

    [string]$HeadRef = 'HEAD',

    [ValidateSet('baseline', 'ponytail-lite', 'caveman-only', 'yagni-oneliner', 'default')]
    [string]$Arm = 'default',

    [ValidateSet('READY', 'NEEDS FIXES', 'BLOCKED', 'unknown')]
    [string]$ShipVerdict = 'unknown',

    [switch]$ExcludeTests,

    [string]$Notes = '',

    [switch]$SkipUsage
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')

$root = Get-OctoClusterRoot
if (-not $Profile) {
    $ctx = Get-ShipExecutionContext
    $Profile = if ($ctx.memory_profile) { [string]$ctx.memory_profile } else { 'octo-cluster' }
}

if (-not $RepoRoot) {
    $siblingDemo = Join-Path (Split-Path $root -Parent) 'consumer-demo'
    if (Test-Path $siblingDemo) { $RepoRoot = $siblingDemo }
    else { $RepoRoot = $root }
}

$memRoot = Get-MemoryRoot -Profile $Profile
$baselinePath = Join-Path $memRoot 'usage-baseline.json'
$logDir = Join-Path $root 'state\logs\metrics-baseline'

# --- usage delta ---
$tokensInput = $null
$tokensOutput = $null
$tokensCache = $null
$tokensTotal = $null
$costUsd = $null
$usageEvents = $null
$usageSource = 'skipped'

if (-not $SkipUsage -and (Test-Path $baselinePath)) {
    try {
        $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
        $sinceMs = [long]$baseline.started_at_ms
        $usageScript = Join-Path $PSScriptRoot 'cursor-usage.ps1'
        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $usageScript -SinceMs $sinceMs 2>$null
        if ($raw) {
            $usage = ($raw | Out-String).Trim() | ConvertFrom-Json
            if ($usage.ok) {
                $tokensInput = [int]$usage.tokens_input
                $tokensOutput = [int]$usage.tokens_output
                $tokensCache = [int]$usage.tokens_cache_read
                $tokensTotal = [int]$usage.tokens_total
                $costUsd = [double]$usage.cost_usd
                $usageEvents = [int]$usage.events
                $usageSource = 'api'
            }
        }
    } catch {
        Write-Host "[measure-card-lite] usage API skipped: $($_.Exception.Message)" -ForegroundColor DarkYellow
        $usageSource = 'skipped'
    }
} elseif (-not (Test-Path $baselinePath)) {
    $usageSource = 'proxy'
}

# --- diff LOC ---
$diffAdded = 0
$diffDeleted = 0
$diffNet = 0
$filesChanged = 0
$scoreDiff = Join-Path $PSScriptRoot '..\agentic\score-diff.ps1'
if (Test-Path $scoreDiff) {
    try {
        $diffJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $scoreDiff `
            -RepoRoot $RepoRoot -BaseRef $BaseRef -HeadRef $HeadRef `
            @($(if ($ExcludeTests) { '-ExcludeTests' }))
        $diff = ($diffJson | Out-String).Trim() | ConvertFrom-Json
        $diffAdded = [int]$diff.added
        $diffDeleted = [int]$diff.deleted
        $diffNet = [int]$diff.net
        $filesChanged = [int]$diff.files_changed
    } catch { }
}

# --- context budget (lite) ---
$budgetAlerts = 0
$commandsLines = 0
$skillsLines = 0
$budgetScript = Join-Path $root 'domains\core\scripts\core-context-budget.ps1'
if (Test-Path $budgetScript) {
    try {
        $budgetRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $budgetScript -Json 2>&1
        $budgetText = if ($budgetRaw -is [System.Array]) { ($budgetRaw | Out-String).Trim() } else { [string]$budgetRaw }
        $budget = $budgetText | ConvertFrom-Json
        $commandsLines = [int]$budget.commands_lines
        $skillsLines = [int]$budget.skills_lines
        $budgetAlerts = @($budget.alerts).Count
    } catch { }
}

# --- gates ---
$gatesPass = 0
$gateStamp = Join-Path $logDir 'last-core-gate-pass.txt'
if (Test-Path $gateStamp) {
    $age = ((Get-Date) - [datetime](Get-Content $gateStamp -Raw).Trim()).TotalHours
    if (($age -le 48) -and ($ShipVerdict -eq 'READY' -or $ShipVerdict -eq 'unknown')) {
        $gatesPass = 1
    }
}

$row = [ordered]@{
    recorded_at             = (Get-Date).ToUniversalTime().ToString('o')
    ticket                  = $Ticket
    arm                     = $Arm
    repo                    = (Split-Path $RepoRoot -Leaf)
    tokens_input            = $tokensInput
    tokens_output           = $tokensOutput
    tokens_cache_read       = $tokensCache
    tokens_total            = $tokensTotal
    cost_usd                = $costUsd
    usage_events            = $usageEvents
    usage_source            = $usageSource
    diff_added              = $diffAdded
    diff_deleted            = $diffDeleted
    diff_net                = $diffNet
    files_changed           = $filesChanged
    gates_pass              = $gatesPass
    context_budget_alerts   = $budgetAlerts
    commands_lines          = $commandsLines
    skills_lines            = $skillsLines
    ship_verdict            = $ShipVerdict
    notes                   = $Notes
}

$pyScript = Join-Path $root 'engine\metrics\metrics_db.py'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if ($python -and (Test-Path $pyScript)) {
    $jsonFile = Join-Path ([System.IO.Path]::GetTempPath()) "octo-card-$([Guid]::NewGuid().ToString('N')).json"
    try {
        ($row | ConvertTo-Json -Compress -Depth 5) | Set-Content -Path $jsonFile -Encoding UTF8 -NoNewline
        & $python.Source $pyScript insert-card --json-file $jsonFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[measure-card-lite] SQLite insert failed" -ForegroundColor Yellow
        }
    } finally {
        Remove-Item $jsonFile -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[measure-card-lite] python or metrics_db.py missing" -ForegroundColor Yellow
}

if (Test-Path $baselinePath) {
    Remove-Item $baselinePath -Force -ErrorAction SilentlyContinue
}

$summary = "ticket=$Ticket tokens=$tokensTotal cost=`$$costUsd diff_added=$diffAdded source=$usageSource"
Write-Host "[measure-card-lite] $summary" -ForegroundColor Green
Write-Output ($row | ConvertTo-Json -Compress)
exit 0
