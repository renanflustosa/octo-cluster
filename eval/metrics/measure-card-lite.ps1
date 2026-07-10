# Lite metrics at /close — Cursor usage delta + diff LOC + budget alerts → SQLite.
param(
    [Parameter(Mandatory = $true)]
    [string]$Ticket,

    [string]$Profile = '',

    [string]$RepoRoot = '',

    [string]$BaseRef = 'develop',

    [string]$HeadRef = 'HEAD',

    [ValidateSet('baseline', 'ponytail-lite', 'caveman-only', 'yagni-oneliner', 'default', 'nada', 'compress-on', 'octo-full')]
    [string]$Arm = 'default',

    [string]$CombinationId = '',

    [ValidateSet('READY', 'NEEDS FIXES', 'BLOCKED', 'unknown')]
    [string]$ShipVerdict = 'unknown',

    [switch]$ExcludeTests,

    [string]$Notes = '',

    [switch]$SkipUsage
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot '..\..\domains\core\scripts\resolve-execution-context.ps1')

$root = Get-OctoClusterRoot
$ctx = $null
try { $ctx = Get-ShipExecutionContext } catch { }

if (-not $Profile) {
    $Profile = if ($ctx -and $ctx.memory_profile) { [string]$ctx.memory_profile } else { 'octo-cluster' }
}

if (-not $CombinationId) {
    if ($ctx -and $ctx.combination_id) { $CombinationId = [string]$ctx.combination_id }
    else { $CombinationId = 'baseline' }
}

# Keep arm aligned with combination for legacy report grouping when still default
if ($Arm -eq 'default' -and $CombinationId -and $CombinationId -ne 'baseline') {
    $Arm = $CombinationId
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
$tokensInMeasured = $null
$tokensOutMeasured = $null
$tokensInEstimated = $null
$tokensOutEstimated = $null
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
                $tokensInMeasured = $tokensInput
                $tokensOutMeasured = $tokensOutput
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

# --- harness_score (ADR-006 weights, lite approximation) ---
$score = 0
$score += (30 * $gatesPass)
if ($usageSource -eq 'api' -and $null -ne $tokensTotal) {
    $tokScore = [math]::Max(0, 20 - [math]::Min(20, [math]::Floor($tokensTotal / 5000)))
    $score += $tokScore
} else {
    $locPenalty = [math]::Min(20, [math]::Abs($diffNet) / 50)
    $score += [math]::Max(0, 20 - $locPenalty)
}
$diffPenalty = [math]::Min(15, [math]::Abs($diffNet) / 40)
$score += [math]::Max(0, 15 - $diffPenalty)
$alertPenalty = [math]::Min(15, $budgetAlerts * 5)
$score += [math]::Max(0, 15 - $alertPenalty)
$score += 5  # phase_shape placeholder
$score += 5  # bootstrap placeholder
$harnessScore = [int][math]::Round([math]::Min(100, $score))

$row = [ordered]@{
    recorded_at               = (Get-Date).ToUniversalTime().ToString('o')
    ticket                    = $Ticket
    arm                       = $Arm
    combination_id            = $CombinationId
    repo                      = (Split-Path $RepoRoot -Leaf)
    tokens_input              = $tokensInput
    tokens_output             = $tokensOutput
    tokens_cache_read         = $tokensCache
    tokens_total              = $tokensTotal
    tokens_input_measured     = $tokensInMeasured
    tokens_output_measured    = $tokensOutMeasured
    tokens_input_estimated    = $tokensInEstimated
    tokens_output_estimated   = $tokensOutEstimated
    cost_usd                  = $costUsd
    usage_events              = $usageEvents
    usage_source              = $usageSource
    diff_added                = $diffAdded
    diff_deleted              = $diffDeleted
    diff_net                  = $diffNet
    files_changed             = $filesChanged
    gates_pass                = $gatesPass
    context_budget_alerts     = $budgetAlerts
    commands_lines            = $commandsLines
    skills_lines              = $skillsLines
    harness_score             = $harnessScore
    ship_verdict              = $ShipVerdict
    notes                     = $Notes
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

$summary = "ticket=$Ticket combo=$CombinationId score=$harnessScore tokens=$tokensTotal cost=`$$costUsd diff_added=$diffAdded source=$usageSource"
Write-Host "[measure-card-lite] $summary" -ForegroundColor Green
Write-Output ($row | ConvertTo-Json -Compress)
exit 0
