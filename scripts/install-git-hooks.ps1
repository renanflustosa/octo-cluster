#Requires -Version 5.1
<#
.SYNOPSIS
  Install .githooks/ as the repository hooksPath (pre-commit + pre-push boundary gates).
.EXAMPLE
  .\scripts\install-git-hooks.ps1
#>
param(
    [switch]$SkipIfSet
)

$ErrorActionPreference = 'Stop'
$root = if ($env:OCTO_CLUSTER) { $env:OCTO_CLUSTER } else { Split-Path $PSScriptRoot -Parent }
Set-Location $root

$hooksDir = Join-Path $root '.githooks'
if (-not (Test-Path $hooksDir)) {
    throw "Missing hooks directory: $hooksDir"
}

$current = git config --get core.hooksPath 2>$null
if ($current -and $SkipIfSet) {
    Write-Host "git hooksPath already set: $current" -ForegroundColor DarkGray
    return
}

git config core.hooksPath .githooks
Write-Host "Installed git hooksPath -> .githooks (pre-commit + pre-push run boundary-audit)" -ForegroundColor Green
