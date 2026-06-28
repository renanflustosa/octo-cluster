# Write .cursor/capabilities-skills.json from capability manifests + execution context.
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")
. (Join-Path (Get-CoreScriptsRoot) "discover-capabilities.ps1")

$pipelines = @('ship', 'scan', 'model', 'close', 'start-workspace', 'review', 'debug')
$ctx = Get-ShipExecutionContext
$workspace = Get-OctoClusterRoot
$entries = @()

foreach ($pipeline in $pipelines) {
    $skill = Get-DiscoveredCapabilitySkill -Pipeline $pipeline -ShipContext $ctx
    $entries += [ordered]@{
        pipeline = $pipeline
        skill    = $skill
    }
}

$auxiliary = @()
foreach ($pack in @($ctx.enabled_capability_packs)) {
    if ($pack -eq 'core') { continue }
    $auxRoot = Join-Path $workspace "capabilities\$pack\skills"
    if (-not (Test-Path $auxRoot)) { continue }
    foreach ($dir in Get-ChildItem -Path $auxRoot -Directory -ErrorAction SilentlyContinue) {
        $skillFile = Join-Path $dir.FullName 'skill.md'
        if (-not (Test-Path $skillFile)) { continue }
        $auxiliary += [ordered]@{
            pack  = $pack
            id    = $dir.Name
            skill = (Resolve-Path $skillFile).Path
        }
    }
}

$payload = [ordered]@{
    generatedAt      = (Get-Date).ToUniversalTime().ToString("o")
    executionContext = $ctx.id
    capabilityPacks  = @($ctx.enabled_capability_packs)
    pipelines        = $entries
    auxiliary        = $auxiliary
}

$outPath = Join-Path $workspace ".cursor\capabilities-skills.json"
if ($WhatIf) {
    Write-Host "Would write $outPath"
    $payload | ConvertTo-Json -Depth 5
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path $outPath -Parent) | Out-Null
$payload | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath ($($entries.Count) pipelines, $($auxiliary.Count) auxiliary, context=$($ctx.id))" -ForegroundColor DarkGray
