#Requires -Version 5.1
<#
.SYNOPSIS
  Phase 0 smoke: 1 SDK run + usage API attribution test.
#>
param(
    [string]$KeyFile = '',
    [string]$Root = 'C:\octo-cluster',
    [string]$Model = 'composer-2.5',
    [switch]$SkipSdkInstall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'load-cursor-vault-key.ps1')
try {
    $vault = $env:PERSONAL_VAULT
    if (-not $vault) { $vault = $env:PERSONAL_VAULT_ROOT }
    $env:CURSOR_API_KEY = Initialize-CursorApiKeyFromVault -KeyFile $KeyFile -VaultRoot $vault
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}
$env:OCTO_CLUSTER = $Root
$env:BAKEOFF_MODEL = $Model

$runnerDir = Join-Path $Root 'eval\agentic\fixtures\_sdk-runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
Push-Location $runnerDir
try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if (-not $SkipSdkInstall -and -not (Test-Path 'node_modules\@cursor\sdk')) {
        if (-not (Test-Path 'package.json')) { npm init -y 2>&1 | Out-Null }
        npm install @cursor/sdk@latest --no-fund --no-audit 2>&1 | ForEach-Object { Write-Host $_ }
    }
    $ErrorActionPreference = $prevEap
    Copy-Item (Join-Path $PSScriptRoot 'run-smoke-phase0.mjs') (Join-Path $runnerDir 'run-smoke-phase0.mjs') -Force
    & node .\run-smoke-phase0.mjs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} finally {
    Remove-Item Env:CURSOR_API_KEY -ErrorAction SilentlyContinue
    Pop-Location
}
exit $code
