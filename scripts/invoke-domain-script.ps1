# Resolve and run a domain or core harness script by logical name.
# Usage: invoke-domain-script.ps1 -Name read-gate -ScriptArgs @{ Path = "engine\context-engine\src\search.ts" }
#        invoke-domain-script.ps1 -Name start-workspace -Domain company2

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [hashtable]$ScriptArgs = @{},
    [string]$Domain
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_load-env.ps1")

$Domain = Get-ResolvedChildDomain -Override $Domain

function Get-PackScriptPrefix {
    param([string]$DomainName)

    if (-not $DomainName) { return $null }

    $ctxPath = Join-Path (Get-OctoClusterRoot) "contexts\$DomainName.json"
    if (Test-Path $ctxPath) {
        try {
            $ctx = Get-Content $ctxPath -Raw | ConvertFrom-Json
            if ($ctx.script_prefix) { return [string]$ctx.script_prefix }
        } catch {
            # fall through
        }
    }
    return $DomainName
}

function Resolve-ChildScriptPath {
    param([string]$ScriptName, [string]$DomainName)

    if (-not $DomainName) { return $null }

    try {
        $domainScripts = Get-DomainScriptsRoot -Name $DomainName
    } catch {
        return $null
    }

    $prefix = Get-PackScriptPrefix -DomainName $DomainName
    $candidates = @()
    if ($prefix) {
        $candidates += Join-Path $domainScripts "$prefix-$ScriptName.ps1"
    }
    $candidates += Join-Path $domainScripts "$DomainName-$ScriptName.ps1"
    $candidates += Join-Path $domainScripts "$ScriptName.ps1"

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Resolve-DomainScriptPath {
    param([string]$ScriptName, [string]$DomainName)

    $child = Resolve-ChildScriptPath -ScriptName $ScriptName -DomainName $DomainName
    if ($child) { return $child }

    $coreScript = Get-CoreScriptPath -Name $ScriptName
    if (Test-Path $coreScript) { return $coreScript }

    $domainLabel = if ($DomainName) { $DomainName } else { 'platform' }
    throw "No script found for -Name '$ScriptName' (domain=$domainLabel). Tried child scripts and $coreScript"
}

function Invoke-ScriptFile {
    param([string]$Path, [hashtable]$BoundArgs = @{})
    $params = @("-ExecutionPolicy", "Bypass", "-File", $Path)
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

# start-workspace: core bootstrap always, then optional child extension (additive).
if ($Name -eq "start-workspace") {
    $corePath = Get-CoreScriptPath -Name $Name
    if (-not (Test-Path $corePath)) {
        throw "Missing core script: $corePath"
    }

    $profile = if ($ScriptArgs.Profile) { $ScriptArgs.Profile } else { Get-DefaultMemoryProfile -Name $Domain }
    $coreArgs = @{ Profile = $profile }
    if ($ScriptArgs.SkipIndex) { $coreArgs.SkipIndex = $true }

    Write-Host "[invoke-domain-script] core: $corePath" -ForegroundColor DarkGray
    Invoke-ScriptFile -Path $corePath -BoundArgs $coreArgs

    $childPath = Resolve-ChildScriptPath -ScriptName $Name -DomainName $Domain
    if ($childPath) {
        Write-Host "[invoke-domain-script] child: $childPath" -ForegroundColor DarkGray
        $childArgs = @{ SkipCore = $true; Profile = $profile }
        if ($ScriptArgs.SkipIndex) { $childArgs.SkipIndex = $true }
        if ($ScriptArgs.WithStack) { $childArgs.WithStack = $true }
        Invoke-ScriptFile -Path $childPath -BoundArgs $childArgs
    }

    exit 0
}

$scriptPath = Resolve-DomainScriptPath -ScriptName $Name -DomainName $Domain
Write-Host "[invoke-domain-script] $scriptPath" -ForegroundColor DarkGray
Invoke-ScriptFile -Path $scriptPath -BoundArgs $ScriptArgs
exit $LASTEXITCODE
