# Placeholder for future multi-tool adapter sync.
param(
    [string]$Domain,
    [string]$Tool = "cursor",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")

$root = Get-OctoClusterRoot
$domains = Join-Path $root "domains"
$adapters = Join-Path $root "adapters"
$generated = Join-Path $root "generated"

$activeDomain = Get-ResolvedChildDomain -Override $Domain
if (-not $activeDomain) {
    Write-Error "No child domain in execution context. Set AI_EXECUTION_CONTEXT or pass -Domain."
}

$domainRoot = Join-Path $domains $activeDomain
$adapterRoot = Join-Path $adapters $Tool
$generatedRoot = Join-Path $generated $Tool

if (-not (Test-Path $domainRoot)) {
    Write-Error "Domain '$activeDomain' not found at $domainRoot"
}

if (-not (Test-Path $adapterRoot)) {
    Write-Error "Adapter '$Tool' not found at $adapterRoot"
}

if (-not (Test-Path $generatedRoot) -and -not $WhatIf) {
    New-Item -ItemType Directory -Force -Path $generatedRoot | Out-Null
}

Write-Host "Adapter sync placeholder: domain=$activeDomain tool=$Tool"
Write-Host "core=$domains\core"
Write-Host "domain=$domainRoot"
Write-Host "adapter=$adapterRoot"
Write-Host "generated=$generatedRoot"

if ($WhatIf) {
    Write-Host "Would generate adapter output from core + domain."
}
else {
    Write-Host "Adapter generation is not implemented yet."
}
