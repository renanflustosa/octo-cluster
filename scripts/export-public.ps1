#Requires -Version 5.1
<#
.SYNOPSIS
  Export public octo-cluster tree from a full clone to a clean destination.
.EXAMPLE
  .\scripts\export-public.ps1 -Dest <dest-path>
#>
param(
    [string]$Source = '',
    [Parameter(Mandatory = $true)][string]$Dest,
    [switch]$SkipValidate,
    [switch]$SkipSync
)

$ErrorActionPreference = 'Stop'
if (-not $Source) { $Source = Split-Path $PSScriptRoot -Parent }
$Source = (Resolve-Path $Source).Path
$Dest = (Resolve-Path $Dest).Path

function Copy-Tree {
    param([string]$Rel)
    $src = Join-Path $Source $Rel
    $dst = Join-Path $Dest $Rel
    if (-not (Test-Path $src)) {
        Write-Host "[skip] missing $Rel" -ForegroundColor DarkGray
        return
    }
    $parent = Split-Path $dst -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    Write-Host "[copy] $Rel" -ForegroundColor Green
}

function Copy-File {
    param([string]$Rel)
    $src = Join-Path $Source $Rel
    $dst = Join-Path $Dest $Rel
    if (-not (Test-Path $src)) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host "[copy] $Rel" -ForegroundColor Green
}

Write-Host "== export-public ==" -ForegroundColor Cyan
Write-Host "Source: $Source"
Write-Host "Dest:   $Dest"

$copyPaths = @(
    'domains/core',
    'domains/company2',
    'domains/company3',
    'domains/company4',
    'capabilities/core',
    'engine',
    'scripts',
    'eval',
    'adapters',
    'docs',
    'repo-policies',
    '.vscode',
    '.github'
)

foreach ($p in $copyPaths) { Copy-Tree $p }

foreach ($f in @(
    'install.ps1',
    'install.cmd',
    'octo.cmd',
    'audit.cmd',
    '.gitignore',
    '.gitattributes',
    'LICENSE',
    'README.md',
    'CONTRIBUTING.md',
    'SECURITY.md'
)) { Copy-File $f }

# Remove private overlay paths that may have been copied
$remove = @(
    'docs/_private',
    'docs/reports',
    'domains/_private',
    'capabilities/_private',
    'contexts/_private',
    'capabilities/registry.local.yaml',
    'kernel'
)
foreach ($r in $remove) {
    $target = Join-Path $Dest $r
    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[remove] $r" -ForegroundColor Yellow
    }
}

$ctxRuntime = Join-Path $Dest 'contexts\runtime'
if (Test-Path $ctxRuntime) {
    Get-ChildItem $ctxRuntime -Filter '*.local.json' -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "[remove] contexts/runtime/$($_.Name)" -ForegroundColor Yellow
    }
    Get-ChildItem $ctxRuntime -Filter '*.private.json' -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "[remove] contexts/runtime/$($_.Name)" -ForegroundColor Yellow
    }
}

# contexts/runtime/platform.json — generic public example
$ctxDir = Join-Path $Dest 'contexts\runtime'
New-Item -ItemType Directory -Force -Path $ctxDir | Out-Null
@{
    id                       = 'platform'
    workspace_id             = 'core'
    enabled_capability_packs = @('core')
    memory_profile           = 'octo-cluster'
    ship_repositories        = @('octo-cluster')
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $ctxDir 'platform.json') -Encoding UTF8
Write-Host '[write] contexts/runtime/platform.json (public)' -ForegroundColor Green

# capabilities/registry.yaml — core only
$regDir = Join-Path $Dest 'capabilities'
New-Item -ItemType Directory -Force -Path $regDir | Out-Null
@'
version: 1
packs:
  core:
    path: capabilities/core
'@ | Set-Content (Join-Path $regDir 'registry.yaml') -Encoding UTF8 -NoNewline
Add-Content (Join-Path $regDir 'registry.yaml') '' -Encoding UTF8
Write-Host '[write] capabilities/registry.yaml (core only)' -ForegroundColor Green

foreach ($exampleFile in @(
    'contexts/runtime/consumer-pack.example.json',
    'capabilities/registry.local.yaml.example'
)) {
    Copy-File $exampleFile
}

# Filter repo-policies to public set
$rp = Join-Path $Dest 'repo-policies'
if (Test-Path $rp) {
    Get-ChildItem $rp -File | Where-Object { $_.Name -notin @('default.yaml', 'octo-cluster.yaml', 'consumer-demo.yaml') } | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "[remove] repo-policies/$($_.Name)" -ForegroundColor Yellow
    }
}


# .gitignore — ensure state is ignored
$gitignore = Join-Path $Dest '.gitignore'
$gi = if (Test-Path $gitignore) { Get-Content $gitignore -Raw } else { '' }
if ($gi -notmatch 'state/') {
    Add-Content $gitignore @'

# Runtime state (never commit)
state/
'@ -Encoding UTF8
}

if (-not $SkipSync) {
    Write-Host '== sync-cursor ==' -ForegroundColor Cyan
    $env:OCTO_CLUSTER = $Dest
    $env:AI_EXECUTION_CONTEXT = 'platform'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest 'scripts\sync-cursor.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'sync-cursor failed' }
}

if (-not $SkipValidate) {
    Write-Host '== validate context-engine ==' -ForegroundColor Cyan
    $env:OCTO_CLUSTER = $Dest
    Push-Location (Join-Path $Dest 'engine\context-engine')
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        bun install | Write-Host
        if ($LASTEXITCODE -ne 0) { throw 'bun install failed' }
        bun run validate octo-cluster | Write-Host
        if ($LASTEXITCODE -ne 0) { throw 'bun validate failed' }
        $ErrorActionPreference = $prevEap
    } finally {
        Pop-Location
    }
}

Write-Host '== export-public done ==' -ForegroundColor Green
