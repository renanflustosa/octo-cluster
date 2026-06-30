# Single entrypoint for /ship orchestration.
# Usage: invoke-ship.ps1 [-Phase all|gates|git|...] [-ScriptArgs @{ CommitMessage = "..." }]

param(
    [ValidateSet('all', 'discover', 'preflight', 'verification', 'gates', 'git', 'reviews')]
    [string]$Phase = 'all',
    [hashtable]$ScriptArgs = @{},
    [string]$Domain,
    [string]$RepoPath,
    [string]$CommitMessage,
    [string]$FeatureBranch,
    [string]$PrTitle,
    [string]$PrBodyFile,
    [switch]$SkipGit,
    [switch]$SkipCommit,
    [switch]$SkipEval,
    [switch]$SkipChildGate
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")

$orchestrator = Join-Path (Get-CoreScriptsRoot) "core-ship-orchestrator.ps1"
if (-not (Test-Path $orchestrator)) {
    throw "Missing orchestrator: $orchestrator"
}

$bound = @{}
foreach ($key in $ScriptArgs.Keys) { $bound[$key] = $ScriptArgs[$key] }
if ($CommitMessage) { $bound['CommitMessage'] = $CommitMessage }
if ($FeatureBranch) { $bound['FeatureBranch'] = $FeatureBranch }
if ($PrTitle) { $bound['PrTitle'] = $PrTitle }
if ($PrBodyFile) { $bound['PrBodyFile'] = $PrBodyFile }
if ($RepoPath) { $bound['RepoPath'] = $RepoPath }
if ($SkipGit) { $bound['SkipGit'] = $true }
if ($SkipCommit) { $bound['SkipCommit'] = $true }
if ($SkipEval) { $bound['SkipEval'] = $true }
if ($SkipChildGate) { $bound['SkipChildGate'] = $true }

$params = @('-ExecutionPolicy', 'Bypass', '-File', $orchestrator, '-Phase', $Phase)
if ($Domain) {
    Write-Host "[deprecation] invoke-ship -Domain is deprecated; use AI_EXECUTION_CONTEXT" -ForegroundColor Yellow
    $params += @('-Domain', $Domain)
}
foreach ($key in $bound.Keys) {
    $val = $bound[$key]
    if ($val -is [switch]) {
        if ($val) { $params += "-$key" }
    } else {
        $params += @("-$key", [string]$val)
    }
}

Write-Host "[invoke-ship] $orchestrator -Phase $Phase" -ForegroundColor DarkGray
& powershell @params
exit $LASTEXITCODE
