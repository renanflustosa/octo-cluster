#Requires -Version 5.1
<#
.SYNOPSIS
  Directional 4-arm bakeoff via Cursor SDK (n=5 cards x 4 arms = 20 runs).
  Loads API key from local secrets vault on demand — never prints it.
#>
param(
    [string]$Model = 'composer-2.5',
    [string]$KeyFile = '',
    [string]$Root = 'C:\octo-cluster',
    [int]$NCards = 5,
    [int]$MaxRuns = 0,
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
if ($MaxRuns -le 0) { $MaxRuns = $NCards * 4 }
$env:OCTO_CLUSTER = $Root
$env:BAKEOFF_MODEL = $Model
$env:BAKEOFF_N_CARDS = [string]$NCards
$env:BAKEOFF_MAX_RUNS = [string]$MaxRuns

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { Write-Host 'node not found'; exit 1 }

$runnerDir = Join-Path $Root 'eval\agentic\fixtures\_sdk-runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'eval\agentic\results') | Out-Null

Push-Location $runnerDir
try {
    # npm writes warnings to stderr; do not treat as terminating under Stop
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if (-not $SkipSdkInstall -and -not (Test-Path 'node_modules\@cursor\sdk')) {
        if (-not (Test-Path 'package.json')) {
            npm init -y 2>&1 | Out-Null
        }
        Write-Host 'Installing @cursor/sdk (local)...' -ForegroundColor Cyan
        npm install @cursor/sdk@latest --no-fund --no-audit 2>&1 | ForEach-Object { Write-Host $_ }
        if (-not (Test-Path 'node_modules\@cursor\sdk')) {
            throw 'npm install @cursor/sdk failed'
        }
    }
    $ErrorActionPreference = $prevEap
    $mjs = Join-Path $PSScriptRoot 'run-bakeoff.mjs'
    if (-not (Test-Path $mjs)) { throw "Missing run-bakeoff.mjs next to this script" }
    Copy-Item -LiteralPath $mjs -Destination (Join-Path $runnerDir 'run-bakeoff.mjs') -Force
    Write-Host "Starting bakeoff n_cards=$NCards max_runs=$MaxRuns model=$Model (key loaded: yes, len=$($env:CURSOR_API_KEY.Length))" -ForegroundColor Cyan
    & node .\run-bakeoff.mjs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} finally {
    # scrub env in this process
    Remove-Item Env:CURSOR_API_KEY -ErrorAction SilentlyContinue
    Pop-Location
}
exit $code
