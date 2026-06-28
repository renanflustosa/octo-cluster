# DEPRECATED: use discover-capabilities.ps1
# Shim retained for scripts that dot-source discover-ship-providers.ps1.

param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')

function Get-DiscoveredShipProviders {
    param(
        [string]$Phase,
        [string]$Domain,
        [string]$RepoPath,
        [hashtable]$ShipContext
    )

    Write-Host "[deprecation] discover-ship-providers.ps1 -> discover-capabilities.ps1" -ForegroundColor Yellow
    return Get-DiscoveredCapabilities -Pipeline ship -Phase $Phase -Domain $Domain -RepoPath $RepoPath -ShipContext $ShipContext
}

function Get-DiscoveredShipSkill {
    param(
        [string]$Domain,
        [string]$RepoPath,
        [hashtable]$ShipContext
    )

    Write-Host "[deprecation] Get-DiscoveredShipSkill -> Get-DiscoveredCapabilitySkill" -ForegroundColor Yellow
    return Get-DiscoveredCapabilitySkill -Pipeline ship -Domain $Domain -RepoPath $RepoPath -ShipContext $ShipContext
}

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    Get-DiscoveredShipProviders | ConvertTo-Json -Depth 6
}
