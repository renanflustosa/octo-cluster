# Discover and run LinkedIn publish providers (pipeline=linkedin, phase=publish).
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('en', 'pt')]
    [string]$Locale,

    [switch]$Confirm
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')
. (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')

$root = Get-OctoClusterRoot
$manifestPathResolved = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath
} else {
    Join-Path $root ($ManifestPath -replace '/', '\')
}

if (-not (Test-Path $manifestPathResolved)) {
    Write-Error "Manifest not found: $manifestPathResolved"
    exit 1
}

if (-not $Confirm) {
    Write-Error 'Publishing requires -Confirm (user confirmed in preview).'
    exit 1
}

$repoPath = $root
$shipCtx = Get-ShipExecutionContext -RepoPath $repoPath

function Get-LinkedInPublishProviders {
    param([string]$WorkspaceRoot, [string]$RepoPath, [hashtable]$ShipContext)

    $providers = @(Get-DiscoveredCapabilities -Pipeline linkedin -Phase publish -RepoPath $RepoPath -ShipContext $ShipContext)
    if ($providers.Count -gt 0) { return $providers }

    $privateRoot = Join-Path $WorkspaceRoot 'capabilities\_private'
    if (-not (Test-Path $privateRoot)) { return @() }

    $seen = @{}
    $found = New-Object System.Collections.ArrayList
    $activeRepoName = if ($ShipContext.active_repo) { [string]$ShipContext.active_repo } else { 'octo-cluster' }

    foreach ($packDir in Get-ChildItem -Path $privateRoot -Directory -ErrorAction SilentlyContinue) {
        $packId = $packDir.Name
        $manifestFile = Join-Path $packDir.FullName 'linkedin\manifest.yaml'
        if (-not (Test-Path $manifestFile)) { continue }

        $target = New-Object System.Collections.ArrayList
        Add-CapabilityManifestProviders -PackId $packId -Pipeline linkedin -Phase publish `
            -RepoPath $RepoPath -ShipContext $ShipContext -ActiveRepoName $activeRepoName `
            -WorkspaceRoot $WorkspaceRoot -SeenIds $seen -TargetList $target
        foreach ($p in $target) { [void]$found.Add($p) }
    }

    return @($found)
}

$providers = @(Get-LinkedInPublishProviders -WorkspaceRoot $root -RepoPath $repoPath -ShipContext $shipCtx)

if ($providers.Count -eq 0) {
    Write-Host '[linkedin-publish] no publish provider found' -ForegroundColor Yellow
    Write-Host '[linkedin-publish] scaffold: capabilities/_private/<pack>/linkedin/ (see README)' -ForegroundColor DarkGray
    Write-Host '[linkedin-publish] fallback: copy post from preview and paste on linkedin.com/feed' -ForegroundColor DarkGray
    exit 2
}

foreach ($provider in $providers) {
    if (-not $provider._script_path -or -not (Test-Path $provider._script_path)) {
        Write-Host "WARN: provider '$($provider.id)' missing script" -ForegroundColor Yellow
        continue
    }

    Write-Host "== linkedin publish provider: $($provider.id) (locale=$Locale) ==" -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $provider._script_path `
        -ManifestPath $manifestPathResolved -Locale $Locale -Confirm

    $code = if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq '') { 0 } else { [int]$LASTEXITCODE }
    if ($code -ne 0) {
        Write-Host "[linkedin-publish] provider $($provider.id) failed (exit $code)" -ForegroundColor Red
        exit $code
    }

    Write-Host "[linkedin-publish] published locale=$Locale via $($provider.id)" -ForegroundColor Green
    exit 0
}

Write-Error 'All publish providers failed or missing scripts.'
exit 1
