# Generic /scan bootstrap - implicit start-workspace + context-engine validate + optional ticket providers.
param(
    [string]$Profile = "",
    [string]$Ticket = "",
    [string]$TicketUrl = "",
    [string]$RepoPath = "",
    [switch]$SkipStartWorkspace
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')
$shipCtx = Get-ShipExecutionContext -RepoPath $RepoPath
if (-not $Profile) {
    $Profile = if ($shipCtx.memory_profile) { [string]$shipCtx.memory_profile } else { 'octo-cluster' }
}
$memRoot = Get-MemoryRoot -Profile $Profile
$startStamp = Join-Path $memRoot "last-start-workspace.txt"
$today = (Get-Date).ToString("yyyy-MM-dd")
$invokeScript = Join-Path (Get-OctoClusterRoot) "scripts\invoke-domain-script.ps1"
function Write-Step([string]$Msg) { Write-Host ""; Write-Host "== $Msg ==" -ForegroundColor Cyan }
if (-not $SkipStartWorkspace) {
    $runStart = $true
    if (Test-Path $startStamp) {
        $last = (Get-Content $startStamp -Raw).Trim()
        if ($last -eq $today) { $runStart = $false }
    }
    if ($runStart) {
        Write-Step "Implicit start-workspace (stale or missing stamp)"
        & powershell -ExecutionPolicy Bypass -File $invokeScript -Name start-workspace
        if ($LASTEXITCODE -ne 0) { Write-Host "WARN: implicit start-workspace reported issues" -ForegroundColor Yellow }
        New-Item -ItemType Directory -Force -Path $memRoot | Out-Null
        Set-Content -Path $startStamp -Value $today -Encoding UTF8
    } else { Write-Host "[ok] start-workspace already ran today ($today)" -ForegroundColor Green }
}
Write-Step "Context-engine validate"
$ce = Get-ContextEngineRoot
try {
    $exitCode = Invoke-ContextEngine run --cwd $ce validate $Profile
    if ($exitCode -ne 0) { Write-Host "WARN: context-engine validate failed" -ForegroundColor Yellow }
    else { Write-Host "[ok] context-engine validate passed" -ForegroundColor Green }
} catch { Write-Host "WARN: context-engine validate skipped - $($_.Exception.Message)" -ForegroundColor Yellow }

# Optional pack ticket providers (phase=ticket). Core stays tracker-agnostic.
if ($Ticket) {
    Write-Step "Ticket providers ($Ticket)"
    if (-not $RepoPath) {
        $RepoPath = if ($shipCtx.active_repo_path) { [string]$shipCtx.active_repo_path } else { (Get-OctoClusterRoot) }
    }
    $providers = @(Get-DiscoveredCapabilities -Pipeline scan -Phase ticket -RepoPath $RepoPath -ShipContext $shipCtx)
    if ($providers.Count -eq 0) {
        Write-Host "[scan] no ticket providers - agent uses user message as ticket source" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Force -Path $memRoot | Out-Null
        $cardPath = Join-Path $memRoot "ticket-card.json"
        foreach ($provider in $providers) {
            if (-not $provider._script_path -or -not (Test-Path $provider._script_path)) {
                Write-Host "WARN: ticket provider '$($provider.id)' missing script" -ForegroundColor Yellow
                continue
            }
            Write-Host "== scan provider: $($provider.id) ==" -ForegroundColor Cyan
            $params = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $provider._script_path,
                '-Ticket', $Ticket, '-Profile', $Profile, '-OutFile', $cardPath
            )
            if ($TicketUrl) { $params += @('-Url', $TicketUrl) }
            & powershell @params
            $code = if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq '') { 0 } else { [int]$LASTEXITCODE }
            $blocking = if ($null -ne $provider.blocking) { [bool]$provider.blocking } else { $false }
            if ($code -ne 0) {
                if ($blocking) {
                    Write-Host "[BLOCKED] ticket provider $($provider.id) failed (exit $code)" -ForegroundColor Red
                    exit $code
                }
                Write-Host "[warn] non-blocking ticket provider $($provider.id) failed (exit $code)" -ForegroundColor Yellow
            } elseif (Test-Path $cardPath) {
                Write-Host "TICKET_CARD=$cardPath" -ForegroundColor Green
                break
            }
        }
    }
}

Write-Host ""; Write-Host "Core scan bootstrap done." -ForegroundColor Cyan
exit 0
