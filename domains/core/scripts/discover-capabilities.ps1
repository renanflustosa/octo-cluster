# Discover capability providers by pipeline (ship, scan, ...).
# Usage: . discover-capabilities.ps1; Get-DiscoveredCapabilities -Pipeline ship -Phase gates

param()

$ErrorActionPreference = "Stop"

function Read-ProviderDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )

    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
    $lines = Get-Content -Path $FilePath -Encoding UTF8
    $parsed = ConvertFrom-SimpleYaml -Lines $lines
    $parsed['_source'] = $FilePath

    if ($parsed.run -and $parsed.run.script) {
        $scriptRel = [string]$parsed.run.script
        $parsed['_script_path'] = Join-Path $WorkspaceRoot ($scriptRel -replace '/', '\')
    }

    return $parsed
}

function Get-CapabilityRegistry {
    param([string]$WorkspaceRoot)

    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
    $registryPath = Join-Path $WorkspaceRoot "capabilities\registry.yaml"
    if (Test-Path $registryPath) {
        $registry = ConvertFrom-SimpleYaml -Lines (Get-Content $registryPath -Encoding UTF8)
    } else {
        $registry = [ordered]@{ version = 1; packs = @{} }
    }

    $localPath = Join-Path $WorkspaceRoot "capabilities\registry.local.yaml"
    if (Test-Path $localPath) {
        $local = ConvertFrom-SimpleYaml -Lines (Get-Content $localPath -Encoding UTF8)
        if ($local.packs) {
            if (-not $registry.packs) { $registry.packs = @{} }
            foreach ($entry in @($local.packs)) {
                if ($entry -is [hashtable] -and $entry.id -and $entry.path) {
                    $registry.packs[[string]$entry.id] = @{ path = [string]$entry.path }
                    continue
                }
            }
            if ($local.packs -is [hashtable]) {
                foreach ($key in $local.packs.Keys) {
                    $registry.packs[$key] = $local.packs[$key]
                }
            }
        }
    }

    return $registry
}

