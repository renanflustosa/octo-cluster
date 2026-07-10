# Close: compact memory, archive ticket, reindex. Domain-agnostic.
param(
    [string]$Ticket,
    [string]$Profile = "octo-cluster",
    [string]$Goal = "",
    [string]$Files = "",
    [string]$Decisions = "",
    [string]$Apis = "",
    [string]$Debt = "",
    [string]$Future = "",
    [string]$RepoRoot = "",
    [string]$BaseRef = "develop",
    [string]$Arm = "default",
    [string]$ShipVerdict = "unknown",
    [switch]$SkipMetrics
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
$mem = Get-MemoryRoot -Profile $Profile
$taskFile = Join-Path $mem "current_task.md"
if (-not $Ticket -and (Test-Path $taskFile)) {
    $raw = Get-Content $taskFile -Raw
    if ($raw -match "CARD:\s*(\S+)") { $Ticket = $Matches[1].Trim() }
}
if (-not $Ticket) { Write-Error "Missing -Ticket (or CARD: in current_task.md)"; exit 1 }
if (-not $Goal -and (Test-Path $taskFile)) {
    $raw = Get-Content $taskFile -Raw
    if ($raw -match "GOAL:\s*(.+)") { $Goal = $Matches[1].Trim() }
}
$ce = Get-ContextEngineRoot
$exitCode = Invoke-ContextEngine run --cwd $ce memory-compact $Profile
if ($null -ne $exitCode -and $exitCode -ne 0) { exit $exitCode }
$learnArgs = @('run', '--cwd', $ce, 'learn', $Profile, '--ticket', $Ticket)
if ($Goal) { $learnArgs += @('--goal', $Goal) }
if ($Files) { $learnArgs += @('--files', $Files) }
if ($Decisions) { $learnArgs += @('--decisions', $Decisions) }
if ($Apis) { $learnArgs += @('--apis', $Apis) }
if ($Debt) { $learnArgs += @('--debt', $Debt) }
if ($Future) { $learnArgs += @('--future', $Future) }
$exitCode = Invoke-ContextEngine @learnArgs
if ($null -ne $exitCode -and $exitCode -ne 0) { exit $exitCode }
$exitCode = Invoke-ContextEngineIncrementalIndex -Profile $Profile -Kind memory -Incremental
if ($exitCode -ne 0) { Write-Host "WARN: incremental LanceDB reindex failed (exit $exitCode)" -ForegroundColor Yellow }
$exitCode = Invoke-ContextEngine run --cwd $ce memory-compact $Profile
if ($null -ne $exitCode -and $exitCode -ne 0) { exit $exitCode }

if (-not $SkipMetrics) {
    $liteScript = Join-Path (Get-OctoClusterRoot) "eval\metrics\measure-card-lite.ps1"
    if (Test-Path $liteScript) {
        try {
            $liteParams = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $liteScript,
                '-Ticket', $Ticket, '-Profile', $Profile, '-Arm', $Arm,
                '-ShipVerdict', $ShipVerdict, '-BaseRef', $BaseRef
            )
            if ($RepoRoot) { $liteParams += @('-RepoRoot', $RepoRoot) }
            $liteOut = & powershell @liteParams 2>&1 | Out-String
            $combo = $null
            $score = $null
            # Prefer JSON line from measure-card-lite
            foreach ($line in ($liteOut -split "`r?`n")) {
                $t = $line.Trim()
                if ($t.StartsWith('{') -and $t.Contains('combination_id')) {
                    try {
                        $row = $t | ConvertFrom-Json
                        $combo = [string]$row.combination_id
                        $score = $row.harness_score
                    } catch { }
                }
                if ($t -match '\[measure-card-lite\]') {
                    Write-Host $t -ForegroundColor Green
                }
            }
            if (-not $combo) {
                try {
                    . (Join-Path (Get-OctoClusterRoot) 'domains\core\scripts\resolve-execution-context.ps1')
                    $ctx = Get-ShipExecutionContext
                    if ($ctx.combination_id) { $combo = [string]$ctx.combination_id }
                } catch { }
            }
            if (-not $combo) { $combo = 'baseline' }
            $scoreText = if ($null -ne $score -and "$score" -ne '') { "$score" } else { 'n/a' }
            Write-Host "[close] metrics combo=$combo harness_score=$scoreText" -ForegroundColor Cyan
            Write-Host "[close] rank arms: pwsh eval/metrics/report.ps1 -CompareCombinations -Last 50" -ForegroundColor DarkGray
        } catch {
            Write-Host "WARN: measure-card-lite skipped - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

if (Test-Path $taskFile) { Set-Content -Path $taskFile -Value "# cleared`nCARD: (none)`n" -Encoding UTF8 }
Write-Host "[close] Archived $Ticket (profile=$Profile). Start NEW chat -> /scan <next-ticket>" -ForegroundColor Green
exit 0
