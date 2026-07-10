#Requires -Version 5.1
# Prepare one real bakeoff chat: set arm overlay + stamp usage baseline + print prompt.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('nada', 'baseline', 'compress-on', 'octo-full')]
    [string]$Arm,

    [Parameter(Mandatory = $true)]
    [ValidateSet('BC-01', 'BC-02', 'BC-03', 'BC-04', 'BC-05')]
    [string]$Card
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
if (-not (Test-Path (Join-Path $root 'eval\agentic\fixtures\runtime-arms'))) {
    $root = 'C:\octo-cluster'
}

$armSrc = Join-Path $root "eval\agentic\fixtures\runtime-arms\$Arm.json"
$armDst = Join-Path $root 'contexts\runtime\platform.local.json'
Copy-Item -LiteralPath $armSrc -Destination $armDst -Force

$ticket = "$Card-$Arm"
$stamp = Join-Path $root 'eval\metrics\stamp-usage-baseline.ps1'
if (Test-Path $stamp) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stamp -Ticket $ticket -Profile octo-cluster 2>&1 | Out-Host
}

$cardFile = Join-Path $root "eval\agentic\fixtures\bakeoff-cards\$Card.md"
$raw = Get-Content -LiteralPath $cardFile -Raw -Encoding UTF8
$prompt = $null
if ($raw -match '(?s)```text\r?\n(.*?)```') {
    $prompt = $Matches[1].Trim()
}

Write-Host ""
Write-Host "=== REAL CHAT READY ===" -ForegroundColor Green
Write-Host "Arm:    $Arm"
Write-Host "Card:   $Card"
Write-Host "Ticket: $ticket"
Write-Host "Overlay: contexts/runtime/platform.local.json"
Write-Host ""
Write-Host "1) Open a NEW Agent chat"
Write-Host "2) Paste this prompt:"
Write-Host "-----"
Write-Host $prompt
Write-Host "-----"
Write-Host "3) After the agent finishes, run:"
Write-Host ("   pwsh eval/metrics/measure-card-lite.ps1 -Ticket `"{0}`" -CombinationId {1} -RepoRoot (Get-Location) -BaseRef HEAD -ShipVerdict READY" -f $ticket, $Arm)
Write-Host "   OR /close with CARD $ticket"
Write-Host ""
