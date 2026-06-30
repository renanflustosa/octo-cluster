# Generic pipeline entrypoint (ship, scan, model, close, start-workspace, ...).
# Usage: invoke-pipeline.ps1 -Pipeline scan [-Action discover|run] [-ScriptArgs @{ ... }]

param(
    [Parameter(Mandatory = $true)][string]$Pipeline,
    [ValidateSet('discover', 'run')]
    [string]$Action = 'run',
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
    [switch]$SkipCommit
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_octo-args.ps1")

if ($CommitMessage) { $ScriptArgs['CommitMessage'] = $CommitMessage }
if ($FeatureBranch) { $ScriptArgs['FeatureBranch'] = $FeatureBranch }
if ($PrTitle) { $ScriptArgs['PrTitle'] = $PrTitle }
if ($PrBodyFile) { $ScriptArgs['PrBodyFile'] = $PrBodyFile }
if ($SkipGit) { $ScriptArgs['SkipGit'] = $true }
if ($SkipCommit) { $ScriptArgs['SkipCommit'] = $true }

$allowed = @('ship', 'scan', 'model', 'close', 'start-workspace', 'review', 'debug')
if ($Pipeline -notin $allowed) {
    throw "Invalid pipeline '$Pipeline'. Allowed: $($allowed -join ', ')"
}

. (Join-Path $PSScriptRoot "_load-env.ps1")
. (Join-Path (Get-CoreScriptsRoot) "discover-capabilities.ps1")

function Invoke-DomainScript {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [hashtable]$BoundArgs = @{},
        [string]$DomainOverride
    )

    $invokeScript = Join-Path $PSScriptRoot "invoke-domain-script.ps1"
    $bound = @{
        Name       = $Name
        ScriptArgs = $BoundArgs
    }
    if ($DomainOverride) { $bound['Domain'] = $DomainOverride }
    Invoke-OctoBoundScript -Path $invokeScript -BoundArgs $bound
}

if (-not $RepoPath) {
    $RepoPath = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { $RepoPath = $null }
}

$shipCtx = Get-ShipExecutionContext -RepoPath $RepoPath
$skillPath = Get-DiscoveredCapabilitySkill -Pipeline $Pipeline -RepoPath $RepoPath -ShipContext $shipCtx

Write-Host "PIPELINE=$Pipeline" -ForegroundColor DarkGray
Write-Host "PIPELINE_SKILL=$skillPath" -ForegroundColor DarkGray
Write-Host ("PIPELINE_CONTEXT=" + ($shipCtx | ConvertTo-Json -Compress)) -ForegroundColor DarkGray

if ($Action -eq 'discover') {
    exit 0
}

switch ($Pipeline) {
    'ship' {
        $invokeShip = Join-Path $PSScriptRoot "invoke-ship.ps1"
        $shipArgs = Merge-OctoScriptArgs -Base $ScriptArgs -Flat @{ Phase = $Phase }
        if ($Domain) { $shipArgs['Domain'] = $Domain }
        Write-Host "[invoke-pipeline] ship -> invoke-ship.ps1 -Phase $Phase" -ForegroundColor DarkGray
        Invoke-OctoBoundScript -Path $invokeShip -BoundArgs $shipArgs
        exit $LASTEXITCODE
    }
    'start-workspace' {
        Write-Host "[invoke-pipeline] start-workspace -> invoke-domain-script.ps1" -ForegroundColor DarkGray
        Invoke-DomainScript -Name start-workspace -BoundArgs $ScriptArgs -DomainOverride $Domain
        exit $LASTEXITCODE
    }
    'close' {
        Write-Host "[invoke-pipeline] close -> invoke-domain-script.ps1" -ForegroundColor DarkGray
        Invoke-DomainScript -Name close -BoundArgs $ScriptArgs -DomainOverride $Domain
        exit $LASTEXITCODE
    }
    'scan' {
        Write-Host "[invoke-pipeline] scan -> invoke-domain-script.ps1 -Name scan-bootstrap" -ForegroundColor DarkGray
        Invoke-DomainScript -Name scan-bootstrap -BoundArgs $ScriptArgs -DomainOverride $Domain
        exit $LASTEXITCODE
    }
    'model' {
        Write-Host "[invoke-pipeline] model is plan-only - no run action" -ForegroundColor Yellow
        exit 0
    }
    'review' {
        Write-Host "[invoke-pipeline] review is agent-only - read PIPELINE_SKILL" -ForegroundColor Yellow
        exit 0
    }
    'debug' {
        Write-Host "[invoke-pipeline] debug is agent-only - read PIPELINE_SKILL" -ForegroundColor Yellow
        exit 0
    }
}

exit 0
