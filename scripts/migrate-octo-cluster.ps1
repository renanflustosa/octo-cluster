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

function Test-ValidOctoClusterRoot {
    param([string]$Path)
    return $Path -and (Test-Path -LiteralPath (Join-Path $Path 'install.ps1'))
}

$userOcto = [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User')
if (-not (Test-ValidOctoClusterRoot $userOcto)) {
    [Environment]::SetEnvironmentVariable('OCTO_CLUSTER', $root, 'User')
    Write-Host "Set User OCTO_CLUSTER -> $root (was stale or missing)" -ForegroundColor Green
}

$oldEnv = [Environment]::GetEnvironmentVariable('AI_WORKSPACE', 'User')
if ($oldEnv) {
    [Environment]::SetEnvironmentVariable('AI_WORKSPACE', $null, 'User')
    Write-Host "Removed User AI_WORKSPACE" -ForegroundColor Green
}

if (-not $env:OCTO_CLUSTER) { $env:OCTO_CLUSTER = $root }

Write-Host "Migration complete." -ForegroundColor Green
