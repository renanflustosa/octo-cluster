# Shared paths for Octo Cluster scripts. Dot-source from domains/*/scripts/*.ps1 or scripts/*.ps1

function Test-OctoClusterRoot {
    param([string]$Path)
    if (-not $Path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path 'install.ps1')) -or
        (Test-Path -LiteralPath (Join-Path $Path 'install.sh'))
}

function Get-OctoClusterEnvVar {
    param(
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process'
    )
    switch ($Scope) {
        'Process' { return $env:OCTO_CLUSTER }
        'User' { return [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User') }
        'Machine' { return [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'Machine') }
    }
}

function Resolve-OctoClusterRootFromScript {
    $here = $PSScriptRoot
    while ($here) {
        if (Test-OctoClusterRoot $here) {
            return (Resolve-Path $here).Path
        }
        $parent = Split-Path $here -Parent
        if ($parent -eq $here) { break }
        $here = $parent
    }
    return $null
}

function Resolve-OctoClusterRoot {
    param([string]$Preferred)

    if (Test-OctoClusterRoot $Preferred) {
        return (Resolve-Path $Preferred).Path
    }

    $fromScript = Resolve-OctoClusterRootFromScript
    if ($fromScript) { return $fromScript }

    foreach ($scope in @('Process', 'User', 'Machine')) {
        $candidate = Get-OctoClusterEnvVar -Scope $scope
        if (Test-OctoClusterRoot $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    if ($Preferred) {
        $parent = Split-Path $Preferred -Parent
        if ($parent) {
            $sibling = Join-Path $parent 'octo-cluster'
            if (Test-OctoClusterRoot $sibling) {
                return (Resolve-Path $sibling).Path
            }
        }
    }

    return $null
}

function Get-OctoClusterInstallPath {
    foreach ($scope in @('User', 'Machine', 'Process')) {
        $candidate = Get-OctoClusterEnvVar -Scope $scope
        if (Test-OctoClusterRoot $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }
    return Resolve-OctoClusterRootFromScript
}

function Get-OctoClusterRootErrorMessage {
    @"
OCTO_CLUSTER could not be resolved.

Remediation (choose one):
  1. Dev Container (recommended — all desktop hosts): Reopen in Container; OCTO_CLUSTER is set automatically.
  2. Linux/macOS native: ./install.sh from clone root (or export OCTO_CLUSTER and run ./scripts/octo).
  3. Windows host optional: pwsh -File "<clone-root>/install.ps1" (sets User-level OCTO_CLUSTER).
  4. Self-locating entry (no env): pwsh -File "<clone-root>/octo.ps1" -Pipeline scan -Action discover

Install runs once per machine. Dev Container covers integrated terminals; native shells use OCTO_CLUSTER or ./scripts/octo.
"@
}

$resolved = Resolve-OctoClusterRoot -Preferred $env:OCTO_CLUSTER
if ($resolved) {
    if ($env:OCTO_CLUSTER -and $env:OCTO_CLUSTER -ne $resolved) {
        Write-Warning "Session OCTO_CLUSTER '$env:OCTO_CLUSTER' differs from resolved root '$resolved'; using resolved path."
    }
    $env:OCTO_CLUSTER = $resolved
}

function Get-OctoClusterRoot {
    $root = Resolve-OctoClusterRoot -Preferred $env:OCTO_CLUSTER
    if ($root) {
        $env:OCTO_CLUSTER = $root
        return $root
    }
    throw (Get-OctoClusterRootErrorMessage)
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
    $octo = Get-OctoClusterRoot
    foreach ($rel in @("domains\$Name", "domains\_private\$Name")) {
        $root = Join-Path $octo $rel
        if (Test-Path $root) {
            return (Resolve-Path $root).Path
        }
    }
    throw "Domain '$Name' not found under domains/ or domains/_private/"
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
    $octo = Get-OctoClusterRoot
    foreach ($ctxFile in @("$PackId.local.json", "$PackId.json")) {
        $ctxPath = Join-Path $octo "contexts\$ctxFile"
        if (-not (Test-Path $ctxPath)) { continue }
        try {
            $ctx = Get-Content $ctxPath -Raw | ConvertFrom-Json
            if ($ctx.docs_root) {
                $rel = [string]$ctx.docs_root
                if ($rel -match '^[a-zA-Z]:\\' -or $rel.StartsWith('/')) { return $rel.TrimEnd('\', '/') }
                return (Join-Path $octo $rel)
            }
        } catch { /* fall through */ }
    }
    foreach ($rel in @("domains\_private\$PackId\docs", "domains\$PackId\docs")) {
        $path = Join-Path $octo $rel
        if (Test-Path $path) { return $path }
    }
    Join-Path $octo "domains\$PackId\docs"
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
