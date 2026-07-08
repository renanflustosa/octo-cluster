# Project .cursorignore from canonical .aiignore
param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$aiignore = Join-Path $Root '.aiignore'
$cursorignore = Join-Path $Root '.cursorignore'

if (-not (Test-Path $aiignore)) {
    throw "Missing .aiignore at $Root"
}

$header = @"
# Canonical: .aiignore — keep sections in sync

"@
$body = Get-Content $aiignore -Raw
Set-Content -Path $cursorignore -Value ($header + $body.TrimEnd() + "`n") -Encoding utf8NoBOM -NoNewline
Write-Host "[sync] $cursorignore <- $aiignore" -ForegroundColor Green
