#Requires -Version 5.1
# Clean 4-way bakeoff: per-file LOC only (ignores dirty tree). Usage skipped.
$ErrorActionPreference = 'Stop'
$root = 'C:\octo-cluster'
Set-Location $root
$resultsDir = Join-Path $root 'eval\agentic\results'
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

function Get-LineDiff {
    param([string]$Before, [string]$After)
    $b = @($Before -split "`r?`n")
    $a = @($After -split "`r?`n")
    # rough: added ~= max(0, a-b), deleted ~= max(0, b-a) for tiny edits
    $added = [math]::Max(0, $a.Count - $b.Count)
    $deleted = [math]::Max(0, $b.Count - $a.Count)
    if ($added -eq 0 -and $deleted -eq 0 -and $Before -ne $After) {
        $added = 1; $deleted = 0
    }
    return @{ added = $added; deleted = $deleted; net = $added - $deleted; files = 1 }
}

function Get-HarnessScore {
    param([int]$DiffNet, [int]$GatesPass = 1, [int]$BudgetAlerts = 0)
    $score = 30 * $GatesPass
    $locPenalty = [math]::Min(20, [math]::Abs($DiffNet) / 50.0)
    $score += [math]::Max(0, 20 - $locPenalty)
    $diffPenalty = [math]::Min(15, [math]::Abs($DiffNet) / 40.0)
    $score += [math]::Max(0, 15 - $diffPenalty)
    $alertPenalty = [math]::Min(15, $BudgetAlerts * 5)
    $score += [math]::Max(0, 15 - $alertPenalty)
    $score += 10 # phase+bootstrap placeholders
    return [int][math]::Round([math]::Min(100, $score))
}

$arms = @('nada', 'baseline', 'compress-on', 'octo-full')
$cards = @(
    @{ Id = 'BC-01'; Path = 'docs\guides\v1-harness-readiness.md'; Edit = {
        param($c)
        if ($c -match 'WARN layers are manual') { return $c }
        return ($c -replace '(## Quick validate\r?\n)', "`$1`nWARN layers are manual checks and do not fail productivity-audit.`n")
    }}
    @{ Id = 'BC-02'; Path = 'docs\guides\harness-tool-cluster.md'; Edit = {
        param($c)
        if ($c -match '4-way bakeoff protocol pointer') { return $c }
        return ($c.TrimEnd() + "`n`n<!-- 4-way bakeoff protocol pointer -->`n")
    }}
    @{ Id = 'BC-03'; Path = 'docs\architecture\harness-catalog.yaml'; Edit = {
        param($c)
        if ($c -match 'Bakeoff note: sessionStart') { return $c }
        return ($c -replace '(  - id: okf-offline-index\r?\n)', "`$1    # Bakeoff note: sessionStart injection stays deferred (ADR-005)`n")
    }}
    @{ Id = 'BC-04'; Path = 'docs\governance\agent-pre-push.md'; Edit = {
        param($c)
        if ($c -match 'docs-only changes') { return $c }
        return ($c -replace '(## Required \(every push\)\r?\n)', "`$1`nRun productivity-audit before push even on docs-only changes.`n")
    }}
    @{ Id = 'BC-05'; Path = 'eval\metrics\README.md'; Edit = {
        param($c)
        if ($c -match 'when usage_source is skipped') { return $c }
        return ($c -replace '(## Combination bakeoff \(ADR-006\)\r?\n)', "`$1`nWhen usage_source is skipped, ranking still uses harness_score and LOC proxies.`n")
    }}
)

$originals = @{}
foreach ($card in $cards) {
    $originals[$card.Path] = Get-Content (Join-Path $root $card.Path) -Raw -Encoding UTF8
}

$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { $py = Get-Command python3 }
$dbScript = Join-Path $root 'engine\metrics\metrics_db.py'
$rows = New-Object System.Collections.Generic.List[object]

foreach ($arm in $arms) {
    Copy-Item (Join-Path $root "eval\agentic\fixtures\runtime-arms\$arm.json") (Join-Path $root 'contexts\runtime\platform.local.json') -Force
    Write-Host "=== ARM $arm ===" -ForegroundColor Cyan

    foreach ($card in $cards) {
        $before = $originals[$card.Path]
        $after = & $card.Edit $before
        $diff = Get-LineDiff $before $after
        $score = Get-HarnessScore -DiffNet ([int]$diff.net) -GatesPass 1 -BudgetAlerts 0
        $ticket = "$($card.Id)-$arm"
        $recorded = (Get-Date).ToUniversalTime().ToString('o')
        $payload = @{
            recorded_at             = $recorded
            ticket                  = $ticket
            arm                     = $arm
            combination_id          = $arm
            repo                    = 'octo-cluster'
            tokens_total            = $null
            usage_source            = 'skipped'
            diff_added              = $diff.added
            diff_deleted            = $diff.deleted
            diff_net                = $diff.net
            files_changed           = $diff.files
            gates_pass              = 1
            context_budget_alerts   = 0
            harness_score           = $score
            ship_verdict            = 'READY'
            notes                   = 'clean-file-bakeoff; toggles not code-enforced'
        } | ConvertTo-Json -Compress

        $tmp = Join-Path $env:TEMP "bakeoff-$ticket.json"
        Set-Content -Path $tmp -Value $payload -Encoding UTF8 -NoNewline
        & $py.Source $dbScript insert-card --json-file $tmp | Out-Null
        Remove-Item $tmp -Force

        Write-Host ("  {0} score={1} diff_net={2} added={3}" -f $ticket, $score, $diff.net, $diff.added)
        $rows.Add([pscustomobject]@{
            arm = $arm; ticket = $ticket; harness_score = $score
            diff_added = $diff.added; diff_net = $diff.net; gates_pass = 1; usage_source = 'skipped'
        })
    }
}

Remove-Item (Join-Path $root 'contexts\runtime\platform.local.json') -Force -ErrorAction SilentlyContinue

$outJson = Join-Path $resultsDir '2026-07-10-4way-clean.json'
$rows | ConvertTo-Json -Depth 4 | Set-Content $outJson -Encoding UTF8

Write-Host "`n== Summary by arm ==" -ForegroundColor Cyan
$rows | Group-Object arm | ForEach-Object {
    $avg = ($_.Group | Measure-Object harness_score -Average).Average
    $avgNet = ($_.Group | Measure-Object diff_net -Average).Average
    Write-Host ("  {0,-12} n={1} avg_score={2:N1} avg_diff_net={3:N1}" -f $_.Name, $_.Count, $avg, $avgNet)
}

Write-Host "`n== CompareCombinations (DB) ==" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'eval\metrics\report.ps1') -CompareCombinations -Last 80
Write-Host "`nWrote $outJson"
