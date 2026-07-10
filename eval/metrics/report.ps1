# Report card + harness trends from SQLite metrics store.
param(
    [int]$Last = 10,

    [ValidateSet('baseline', 'ponytail-lite', 'caveman-only', 'yagni-oneliner', 'default', 'all')]
    [string]$Arm = 'all',

    [switch]$CompareCombinations
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')

$root = Get-OctoClusterRoot
$storeScript = Join-Path $root 'engine\metrics\metrics-store.ps1'

if (-not (Test-Path $storeScript)) {
    Write-Host "metrics-store not found" -ForegroundColor Red
    exit 1
}

# migrate legacy CSV once if DB empty
$dbPath = Join-Path $root 'state\metrics\metrics.db'
if (-not (Test-Path $dbPath)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $storeScript -StoreAction init 2>&1 | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File $storeScript -StoreAction migrate-csv 2>&1 | Out-Null
}

if ($CompareCombinations) {
    $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $storeScript -StoreAction compare-combinations -Last $Last
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $data = ($raw | Out-String).Trim() | ConvertFrom-Json
    Write-Host "== Combination ranking (last $($data.last)) ==" -ForegroundColor Cyan
    if ($data.winner) {
        Write-Host ("winner: {0}" -f $data.winner) -ForegroundColor Green
    }
    Write-Host ""
    foreach ($c in $data.by_combination) {
        $avgScore = if ($null -ne $c.avg_harness_score) { [math]::Round([double]$c.avg_harness_score, 1) } else { '-' }
        $avgTok = if ($null -ne $c.avg_tokens) { [math]::Round([double]$c.avg_tokens, 0) } else { '-' }
        $avgGate = if ($null -ne $c.avg_gate_pass) { [math]::Round([double]$c.avg_gate_pass, 2) } else { '-' }
        Write-Host ("  {0,-20} n={1} score={2} tokens={3} gate={4} measured={5} skipped={6}" -f `
            $c.combination_id, $c.n, $avgScore, $avgTok, $avgGate, $c.n_measured, $c.n_estimated_or_skipped)
    }
    exit 0
}

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $storeScript -StoreAction trends -Last $Last -Arm $Arm
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$data = ($raw | Out-String).Trim() | ConvertFrom-Json

Write-Host "== Octo Cluster metrics (last $Last, arm=$Arm) ==" -ForegroundColor Cyan

if ($data.by_arm) {
    Write-Host ""
    Write-Host "by arm:" -ForegroundColor Cyan
    foreach ($a in $data.by_arm) {
        $avgDiff = if ($a.avg_diff_added) { [math]::Round([double]$a.avg_diff_added, 1) } else { '-' }
        $avgTok = if ($a.avg_tokens) { [math]::Round([double]$a.avg_tokens, 0) } else { '-' }
        $avgCost = if ($a.avg_cost) { [math]::Round([double]$a.avg_cost, 2) } else { '-' }
        $avgScore = if ($null -ne $a.avg_harness_score) { [math]::Round([double]$a.avg_harness_score, 1) } else { '-' }
        Write-Host ("  {0,-16} n={1} avg_diff={2} avg_tokens={3} avg_cost=`${4} score={5}" -f $a.arm, $a.n, $avgDiff, $avgTok, $avgCost, $avgScore)
    }
}

if ($data.recent_cards) {
    Write-Host ""
    Write-Host "recent cards:" -ForegroundColor Cyan
    foreach ($c in $data.recent_cards) {
        $cid = if ($c.combination_id) { $c.combination_id } else { '-' }
        Write-Host ("  {0} {1} arm={2} combo={3} tokens={4} cost=`${5} diff={6} score={7}" -f `
            $c.recorded_at, $c.ticket, $c.arm, $cid, $c.tokens_total, $c.cost_usd, $c.diff_added, $c.harness_score)
    }
}

if ($data.harness_snapshots) {
    Write-Host ""
    Write-Host "harness snapshots:" -ForegroundColor Cyan
    foreach ($h in $data.harness_snapshots) {
        Write-Host ("  {0} score={1} cmd={2} skills={3}" -f $h.recorded_at, $h.harness_score, $h.commands_lines, $h.skills_lines)
    }
}

exit 0
