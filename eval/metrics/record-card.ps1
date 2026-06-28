# Deprecated wrapper — use measure-card-lite.ps1 (SQLite).
param(
    [Parameter(Mandatory = $true)]
    [string]$Ticket,
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [string]$BaseRef = 'develop',
    [string]$Arm = 'default',
    [int]$ChatTurns = 0,
    [string]$ShipVerdict = 'unknown',
    [switch]$ExcludeTests,
    [string]$Notes = ''
)

$lite = Join-Path $PSScriptRoot 'measure-card-lite.ps1'
$noteCombined = $Notes
if ($ChatTurns -gt 0) {
    $noteCombined = if ($Notes) { "$Notes; chat_turns=$ChatTurns" } else { "chat_turns=$ChatTurns" }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $lite `
    -Ticket $Ticket -RepoRoot $RepoRoot -BaseRef $BaseRef -Arm $Arm `
    -ShipVerdict $ShipVerdict -Notes $noteCombined `
    @($(if ($ExcludeTests) { '-ExcludeTests' }))
exit $LASTEXITCODE
