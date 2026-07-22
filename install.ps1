#Requires -Version 5.1
<#
.SYNOPSIS
  Minimal octo-cluster setup for Win11 + Cursor.
  Installs the repository git hooks (pre-commit / pre-push boundary gates).
.EXAMPLE
  pwsh -File install.ps1
#>
param()

$ErrorActionPreference = 'Stop'
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = $PSScriptRoot }
Set-Location $root

if (-not (Test-Path (Join-Path $root '.githooks'))) {
    throw "Missing hooks directory: $root/.githooks"
}

git config core.hooksPath .githooks
Write-Host "Installed git hooksPath -> .githooks (pre-commit + pre-push run boundary-audit)." -ForegroundColor Green
Write-Host ""
Write-Host "Done. Next: open the repo in Cursor and use /ship, /review, /debug, /prompt."
