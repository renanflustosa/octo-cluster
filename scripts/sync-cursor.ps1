# Sync domains/core into .cursor/* (core commands + core skills only).
# Pack skills resolve at runtime via invoke-pipeline / capabilities-skills.json.
param(
    [string]$Domain,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")

$root = Get-OctoClusterRoot
$domains = Join-Path $root "domains"
$cursor = Join-Path $root ".cursor"

function Sync-Tree {
    param(
        [string]$Source,
        [string]$Dest
    )
    if (-not (Test-Path $Source)) { return $false }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    if ($WhatIf) {
        Write-Host "Would sync $Source to $Dest"
        return $true
    }
    robocopy $Source $Dest /E /IS /IT /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    return $true
}

function Test-DomainHasAssets {
    param([string]$DomainRoot)
    $assetDirs = @("rules", "skills", "commands", "hooks")
    foreach ($dir in $assetDirs) {
        $path = Join-Path $DomainRoot $dir
        if (-not (Test-Path $path)) { continue }
        $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".gitkeep" }
        if ($items) { return $true }
    }
    return $false
}

$ctx = Get-ShipExecutionContext
$activeDomain = if ($Domain) {
    $Domain
} else {
    Get-ResolvedChildDomain
}


function Resolve-ChildDomainRoot {
    param(
        [string]$DomainsRoot,
        [string]$ActiveDomain
    )
    if (-not $ActiveDomain) { return $null }
    foreach ($rel in @($ActiveDomain, (Join-Path '_private' $ActiveDomain))) {
        $candidate = Join-Path $DomainsRoot $rel
        if (Test-Path $candidate) {
            return @{
                Path    = $candidate
                RelRoot = "domains/$($rel -replace '\\','/')"
            }
        }
    }
    return $null
}

$childResolved = Resolve-ChildDomainRoot -DomainsRoot $domains -ActiveDomain $activeDomain
$childRoot = if ($childResolved) { $childResolved.Path } else { $null }

if ($activeDomain -eq "core") {
    Write-Error "Active domain cannot be 'core'. Choose a child domain (e.g. company2) or use platform context."
}

if ($activeDomain -and -not $childRoot) {
    Write-Warning "Domain '$activeDomain' not found under domains/ or domains/_private/ - syncing core only."
    $activeDomain = $null
    $childRoot = $null
}

$coreRoot = Join-Path $domains "core"
$coreRules = Join-Path $coreRoot "rules"
$coreSkills = Join-Path $coreRoot "skills"
$coreCommands = Join-Path $coreRoot "commands"
$childRules = if ($childRoot) { Join-Path $childRoot "rules" } else { $null }
$childHooks = if ($childRoot) { Join-Path $childRoot "hooks" } else { $null }
$cursorRules = Join-Path $cursor "rules"
$cursorSkills = Join-Path $cursor "skills"
$cursorCommands = Join-Path $cursor "commands"
$cursorHooks = Join-Path $cursor "hooks"

foreach ($dir in @($cursorRules, $cursorSkills, $cursorCommands, $cursorHooks)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ($WhatIf) { continue }
    Get-ChildItem -Path $dir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}

Sync-Tree $coreRules $cursorRules | Out-Null
Sync-Tree $coreSkills $cursorSkills | Out-Null
Sync-Tree $coreCommands $cursorCommands | Out-Null

$hasChildAssets = $false
if ($childRoot) {
    $hasChildAssets = Test-DomainHasAssets $childRoot
}

if ($hasChildAssets) {
    Sync-Tree $childRules $cursorRules | Out-Null
} elseif ($activeDomain) {
    Write-Warning "Domain '$activeDomain' has no assets yet - syncing core only."
}

function Sync-HookScripts {
    param(
        [string]$SourceHooksDir,
        [string]$DestHooksDir
    )
    if (-not (Test-Path $SourceHooksDir)) { return }
    New-Item -ItemType Directory -Force -Path $DestHooksDir | Out-Null
    if ($WhatIf) {
        Write-Host "Would sync hook scripts from $SourceHooksDir to $DestHooksDir"
        return
    }
    Get-ChildItem -Path $SourceHooksDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item -Path $_.FullName -Destination $DestHooksDir -Force }
}

function Write-HooksJsonFromTemplate {
    param([string]$TemplatePath, [string]$DestPath)
    if (-not (Test-Path $TemplatePath)) {
        throw "Hooks template not found: $TemplatePath"
    }
    if ($WhatIf) {
        Write-Host "Would write hooks.json from $TemplatePath"
        return
    }
    Copy-Item -Path $TemplatePath -Destination $DestPath -Force
}

$hooksJsonPath = Join-Path $cursor "hooks.json"
$hooksTemplate = if ($activeDomain -and (Test-Path (Join-Path $childHooks "hooks.$activeDomain.json"))) {
    Join-Path $childHooks "hooks.$activeDomain.json"
} else {
    Join-Path $coreRoot "hooks\hooks.platform.json"
}

Write-HooksJsonFromTemplate -TemplatePath $hooksTemplate -DestPath $hooksJsonPath

if ($childHooks -and (Test-Path $childHooks)) {
    Sync-HookScripts -SourceHooksDir $childHooks -DestHooksDir $cursorHooks
}

$skillIndexScript = Join-Path $PSScriptRoot "write-capabilities-skill-index.ps1"
if (Test-Path $skillIndexScript) {
    $prevCtx = $env:AI_EXECUTION_CONTEXT
    if ($activeDomain) {
        $env:AI_EXECUTION_CONTEXT = $activeDomain
    } elseif (-not $env:AI_EXECUTION_CONTEXT) {
        $env:AI_EXECUTION_CONTEXT = 'platform'
    }
    $indexArgs = @('-ExecutionPolicy', 'Bypass', '-File', $skillIndexScript)
    if ($WhatIf) { $indexArgs += '-WhatIf' }
    & powershell @indexArgs
    if ($null -ne $prevCtx) { $env:AI_EXECUTION_CONTEXT = $prevCtx }
    elseif ($activeDomain) { Remove-Item Env:AI_EXECUTION_CONTEXT -ErrorAction SilentlyContinue }
}

$manifest = @{
    executionContext = $ctx.id
    domain           = $(if ($activeDomain) { $activeDomain } else { 'platform' })
    syncedAt         = (Get-Date).ToUniversalTime().ToString("o")
    coreRoot         = "domains/core"
    childRoot        = $(if ($childResolved) { $childResolved.RelRoot } else { $null })
    commandsPolicy   = "core-only"
    skillsPolicy     = "core-only"
    skillDiscovery   = "capabilities-skills.json + invoke-pipeline discover"
}
$manifestPath = Join-Path $cursor "domain.manifest.json"
if (-not $WhatIf) {
    $manifest | ConvertTo-Json | Set-Content -Path $manifestPath -Encoding UTF8
} else {
    Write-Host "Would write $manifestPath"
}

if ($activeDomain) {
    Write-Host ("Synced core commands/skills + {0} rules/hooks to .cursor under {1} (context={2})" -f $activeDomain, $root, $ctx.id)
} else {
    Write-Host ("Synced domains/core to .cursor under {0} (context={1}, platform-only)" -f $root, $ctx.id)
}
