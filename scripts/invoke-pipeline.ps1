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
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"

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
    $params = @('-ExecutionPolicy', 'Bypass', '-File', $invokeScript, '-Name', $Name)
    if ($DomainOverride) { $params += @('-Domain', $DomainOverride) }
    foreach ($key in $BoundArgs.Keys) {
        $val = $BoundArgs[$key]
        if ($val -is [switch]) {
            if ($val) { $params += "-$key" }
        } else {
            $params += @("-$key", [string]$val)
        }
    }
    & powershell @params
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
        $params = @('-ExecutionPolicy', 'Bypass', '-File', $invokeShip, '-Phase', $Phase)
        if ($Domain) { $params += @('-Domain', $Domain) }
        foreach ($key in $ScriptArgs.Keys) {
            $val = $ScriptArgs[$key]
            if ($val -is [switch]) {
                if ($val) { $params += "-$key" }
            } else {
                $params += @("-$key", [string]$val)
            }
        }
        Write-Host "[invoke-pipeline] ship -> invoke-ship.ps1 -Phase $Phase" -ForegroundColor DarkGray
        & powershell @params
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
