#Requires -Version 5.1
<#
.SYNOPSIS
  One-time migration from ai-workspace branding to Octo Cluster.
#>
param(
    [string]$WorkspaceRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Split-Path $PSScriptRoot -Parent
}
$root = (Resolve-Path $WorkspaceRoot).Path
$memRoot = Join-Path $root 'state\memory'

function Move-MemoryProfile {
    param([string]$From, [string]$To)
    $src = Join-Path $memRoot $From
    $dst = Join-Path $memRoot $To
    if (-not (Test-Path $src)) { return }
    if (-not (Test-Path $dst)) {
        Move-Item -LiteralPath $src -Destination $dst
        Write-Host "Moved memory profile $From -> $To" -ForegroundColor Green
        return
    }
    Get-ChildItem -LiteralPath $src -Force | ForEach-Object {
        $target = Join-Path $dst $_.Name
        if (Test-Path $target) { return }
        Move-Item -LiteralPath $_.FullName -Destination $target
    }
    if (-not (Get-ChildItem -LiteralPath $src -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $src -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Merged memory profile $From -> $To" -ForegroundColor Green
}

function Rename-StartStamp {
    param([string]$ProfileDir)
    $old = Join-Path $ProfileDir 'last-day-start.txt'
    $new = Join-Path $ProfileDir 'last-start-workspace.txt'
    if ((Test-Path $old) -and -not (Test-Path $new)) {
        Move-Item -LiteralPath $old -Destination $new
        Write-Host "Renamed last-day-start.txt in $ProfileDir" -ForegroundColor DarkGray
    }
}

Write-Host "Octo Cluster migration (root: $root)" -ForegroundColor Cyan

Move-MemoryProfile -From 'ai-workspace' -To 'octo-cluster'
Move-MemoryProfile -From 'core' -To 'octo-cluster'

Get-ChildItem -LiteralPath $memRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Rename-StartStamp -ProfileDir $_.FullName
}

$oldEnv = [Environment]::GetEnvironmentVariable('AI_WORKSPACE', 'User')
$userOcto = [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User')
$validRoot = if (Test-Path (Join-Path $root 'install.ps1')) { $root } else { $null }

function Set-UserOctoCluster {
    param([string]$Path)
    if (-not $Path) { return }
    [Environment]::SetEnvironmentVariable('OCTO_CLUSTER', $Path, 'User')
    Write-Host "Set User OCTO_CLUSTER=$Path" -ForegroundColor Green
}

if ($userOcto -and -not (Test-Path (Join-Path $userOcto 'install.ps1'))) {
    $parent = Split-Path $userOcto -Parent
    $sibling = if ($parent) { Join-Path $parent 'octo-cluster' } else { $null }
    if ($sibling -and (Test-Path (Join-Path $sibling 'install.ps1'))) {
        Set-UserOctoCluster $sibling
    } elseif ($validRoot) {
        Set-UserOctoCluster $validRoot
    } else {
        Write-Host "WARN: User OCTO_CLUSTER points to invalid path: $userOcto" -ForegroundColor Yellow
    }
} elseif (-not $userOcto -and $validRoot) {
    Set-UserOctoCluster $validRoot
}

if ($oldEnv) {
    if (-not $userOcto -and (Test-Path (Join-Path $oldEnv 'install.ps1'))) {
        Set-UserOctoCluster $oldEnv
    }
    [Environment]::SetEnvironmentVariable('AI_WORKSPACE', $null, 'User')
    Write-Host "Removed User AI_WORKSPACE" -ForegroundColor Green
}

if (-not $env:OCTO_CLUSTER) { $env:OCTO_CLUSTER = $root }

Write-Host "Migration complete." -ForegroundColor Green
