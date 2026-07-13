#Requires -Version 5.1
<#
.SYNOPSIS
  Binary AS-IS vs Octo-Full bakeoff (paired cards × 2 arms). Primary: harness_score + tokens_total.
  Loads API key from vault; session token via PERSONAL_VAULT SESSION.json — never prints secrets.
  N=5 default: 10 runs, ABAB order per card, 30s post-run pause for token attribution.
#>
param(
    [string]$Model = 'composer-2.5',
    [string]$KeyFile = '',
    [string]$Root = 'C:\octo-cluster',
    [string]$PersonalVault = '',
    [int]$NCards = 5,
    [ValidateSet('n3', 'n5')]
    [string]$Sample = 'n5',
    [ValidateSet(2, 3)]
    [int]$Phase = 3,
    [string]$Arms = 'asis,full',
    [int]$MaxRuns = 0,
    [int]$PauseMs = 30000,
    [int]$InterCardMs = 60000,
    [switch]$SkipSdkInstall
)

$ErrorActionPreference = 'Stop'

if (-not $PersonalVault) {
    $PersonalVault = $env:PERSONAL_VAULT
    if (-not $PersonalVault) { $PersonalVault = $env:PERSONAL_VAULT_ROOT }
}
. (Join-Path $PSScriptRoot 'load-cursor-vault-key.ps1')
try {
    $env:CURSOR_API_KEY = Initialize-CursorApiKeyFromVault -KeyFile $KeyFile -VaultRoot $PersonalVault
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}

if ($Phase -eq 2) {
    if ($MaxRuns -le 0) { $MaxRuns = 2 }
} elseif ($MaxRuns -le 0) {
    $MaxRuns = $NCards * 2
}

$env:OCTO_CLUSTER = $Root
$env:PERSONAL_VAULT = $PersonalVault
$env:BAKEOFF_MODEL = $Model
$env:BAKEOFF_N_CARDS = [string]$NCards
$env:BAKEOFF_MAX_RUNS = [string]$MaxRuns
$env:BAKEOFF_ARMS = $Arms
$env:BAKEOFF_PHASE = [string]$Phase
$env:BAKEOFF_SAMPLE = $Sample
$env:BAKEOFF_PAUSE_MS = [string]$PauseMs
$env:BAKEOFF_INTER_CARD_MS = [string]$InterCardMs

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host 'node not found'
    exit 1
}

$runnerDir = Join-Path $Root 'eval\agentic\fixtures\_sdk-runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'eval\agentic\results') | Out-Null

Push-Location $runnerDir
try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if (-not $SkipSdkInstall -and -not (Test-Path 'node_modules\@cursor\sdk')) {
        if (-not (Test-Path 'package.json')) { npm init -y 2>&1 | Out-Null }
        Write-Host 'Installing @cursor/sdk (local)...' -ForegroundColor Cyan
        npm install @cursor/sdk@latest --no-fund --no-audit 2>&1 | ForEach-Object { Write-Host $_ }
    }
    $ErrorActionPreference = $prevEap
    $mjs = Join-Path $PSScriptRoot 'run-asis-vs-full.mjs'
    if (-not (Test-Path $mjs)) { throw 'Missing run-asis-vs-full.mjs' }
    Copy-Item -LiteralPath $mjs -Destination (Join-Path $runnerDir 'run-asis-vs-full.mjs') -Force
    Write-Host "Starting ASIS-vs-FULL sample=$Sample phase=$Phase n_cards=$NCards max_runs=$MaxRuns arms=$Arms model=$Model pause_ms=$PauseMs (key loaded: yes)" -ForegroundColor Cyan
    & node .\run-asis-vs-full.mjs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} finally {
    Remove-Item Env:CURSOR_API_KEY -ErrorAction SilentlyContinue
    Pop-Location
}
exit $code
