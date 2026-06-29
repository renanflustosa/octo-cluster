#Requires -Version 5.1
<#
.SYNOPSIS
  Bootstrap octo-cluster on a new machine (platform / CORE context).
  Installs prerequisites via direct download (no winget): git check, bun, gh, ripgrep.
#>
param(
    [string]$WorkspaceRoot = $PSScriptRoot,
    [switch]$SkipOptional,
    [switch]$WithOllama
)

$ErrorActionPreference = "Stop"
$env:OCTO_CLUSTER = (Resolve-Path $WorkspaceRoot).Path
[Environment]::SetEnvironmentVariable('OCTO_CLUSTER', $env:OCTO_CLUSTER, 'User')

Write-Host "OCTO_CLUSTER=$env:OCTO_CLUSTER"

$migrate = Join-Path $PSScriptRoot "scripts\migrate-octo-cluster.ps1"
if (Test-Path $migrate) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $migrate -WorkspaceRoot $env:OCTO_CLUSTER
}

# Prerequisites first (bun, gh, rg) - fast direct downloads
$prereq = Join-Path $PSScriptRoot "scripts\install-prerequisites.ps1"
. $prereq
Install-PlatformPrerequisites -SkipOptional:$SkipOptional

if ($WithOllama) {
    try { Install-Ollama | Out-Null } catch { Write-Warning "Ollama optional install skipped: $($_.Exception.Message)" }
}

# Sync domains -> .cursor
& (Join-Path $PSScriptRoot "scripts\sync-cursor.ps1")

$validateHooks = Join-Path $PSScriptRoot "scripts\validate-cursor-hooks.ps1"
if (Test-Path $validateHooks) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validateHooks
    if ($LASTEXITCODE -ne 0) { throw "validate-cursor-hooks failed - run .\scripts\sync-cursor.ps1" }
}

# State dirs
@("state\memory", "state\logs\metrics-baseline", "state\metrics") | ForEach-Object {
    New-Item -ItemType Directory -Force -Path (Join-Path $env:OCTO_CLUSTER $_) | Out-Null
}

# Context engine deps (Bun + LanceDB)
. (Join-Path $PSScriptRoot "scripts\_load-env.ps1")
Ensure-ContextEngineDeps -AllowInstall | Out-Null
Write-Host "context-engine deps OK (Bun + @lancedb/lancedb)" -ForegroundColor DarkGray

# Seed platform memory profile
$memProfile = Join-Path $env:OCTO_CLUSTER "state\memory\octo-cluster"
New-Item -ItemType Directory -Force -Path (Join-Path $memProfile "context") | Out-Null
$overview = Join-Path $memProfile "overview.md"
if (-not (Test-Path $overview)) {
    Set-Content -Path $overview -Encoding UTF8 -Value "# octo-cluster memory profile`n`nPlatform CORE context."
}
$architecture = Join-Path $memProfile "context\architecture.md"
if (-not (Test-Path $architecture)) {
    Set-Content -Path $architecture -Encoding UTF8 -Value "# Architecture (platform)`n`n- Core: domains/core, capabilities/, scripts/`n- Context engine: engine/context-engine`n- Execution context: contexts/platform.json"
    Write-Host "Seeded state/memory/octo-cluster" -ForegroundColor DarkGray
}

$bun = Get-BunExecutable
if ($bun) {
    $ce = Join-Path $env:OCTO_CLUSTER "engine\context-engine"
    Write-Host "Indexing octo-cluster memory..." -ForegroundColor DarkGray
    Push-Location $ce
    try { & $bun run index-incremental octo-cluster --kind memory --incremental } finally { Pop-Location }
}

$audit = Join-Path $env:OCTO_CLUSTER "scripts\productivity-audit.ps1"
if (Test-Path $audit) {
    Write-Host ""
    & powershell -NoProfile -ExecutionPolicy Bypass -File $audit
    if ($LASTEXITCODE -ne 0) { throw "productivity-audit failed - fix missing tools and re-run .\install.ps1" }
}

Write-Host @"

Done. Next steps:
  1. Set OCTO_CLUSTER permanently (User env) or open octo-cluster.code-workspace.
  2. gh auth login   (once, for PRs/issues)
  3. New chat -> /scan <TICKET> description

Active context: AI_EXECUTION_CONTEXT=platform. See docs/ONBOARDING.md.

"@
