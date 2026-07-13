#Requires -Version 5.1
<#
.SYNOPSIS
  Binary COM vs SEM bakeoff via Cursor SDK (default N=3 cards x 2 arms = 6 runs).
  Loads API key from local secrets vault on demand — never prints it.
#>
param(
    [string]$Model = 'composer-2.5',
    [string]$KeyFile = '',
    [string]$Root = 'C:\octo-cluster',
    [int]$NCards = 3,
    [ValidateSet(2, 3)]
    [int]$Phase = 3,
    [string]$Arms = 'sem,com',
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

if ($Phase -eq 2) {
    if ($MaxRuns -le 0) { $MaxRuns = 2 }
} elseif ($MaxRuns -le 0) {
    $MaxRuns = $NCards * 2
}

$env:OCTO_CLUSTER = $Root
$env:BAKEOFF_MODEL = $Model
$env:BAKEOFF_N_CARDS = [string]$NCards
$env:BAKEOFF_MAX_RUNS = [string]$MaxRuns
$env:BAKEOFF_ARMS = $Arms
$env:BAKEOFF_PHASE = [string]$Phase

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { Write-Host 'node not found'; exit 1 }

$runnerDir = Join-Path $Root 'eval\agentic\fixtures\_sdk-runner'
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'eval\agentic\results') | Out-Null

Push-Location $runnerDir
try {
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
    $mjs = Join-Path $PSScriptRoot 'run-com-vs-sem.mjs'
    if (-not (Test-Path $mjs)) { throw 'Missing run-com-vs-sem.mjs next to this script' }
    Copy-Item -LiteralPath $mjs -Destination (Join-Path $runnerDir 'run-com-vs-sem.mjs') -Force
    Write-Host "Starting COM-vs-SEM phase=$Phase n_cards=$NCards max_runs=$MaxRuns arms=$Arms model=$Model (key loaded: yes, len=$($env:CURSOR_API_KEY.Length))" -ForegroundColor Cyan
    & node .\run-com-vs-sem.mjs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
} finally {
    Remove-Item Env:CURSOR_API_KEY -ErrorAction SilentlyContinue
    Pop-Location
}
exit $code
