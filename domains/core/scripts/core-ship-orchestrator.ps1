# Ship orchestrator - runs discovered providers and repository-policy git delivery.
# Usage: core-ship-orchestrator.ps1 [-Phase all|preflight|verification|gates|git|reviews|discover]

param(
    [ValidateSet('all', 'discover', 'preflight', 'verification', 'gates', 'git', 'reviews')]
    [string]$Phase = 'all',
    [string]$RepoPath,
    [string]$Domain,
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
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
. (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')

function Invoke-ShipProvider {
    param(
        [hashtable]$Provider,
        [hashtable]$BoundArgs = @{}
    )

    if (-not $Provider._script_path -or -not (Test-Path $Provider._script_path)) {
        throw "Provider '$($Provider.id)' script not found: $($Provider._script_path)"
    }

    Write-Host "== ship provider: $($Provider.id) ($($Provider.phase)) ==" -ForegroundColor Cyan
    $params = @('-ExecutionPolicy', 'Bypass', '-File', $Provider._script_path)
    foreach ($key in $BoundArgs.Keys) {
        $val = $BoundArgs[$key]
        if ($val -is [switch]) {
            if ($val) { $params += "-$key" }
        } else {
            $params += @("-$key", [string]$val)
        }
    }
    & powershell @params | Out-Null
    if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq '') { return 0 }
    return [int]$LASTEXITCODE
}

function Invoke-ShipPhase {
    param(
        [Parameter(Mandatory = $true)][string]$PhaseName,
        [string]$RepoPath,
        [hashtable]$ShipContext
    )

    $providers = Get-DiscoveredCapabilities -Pipeline ship -Phase $PhaseName -RepoPath $RepoPath -ShipContext $ShipContext
    if (-not $providers -or $providers.Count -eq 0) {
        Write-Host "`[ship] no providers for phase $PhaseName" -ForegroundColor DarkGray
        return 0
    }

    $bound = @{}
    if ($SkipEval) { $bound.SkipEval = $true }
    if ($SkipChildGate) { $bound.SkipChildGate = $true }

    foreach ($provider in $providers) {
        $blocking = $true
        if ($null -ne $provider.blocking) { $blocking = [bool]$provider.blocking }
        if ($PhaseName -eq 'reviews') { $blocking = $false }

        $providerArgs = @{}
        foreach ($key in $bound.Keys) { $providerArgs[$key] = $bound[$key] }
        if ($provider._legacy) { $providerArgs.SkipEval = $true }

        $code = Invoke-ShipProvider -Provider $provider -BoundArgs $providerArgs
        if ($code -ne 0) {
            if ($blocking) {
                Write-Host "`[BLOCKED] provider $($provider.id) failed (exit $code)" -ForegroundColor Red
                return $code
            }
            Write-Host "`[warn] non-blocking provider $($provider.id) failed (exit $code)" -ForegroundColor Yellow
        }
    }
    return 0
}

if (-not $RepoPath) {
    $RepoPath = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Not inside a git repository." }
}
$RepoPath = (Resolve-Path $RepoPath).Path

$shipCtx = Get-ShipExecutionContext -RepoPath $RepoPath
if ($Domain -and -not $env:AI_EXECUTION_CONTEXT) {
    Write-Host "[deprecation] -Domain is deprecated; use AI_EXECUTION_CONTEXT" -ForegroundColor Yellow
}

$runPhases = if ($Phase -eq 'all') {
    @('discover', 'preflight', 'verification', 'gates', 'git', 'reviews')
} else {
    @($Phase)
}

$skillPath = Get-DiscoveredCapabilitySkill -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx
Write-Host "SHIP_SKILL=$skillPath" -ForegroundColor DarkGray
Write-Host ("SHIP_CONTEXT=" + ($shipCtx | ConvertTo-Json -Compress)) -ForegroundColor DarkGray

foreach ($phaseName in $runPhases) {
    switch ($phaseName) {
        'discover' {
            $policy = Get-RepoPolicy -RepoPath $RepoPath
            Write-Host "SHIP_REPO=$RepoPath" -ForegroundColor DarkGray
            Write-Host ("SHIP_POLICY=" + ($policy | ConvertTo-Json -Compress)) -ForegroundColor DarkGray
            $providerCount = @(Get-DiscoveredCapabilities -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx).Count
            Write-Host "SHIP_PROVIDERS=$providerCount" -ForegroundColor DarkGray
            foreach ($provider in Get-DiscoveredCapabilities -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx) {
                Write-Host ("  provider: $($provider.id) ($($provider.phase))") -ForegroundColor DarkGray
            }
        }
        'git' {
            if ($SkipGit) {
                Write-Host "`[ship] skip git phase" -ForegroundColor Yellow
                continue
            }
            $gitScript = Join-Path $PSScriptRoot 'core-ship-git.ps1'
            $gitArgs = @{
                RepoPath = $RepoPath
            }
            if ($CommitMessage) { $gitArgs.CommitMessage = $CommitMessage }
            if ($FeatureBranch) { $gitArgs.FeatureBranch = $FeatureBranch }
            if ($PrTitle) { $gitArgs.PrTitle = $PrTitle }
            if ($PrBodyFile) { $gitArgs.PrBodyFile = $PrBodyFile }
            if ($SkipCommit) { $gitArgs.SkipCommit = $true }

            $params = @('-ExecutionPolicy', 'Bypass', '-File', $gitScript)
            foreach ($key in $gitArgs.Keys) {
                $val = $gitArgs[$key]
                if ($val -is [switch]) {
                    if ($val) { $params += "-$key" }
                } else {
                    $params += @("-$key", [string]$val)
                }
            }
            Write-Host "== ship phase: git (repository-policy) ==" -ForegroundColor Cyan
            & powershell @params
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        default {
            $code = Invoke-ShipPhase -PhaseName $phaseName -RepoPath $RepoPath -ShipContext $shipCtx
            if ($code -ne 0) { exit $code }
        }
    }
}

if ($Phase -eq 'gates' -or $Phase -eq 'all') {
    $logDir = Join-Path (Get-OctoClusterRoot) "state\logs\metrics-baseline"
    $stampFile = Join-Path $logDir "last-core-gate-pass.txt"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8
}

Write-Host "`[ok] ship orchestrator completed (phase=$Phase)" -ForegroundColor Green
exit 0
