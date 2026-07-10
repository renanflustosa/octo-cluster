#Requires -Version 5.1
# Instrumented 4-way bakeoff runner (LOC + harness_score; usage skipped).
param([switch]$KeepLocalOverlay)

$ErrorActionPreference = 'Continue'
$root = 'C:\octo-cluster'
Set-Location $root
$resultsDir = Join-Path $root 'eval\agentic\results'
if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }

function Save-Original {
    param([string]$Rel)
    $full = Join-Path $root $Rel
    if (Test-Path $full) { return (Get-Content $full -Raw -Encoding UTF8) }
    return $null
}

function Restore-Original {
    param([string]$Rel, [string]$Content)
    $full = Join-Path $root $Rel
    if ($null -eq $Content) { return }
    Set-Content -Path $full -Value $Content -Encoding UTF8 -NoNewline
}

$arms = @('nada', 'baseline', 'compress-on', 'octo-full')
$cards = @(
    @{ Id = 'BC-01'; Path = 'docs\guides\v1-harness-readiness.md'; Marker = 'WARN layers are manual'; Insert = {
        param($c)
        if ($c -match 'WARN layers are manual') { return $c }
        return ($c -replace '(## Quick validate\r?\n)', "`$1`nWARN layers are manual checks and do not fail productivity-audit.`n")
    }}
    @{ Id = 'BC-02'; Path = 'docs\guides\harness-tool-cluster.md'; Marker = '4-way bakeoff protocol pointer'; Insert = {
        param($c)
        if ($c -match '4-way bakeoff protocol pointer') { return $c }
        return ($c.TrimEnd() + "`n`n<!-- 4-way bakeoff protocol pointer -->`n")
    }}
    @{ Id = 'BC-03'; Path = 'docs\architecture\harness-catalog.yaml'; Marker = 'Bakeoff note: sessionStart'; Insert = {
        param($c)
        if ($c -match 'Bakeoff note: sessionStart') { return $c }
        return ($c -replace '(  - id: okf-offline-index\r?\n)', "`$1    # Bakeoff note: sessionStart injection stays deferred (ADR-005)`n")
    }}
    @{ Id = 'BC-04'; Path = 'docs\governance\agent-pre-push.md'; Marker = 'docs-only changes'; Insert = {
        param($c)
        if ($c -match 'docs-only changes') { return $c }
        return ($c -replace '(## Required \(every push\)\r?\n)', "`$1`nRun productivity-audit before push even on docs-only changes.`n")
    }}
    @{ Id = 'BC-05'; Path = 'eval\metrics\README.md'; Marker = 'when usage_source is skipped'; Insert = {
        param($c)
        if ($c -match 'when usage_source is skipped') { return $c }
        return ($c -replace '(## Combination bakeoff \(ADR-006\)\r?\n)', "`$1`nWhen usage_source is skipped, ranking still uses harness_score and LOC proxies.`n")
    }}
)

# Snapshot originals once
$originals = @{}
foreach ($card in $cards) {
    $originals[$card.Path] = Save-Original $card.Path
}

$lite = Join-Path $root 'eval\metrics\measure-card-lite.ps1'
$results = New-Object System.Collections.Generic.List[object]

foreach ($arm in $arms) {
    Copy-Item (Join-Path $root "eval\agentic\fixtures\runtime-arms\$arm.json") (Join-Path $root 'contexts\runtime\platform.local.json') -Force
    Write-Host "=== ARM $arm ===" -ForegroundColor Cyan

    foreach ($card in $cards) {
        Restore-Original $card.Path $originals[$card.Path]
        $full = Join-Path $root $card.Path
        $cur = Get-Content $full -Raw -Encoding UTF8
        $new = & $card.Insert $cur
        Set-Content -Path $full -Value $new -Encoding UTF8 -NoNewline

        $ticket = "$($card.Id)-$arm"
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $lite `
            -Ticket $ticket -CombinationId $arm -RepoRoot $root -BaseRef HEAD `
            -ShipVerdict READY -SkipUsage -Notes 'instrumented-bakeoff' 2>&1 | Out-String

        $score = $null; $diffNet = $null; $gates = $null; $files = $null; $added = $null
        foreach ($line in ($out -split "`r?`n")) {
            $t = $line.Trim()
            if ($t.StartsWith('{') -and $t.Contains('harness_score')) {
                try {
                    $row = $t | ConvertFrom-Json
                    $score = $row.harness_score
                    $diffNet = $row.diff_net
                    $gates = $row.gates_pass
                    $files = $row.files_changed
                    $added = $row.diff_added
                } catch { }
            }
            if ($t -match '\[measure-card-lite\]') { Write-Host $t }
        }

        $results.Add([pscustomobject]@{
            arm = $arm; ticket = $ticket; harness_score = $score
            diff_added = $added; diff_net = $diffNet; files_changed = $files; gates_pass = $gates
        })

        Restore-Original $card.Path $originals[$card.Path]
    }
}

if (-not $KeepLocalOverlay) {
    Remove-Item (Join-Path $root 'contexts\runtime\platform.local.json') -Force -ErrorAction SilentlyContinue
}

$jsonPath = Join-Path $resultsDir '2026-07-10-4way-instrumented.json'
$results | ConvertTo-Json -Depth 4 | Set-Content $jsonPath -Encoding UTF8
Write-Host "`n== Per-run table ==" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "== CompareCombinations ==" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'eval\metrics\report.ps1') -CompareCombinations -Last 40
Write-Host "Wrote $jsonPath"
