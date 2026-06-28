# Shared paths for Octo Cluster scripts. Dot-source from domains/*/scripts/*.ps1 or scripts/*.ps1

if (-not $env:OCTO_CLUSTER -or -not (Test-Path -LiteralPath $env:OCTO_CLUSTER)) {
    $here = $PSScriptRoot
    while ($here) {
        if (Test-Path (Join-Path $here 'install.ps1')) {
            $env:OCTO_CLUSTER = (Resolve-Path $here).Path
            break
        }
        $parent = Split-Path $here -Parent
        if ($parent -eq $here) { break }
        $here = $parent
    }
}

function Get-OctoClusterRoot {
    if ($env:OCTO_CLUSTER -and (Test-Path $env:OCTO_CLUSTER)) {
        return (Resolve-Path $env:OCTO_CLUSTER).Path
    }
    $here = $PSScriptRoot
    while ($here) {
        if (Test-Path (Join-Path $here "install.ps1")) {
            return (Resolve-Path $here).Path
        }
        $parent = Split-Path $here -Parent
        if ($parent -eq $here) { break }
        $here = $parent
    }
    throw "OCTO_CLUSTER not set and install.ps1 not found above $PSScriptRoot"
}

function Import-ExecutionContextModule {
    if ($script:ExecutionContextModuleLoaded) { return }
    $resolver = Join-Path (Get-OctoClusterRoot) "domains\core\scripts\resolve-execution-context.ps1"
    if (-not (Test-Path $resolver)) {
        throw "Missing execution context resolver: $resolver"
    }
    . $resolver
    $script:ExecutionContextModuleLoaded = $true

$contextEngineRuntime = Join-Path (Get-OctoClusterRoot) "scripts\context-engine-runtime.ps1"
if (Test-Path $contextEngineRuntime) {
    . $contextEngineRuntime
}
}

function Get-ResolvedChildDomain {
    param([string]$Override)

    if ($Override) { return $Override }
    $packs = @((Get-ShipExecutionContext).enabled_capability_packs | Where-Object { $_ -ne 'core' })
    if ($packs.Count -gt 0) { return [string]$packs[0] }
    return $null
}

function Get-DomainRoot {
    param([string]$Name = (Get-ResolvedChildDomain))
    if (-not $Name -or $Name -eq 'platform') {
        throw "Get-DomainRoot expects a child domain id, not '$Name'."
    }
    if ($Name -eq "core") {
        throw "Get-DomainRoot expects a child domain id, not 'core'."
    }
    $root = Join-Path (Get-OctoClusterRoot) "domains\$Name"
    if (-not (Test-Path $root)) {
        throw "Domain '$Name' not found at $root"
    }
    return (Resolve-Path $root).Path
}

function Get-CoreRoot {
    Join-Path (Get-OctoClusterRoot) "domains\core"
}

function Get-ContextEngineRoot {
    Join-Path (Get-OctoClusterRoot) "engine\context-engine"
}

function Get-MemoryRoot {
    param([string]$Profile)
    Join-Path (Get-OctoClusterRoot) "state\memory\$Profile"
}

function Get-PackDocsRoot {
    param([Parameter(Mandatory = $true)][string]$PackId)
    $ctxPath = Join-Path (Get-OctoClusterRoot) "contexts\$PackId.json"
    if (Test-Path $ctxPath) {
        try {
            $ctx = Get-Content $ctxPath -Raw | ConvertFrom-Json
            if ($ctx.docs_root) {
                $rel = [string]$ctx.docs_root
                if ($rel -match '^[a-zA-Z]:\\' -or $rel.StartsWith('/')) { return $rel.TrimEnd('\', '/') }
                return (Join-Path (Get-OctoClusterRoot) $rel)
            }
        } catch { /* fall through */ }
    }
    Join-Path (Get-OctoClusterRoot) "domains\$PackId\docs"
}

function Get-DomainScriptsRoot {
    param([string]$Name = (Get-ResolvedChildDomain))
    if (-not $Name) { throw "No child domain in execution context." }
    Join-Path (Get-DomainRoot -Name $Name) "scripts"
}

function Get-DomainDocsRoot {
    param([string]$Name = (Get-ResolvedChildDomain))
    if (-not $Name) { throw "No child domain in execution context." }
    Join-Path (Get-DomainRoot -Name $Name) "docs"
}

function Get-CoreScriptsRoot {
    Join-Path (Get-CoreRoot) "scripts"
}

function Get-CoreScriptPath {
    param([Parameter(Mandatory = $true)][string]$Name)
    Join-Path (Get-CoreScriptsRoot) "core-$Name.ps1"
}

function Get-DefaultMemoryProfile {
    param([string]$Name)
    if ($Name) {
        $ctxPath = Join-Path (Get-OctoClusterRoot) "contexts\$Name.json"
        if (Test-Path $ctxPath) {
            try {
                $ctx = Get-Content $ctxPath -Raw | ConvertFrom-Json
                if ($ctx.memory_profile) { return [string]$ctx.memory_profile }
            } catch { }
        }
        return 'octo-cluster'
    }
    $ctx = Get-ShipExecutionContext
    if ($ctx.memory_profile) { return [string]$ctx.memory_profile }
    return 'octo-cluster'
}

$resolver = Join-Path (Get-OctoClusterRoot) "domains\core\scripts\resolve-execution-context.ps1"
if (-not (Test-Path $resolver)) {
    throw "Missing execution context resolver: $resolver"
}
. $resolver
$script:ExecutionContextModuleLoaded = $true

$contextEngineRuntime = Join-Path (Get-OctoClusterRoot) "scripts\context-engine-runtime.ps1"
if (Test-Path $contextEngineRuntime) {
    . $contextEngineRuntime
}
