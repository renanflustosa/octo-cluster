# Write .cursor/capabilities-skills.json from capability manifests + execution context.
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")
. (Join-Path (Get-CoreScriptsRoot) "discover-capabilities.ps1")

function ConvertTo-WorkspaceRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )
    if (-not $Path) { return $Path }
    if ($Path -notmatch '^[a-zA-Z]:' -and $Path -notmatch '^/') {
        return ($Path -replace '\\', '/')
    }
    try {
        $full = (Resolve-Path -LiteralPath $Path).Path
        $root = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
        if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            return ($full.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/')
        }
    } catch {
        /* fall through */
    }
    return ($Path -replace '\\', '/')
}

$pipelines = @('ship', 'scan', 'model', 'close', 'start-workspace', 'review', 'debug')
$ctx = Get-ShipExecutionContext
$workspace = Get-OctoClusterRoot
$entries = @()

foreach ($pipeline in $pipelines) {
    $skill = Get-DiscoveredCapabilitySkill -Pipeline $pipeline -ShipContext $ctx
    $entries += [ordered]@{
        pipeline = $pipeline
        skill    = (ConvertTo-WorkspaceRelativePath -Path $skill -WorkspaceRoot $workspace)
    }
}

$auxiliary = @()
foreach ($pack in @($ctx.enabled_capability_packs)) {
    if ($pack -eq 'core') { continue }
    $packRoot = Get-CapabilityPackPath -PackId $pack -WorkspaceRoot $workspace
    $auxRoot = Join-Path $packRoot 'skills'
    if (-not (Test-Path $auxRoot)) { continue }
    foreach ($dir in Get-ChildItem -Path $auxRoot -Directory -ErrorAction SilentlyContinue) {
        $skillFile = Join-Path $dir.FullName 'skill.md'
        if (-not (Test-Path $skillFile)) { continue }
        $auxiliary += [ordered]@{
            pack  = $pack
            id    = $dir.Name
            skill = (ConvertTo-WorkspaceRelativePath -Path $skillFile -WorkspaceRoot $workspace)
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