function Get-CapabilityPackPath {
    param(
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )

    $registry = Get-CapabilityRegistry -WorkspaceRoot $WorkspaceRoot
    $packs = $registry.packs
    if ($packs -and $packs[$PackId] -and $packs[$PackId].path) {
        return Join-Path $WorkspaceRoot ([string]$packs[$PackId].path -replace '/', '\')
    }
    foreach ($entry in @($packs)) {
        if ($entry -is [hashtable] -and [string]$entry.id -eq $PackId -and $entry.path) {
            return Join-Path $WorkspaceRoot ([string]$entry.path -replace '/', '\')
        }
    }
    foreach ($rel in @("capabilities\_private\$PackId", "capabilities\$PackId")) {
        $candidate = Join-Path $WorkspaceRoot $rel
        if (Test-Path $candidate) { return $candidate }
    }
    return Join-Path $WorkspaceRoot "capabilities\_private\$PackId"
}

function Get-ManifestProviderEntries {
    param([hashtable]$Manifest)

    if (-not $Manifest -or -not $Manifest.providers) { return @() }
    $raw = $Manifest.providers
    if ($raw -is [array]) { return @($raw) }
    return @([string]$raw -split '[,\s]+' | Where-Object { $_ })
}

function Resolve-CapabilityPipelineRoot {
    param(
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$Pipeline,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )

    $capRoot = Join-Path (Get-CapabilityPackPath -PackId $PackId -WorkspaceRoot $WorkspaceRoot) $Pipeline
    $capManifest = Join-Path $capRoot "manifest.yaml"
    if (Test-Path $capManifest) {
        return [ordered]@{
            Path   = $capRoot
            Legacy = $false
        }
    }

    return $null
}

function Get-ProviderOwnerRepositories {
    param([hashtable]$Provider)

    if (-not $Provider.owner) { return $null }
    if ($Provider.owner.global -eq $true) { return @('*') }

    $raw = $Provider.owner.repositories
    if (-not $raw) { return @() }
    if ($raw -is [array]) { return @($raw) }
    return @([string]$raw -split '[,\s|]+' | Where-Object { $_ })
}

function Test-ProviderOwnership {
    param(
        [hashtable]$Provider,
        [string]$ActiveRepoName,
        [hashtable]$ShipContext
    )

    $repos = Get-ProviderOwnerRepositories -Provider $Provider
    if ($repos -contains '*') { return $true }

    if ($null -eq $repos -and $Provider._legacy) {
        Write-Host "[deprecation] legacy provider '$($Provider.id)' without owner.repositories; using context ship_repositories" -ForegroundColor Yellow
        if ($ShipContext.ship_repositories -and $ShipContext.ship_repositories.Count -gt 0) {
            return $ShipContext.ship_repositories -contains $ActiveRepoName
        }
        return $false
    }

    if ($null -eq $repos) {
        Write-Host "[deprecation] provider '$($Provider.id)' missing owner block; applying to all repos" -ForegroundColor Yellow
        return $true
    }

    if ($repos.Count -eq 0) { return $true }
    if (-not $ActiveRepoName) { return $false }
    return $repos -contains $ActiveRepoName
}

function Test-ProviderWhen {
    param(
        [hashtable]$Provider,
        [string]$RepoPath
    )

    $when = if ($Provider.when) { [string]$Provider.when } else { 'always' }
    switch ($when) {
        'always' { return $true }
        'on_change' {
            if (-not $Provider.on_change -or -not $Provider.on_change.paths) { return $true }
            Push-Location $RepoPath
            try {
                $hits = @(git diff --name-only HEAD 2>$null)
                if ($LASTEXITCODE -ne 0) { $hits = @(git diff --name-only 2>$null) }
                foreach ($pattern in @($Provider.on_change.paths)) {
                    foreach ($hit in $hits) {
                        if ($hit -like $pattern) { return $true }
                    }
                }
                return $false
            } finally {
                Pop-Location
            }
        }
        default { return $true }
    }
}

function Get-LegacyDomainGateProviders {
    param(
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )

    Write-Host "[deprecation] legacy gate filename discovery for pack '$PackId' - add capabilities/$PackId/ship/manifest.yaml" -ForegroundColor Yellow

    $providers = @()
    try {
        $domainScripts = Get-DomainScriptsRoot -Name $PackId
    } catch {
        return $providers
    }

    $prefix = $PackId
    $ctxPath = Join-Path $WorkspaceRoot "contexts\$PackId.json"
    if (Test-Path $ctxPath) {
        try {
            $ctx = Get-Content $ctxPath -Raw | ConvertFrom-Json
            if ($ctx.script_prefix) { $prefix = [string]$ctx.script_prefix }
        } catch {
            # fall through
        }
    }

    $candidates = @(
        (Join-Path $domainScripts "$PackId-ship-gate.ps1"),
        (Join-Path $domainScripts "$prefix-ship-gate.ps1"),
        (Join-Path $domainScripts "ship-gate.ps1")
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }
        return @([ordered]@{
            id           = ([System.IO.Path]::GetFileNameWithoutExtension($candidate))
            phase        = 'gates'
            kind         = 'script'
            blocking     = $true
            priority     = 100
            when         = 'always'
            _source      = 'legacy-discovery'
            _script_path = $candidate
            _legacy      = $true
        })
    }

    return $providers
}

function Add-CapabilityManifestProviders {
    param(
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$Pipeline,
        [string]$Phase,
        [string]$RepoPath,
        [hashtable]$ShipContext,
        [string]$ActiveRepoName,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][hashtable]$SeenIds,
        [Parameter(Mandatory = $true)]$TargetList
    )

    $resolved = Resolve-CapabilityPipelineRoot -PackId $PackId -Pipeline $Pipeline -WorkspaceRoot $WorkspaceRoot
    if (-not $resolved) {
        if ((-not $Phase -or $Phase -eq 'gates') -and $PackId -ne 'core') {
            foreach ($legacy in Get-LegacyDomainGateProviders -PackId $PackId -WorkspaceRoot $WorkspaceRoot) {
                if ($SeenIds.ContainsKey([string]$legacy.id)) { continue }
                if (-not (Test-ProviderOwnership -Provider $legacy -ActiveRepoName $ActiveRepoName -ShipContext $ShipContext)) { continue }
                $SeenIds[[string]$legacy.id] = $true
                [void]$TargetList.Add($legacy)
            }
        }
        return
    }

    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
    $manifestPath = Join-Path $resolved.Path "manifest.yaml"
    $manifest = ConvertFrom-SimpleYaml -Lines (Get-Content $manifestPath -Encoding UTF8)

    foreach ($rel in Get-ManifestProviderEntries -Manifest $manifest) {
        $providerFile = Join-Path $resolved.Path ($rel -replace '/', '\')
        if (-not (Test-Path $providerFile)) { continue }
        $def = Read-ProviderDefinition -FilePath $providerFile -WorkspaceRoot $WorkspaceRoot
        if ($Phase -and [string]$def.phase -ne $Phase) { continue }
        if ($SeenIds.ContainsKey([string]$def.id)) { continue }
        if (-not (Test-ProviderOwnership -Provider $def -ActiveRepoName $ActiveRepoName -ShipContext $ShipContext)) { continue }
        if (-not (Test-ProviderWhen -Provider $def -RepoPath $RepoPath)) { continue }
        $SeenIds[[string]$def.id] = $true
        [void]$TargetList.Add($def)
    }
}

function Test-PackAppliesToRepo {
    param(
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$RepoName,
        [hashtable]$ShipContext
    )

    if ($PackId -eq 'core') { return $true }
    if ($ShipContext.ship_repositories -and $ShipContext.ship_repositories.Count -gt 0) {
        return $ShipContext.ship_repositories -contains $RepoName
    }
    return $false
}

function Resolve-CapabilitySkillPath {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestSkill,
        [Parameter(Mandatory = $true)][string]$PipelineRoot,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot
    )

    $skillRel = [string]$ManifestSkill
    if ($skillRel -match '^(\.\./|\./)') {
        $candidate = Join-Path $PipelineRoot ($skillRel -replace '/', '\')
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }
    if ($skillRel -notmatch '^[a-zA-Z]:' -and $skillRel -notmatch '^/') {
        $localCandidate = Join-Path $PipelineRoot ($skillRel -replace '/', '\')
        if (Test-Path $localCandidate) { return (Resolve-Path $localCandidate).Path }
    }
    $candidate = Join-Path $WorkspaceRoot ($skillRel -replace '/', '\')
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    return $null
}

function Get-DiscoveredCapabilities {
    param(
        [Parameter(Mandatory = $true)][string]$Pipeline,
        [string]$Phase,
        [string]$Domain,
        [string]$RepoPath,
        [hashtable]$ShipContext
    )

    . (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')

    if (-not $RepoPath) {
        $RepoPath = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { throw "RepoPath required outside a git repository." }
    }
    $RepoPath = (Resolve-Path $RepoPath).Path

    if (-not $ShipContext) {
        $ShipContext = Get-ShipExecutionContext -RepoPath $RepoPath
    }

    $activeRepoName = if ($ShipContext.active_repo) {
        [string]$ShipContext.active_repo
    } else {
        Get-RepoNameFromPath -RepoPath $RepoPath
    }

    $workspace = Get-OctoClusterRoot
    $results = New-Object System.Collections.ArrayList
    $seenIds = @{}

    $packs = @($ShipContext.enabled_capability_packs)
    if (-not $packs -or $packs.Count -eq 0) {
        $packs = if ($Domain) { @('core', $Domain) } else { @('core') }
    }

    foreach ($pack in $packs) {
        Add-CapabilityManifestProviders -PackId $pack -Pipeline $Pipeline -Phase $Phase `
            -RepoPath $RepoPath -ShipContext $ShipContext -ActiveRepoName $activeRepoName `
            -WorkspaceRoot $workspace -SeenIds $seenIds -TargetList $results
    }

    return @($results | Sort-Object { if ($null -ne $_.priority) { [int]$_.priority } else { 999 } }, { [string]$_._source })
}

function Get-DiscoveredCapabilitySkill {
    param(
        [Parameter(Mandatory = $true)][string]$Pipeline,
        [string]$Domain,
        [string]$RepoPath,
        [hashtable]$ShipContext
    )

    . (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')

    if (-not $RepoPath) {
        $RepoPath = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { throw "RepoPath required outside a git repository." }
    }
    $RepoPath = (Resolve-Path $RepoPath).Path

    if (-not $ShipContext) {
        $ShipContext = Get-ShipExecutionContext -RepoPath $RepoPath
    }

    $repoName = if ($ShipContext.active_repo) {
        [string]$ShipContext.active_repo
    } else {
        Get-RepoNameFromPath -RepoPath $RepoPath
    }

    $workspace = Get-OctoClusterRoot
    $packs = @($ShipContext.enabled_capability_packs)
    if (-not $packs -or $packs.Count -eq 0) {
        $packs = if ($Domain) { @('core', $Domain) } else { @('core') }
    }

    foreach ($pack in $packs) {
        if ($pack -eq 'core') { continue }
        if (-not (Test-PackAppliesToRepo -PackId $pack -RepoName $repoName -ShipContext $ShipContext)) { continue }

        $resolved = Resolve-CapabilityPipelineRoot -PackId $pack -Pipeline $Pipeline -WorkspaceRoot $workspace
        if ($resolved) {
            $manifest = ConvertFrom-SimpleYaml -Lines (Get-Content (Join-Path $resolved.Path "manifest.yaml") -Encoding UTF8)
            if ($manifest.skill) {
                $skillPath = Resolve-CapabilitySkillPath -ManifestSkill ([string]$manifest.skill) `
                    -PipelineRoot $resolved.Path -WorkspaceRoot $workspace
                if ($skillPath) { return $skillPath }
            }
        }

        $skillCandidates = @(
            (Join-Path $workspace "capabilities\_private\$pack\$Pipeline\skill.md"),
            (Join-Path $workspace "capabilities\$pack\$Pipeline\skill.md"),
            (Join-Path $workspace "domains\_private\$pack\$Pipeline\skill.md"),
            (Join-Path $workspace "domains\$pack\$Pipeline\skill.md")
        )
        foreach ($candidate in $skillCandidates) {
            if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
        }
    }

    $coreResolved = Resolve-CapabilityPipelineRoot -PackId 'core' -Pipeline $Pipeline -WorkspaceRoot $workspace
    if ($coreResolved) {
        $coreManifest = ConvertFrom-SimpleYaml -Lines (Get-Content (Join-Path $coreResolved.Path "manifest.yaml") -Encoding UTF8)
        if ($coreManifest.skill) {
            $coreSkill = Resolve-CapabilitySkillPath -ManifestSkill ([string]$coreManifest.skill) `
                -PipelineRoot $coreResolved.Path -WorkspaceRoot $workspace
            if ($coreSkill) { return $coreSkill }
        }
    }

    return (Join-Path $workspace "domains\core\skills\$((Get-PipelineDefaultSkillName -Pipeline $Pipeline))\SKILL.md")
}

function Get-PipelineDefaultSkillName {
    param([Parameter(Mandatory = $true)][string]$Pipeline)

    switch ($Pipeline) {
        'ship' { return 'core-ship' }
        'review' { return 'code-review' }
        'debug' { return 'systematic-debugging' }
        default { return 'core-adaptive-loop' }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    Get-DiscoveredCapabilities -Pipeline ship | ConvertTo-Json -Depth 6
}
