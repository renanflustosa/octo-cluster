# Resolve execution context: enabled capability packs + active repo.
# Usage: . resolve-execution-context.ps1; Get-ShipExecutionContext [-RepoPath ...]

param()

$ErrorActionPreference = "Stop"

function Get-ContextConfigPath {
    param([Parameter(Mandatory = $true)][string]$ContextId)

    $workspace = Get-OctoClusterRoot
    if ($ContextId -match '[/\\]' -or $ContextId.EndsWith('.json')) {
        $candidate = if ([System.IO.Path]::IsPathRooted($ContextId)) {
            $ContextId
        } else {
            Join-Path $workspace ($ContextId -replace '/', '\')
        }
        if (-not (Test-Path $candidate)) {
            throw "Execution context file not found: $candidate"
        }
        return (Resolve-Path $candidate).Path
    }

    $path = Join-Path $workspace "contexts\$ContextId.json"
    $localPath = Join-Path $workspace "contexts\$ContextId.local.json"
    if (Test-Path $localPath) {
        return (Resolve-Path $localPath).Path
    }
    if (Test-Path $path) {
        return (Resolve-Path $path).Path
    }
    throw "Execution context not found: contexts/$ContextId.local.json or contexts/$ContextId.json"
}

function Resolve-ExecutionContextId {
    if ($env:AI_EXECUTION_CONTEXT) {
        return [string]$env:AI_EXECUTION_CONTEXT
    }
    return 'platform'
}

function Get-ShipExecutionContext {
    param([string]$RepoPath)

    . (Join-Path $PSScriptRoot 'get-repo-policy.ps1')

    if (-not $RepoPath) {
        $RepoPath = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { $RepoPath = $null }
    } elseif ($RepoPath) {
        $RepoPath = (Resolve-Path $RepoPath).Path
    }

    $contextId = Resolve-ExecutionContextId
    $activeRepo = if ($RepoPath) { Get-RepoNameFromPath -RepoPath $RepoPath } else { $null }

    try {
        $configPath = Get-ContextConfigPath -ContextId $contextId
        $json = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return [ordered]@{
            id                         = [string]$json.id
            workspace_id               = if ($json.workspace_id) { [string]$json.workspace_id } else { [string]$json.id }
            enabled_capability_packs   = @($json.enabled_capability_packs)
            memory_profile             = if ($json.memory_profile) { [string]$json.memory_profile } else { [string]$json.id }
            ship_repositories          = if ($json.ship_repositories) { @($json.ship_repositories) } else { @() }
            active_repo                = $activeRepo
            active_repo_path           = $RepoPath
            _config_path               = $configPath
            _legacy_domain             = if ($json.id -ne 'platform') { [string]$json.id } else { $null }
        }
    } catch {
        Write-Host "[execution-context] fallback for '$contextId': $($_.Exception.Message)" -ForegroundColor Yellow
        $packs = @('core')
        if ($contextId -and $contextId -ne 'core' -and $contextId -ne 'platform') {
            $packs += $contextId
        }
        return [ordered]@{
            id                       = $contextId
            workspace_id             = $contextId
            enabled_capability_packs = @($packs | Select-Object -Unique)
            memory_profile           = $contextId
            ship_repositories        = @()
            active_repo              = $activeRepo
            active_repo_path         = $RepoPath
            _config_path             = $null
            _legacy_domain           = if ($contextId -ne 'platform') { $contextId } else { $null }
            _fallback                = $true
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    Get-ShipExecutionContext | ConvertTo-Json -Depth 4
}
