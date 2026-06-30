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

# Boundary gates (pre-commit / pre-push)
$hooks = Join-Path $PSScriptRoot "scripts\install-git-hooks.ps1"
if (Test-Path $hooks) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $hooks
}

# Seed local workspace from public template (gitignored; may add private folders)
$wsExample = Join-Path $env:OCTO_CLUSTER 'octo-cluster.code-workspace.example'
$wsLocal = Join-Path $env:OCTO_CLUSTER 'octo-cluster.code-workspace'
if ((Test-Path $wsExample) -and -not (Test-Path $wsLocal)) {
    Copy-Item -LiteralPath $wsExample -Destination $wsLocal
    Write-Host 'Created octo-cluster.code-workspace from .example' -ForegroundColor DarkGray
}

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

# Seed platform memory profile from tracked fixtures
$bun = Get-BunExecutable
if ($bun) {
    $ce = Join-Path $env:OCTO_CLUSTER "engine\context-engine"
    Push-Location $ce
    try { & $bun run seed-profile octo-cluster } finally { Pop-Location }
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
  1. OCTO_CLUSTER is set at User scope (persists across terminals and agent shells).
     Open octo-cluster.code-workspace for session env in integrated terminals.
  2. gh auth login   (once, for PRs/issues)
  3. New chat -> /scan <TICKET> description

Entry point: octo.ps1 (see docs/architecture/path-resolution.md)

Active context: AI_EXECUTION_CONTEXT=platform. See docs/guides/onboarding.md.

"@
