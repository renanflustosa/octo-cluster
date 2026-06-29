# Single entrypoint for /ship orchestration.
# Usage: invoke-ship.ps1 [-Phase all|gates|git|...] [-ScriptArgs @{ CommitMessage = "..." }]

param(
    [ValidateSet('all', 'discover', 'preflight', 'verification', 'gates', 'git', 'reviews')]
    [string]$Phase = 'all',
    [hashtable]$ScriptArgs = @{},
    [string]$Domain,
    [string]$CommitMessage,
    [string]$FeatureBranch,
    [string]$PrTitle,
    [string]$PrBodyFile,
    [switch]$SkipCommit,
    [switch]$SkipGit
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")

if ($CommitMessage) { $ScriptArgs['CommitMessage'] = $CommitMessage }
if ($FeatureBranch) { $ScriptArgs['FeatureBranch'] = $FeatureBranch }
if ($PrTitle) { $ScriptArgs['PrTitle'] = $PrTitle }
if ($PrBodyFile) { $ScriptArgs['PrBodyFile'] = $PrBodyFile }
if ($SkipCommit) { $ScriptArgs['SkipCommit'] = $true }
if ($SkipGit) { $ScriptArgs['SkipGit'] = $true }

$orchestrator = Join-Path (Get-CoreScriptsRoot) "core-ship-orchestrator.ps1"
if (-not (Test-Path $orchestrator)) {
    throw "Missing orchestrator: $orchestrator"
}

$params = @('-ExecutionPolicy', 'Bypass', '-File', $orchestrator, '-Phase', $Phase)
if ($Domain) {
    Write-Host "[deprecation] invoke-ship -Domain is deprecated; use AI_EXECUTION_CONTEXT" -ForegroundColor Yellow
    $params += @('-Domain', $Domain)
}
foreach ($key in $ScriptArgs.Keys) {
    $val = $ScriptArgs[$key]
    if ($val -is [switch]) {
        if ($val) { $params += "-$key" }
    } else {
        $params += @("-$key", [string]$val)
    }
}

Write-Host "[invoke-ship] $orchestrator -Phase $Phase" -ForegroundColor DarkGray
& powershell @params
exit $LASTEXITCODE
