# Generic /scan bootstrap - implicit start-workspace + context-engine validate.
param(
    [string]$Profile = "",
    [switch]$SkipStartWorkspace
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
$shipCtx = Get-ShipExecutionContext
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
Write-Host ""; Write-Host "Core scan bootstrap done." -ForegroundColor Cyan
exit 0
