# Daily core bootstrap (~30s-2min). Domain-agnostic; child scripts extend via invoke-domain-script.
param(
    [string]$Profile = "",
    [switch]$SkipIndex
)
$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
if (-not $Profile) { $Profile = Get-DefaultMemoryProfile }
function Step([string]$Msg) { Write-Host ""; Write-Host "== $Msg ==" -ForegroundColor Cyan }
$mem = Get-MemoryRoot -Profile $Profile
$memoryManifest = Join-Path $mem "vector\manifest.json"
$ce = Get-ContextEngineRoot
Step "Context-engine validate"
if (Test-Path $ce) {
    try {
        $exitCode = Invoke-ContextEngine run --cwd $ce validate $Profile
        if ($exitCode -ne 0) { Write-Host "WARN: context-engine validate reported issues" -ForegroundColor Yellow }
    } catch { Write-Host "WARN: context-engine validate skipped - $($_.Exception.Message)" -ForegroundColor Yellow }
} else { Write-Host "WARN: context-engine not found at $ce" -ForegroundColor Yellow }
Step "Context budget"
& powershell -ExecutionPolicy Bypass -File (Get-CoreScriptPath "context-budget") -Profile $Profile
Step "Memory profile"
Write-Host "Profile: $Profile" -ForegroundColor Green
if (Test-Path $mem) { Write-Host "  root: $mem" -ForegroundColor DarkGray }
else { New-Item -ItemType Directory -Force -Path $mem | Out-Null; Write-Host "  created: $mem" -ForegroundColor DarkGray }
if (-not $SkipIndex) {
    $stale = $true
    if (Test-Path $memoryManifest) {
        try {
            $m = Get-Content $memoryManifest -Raw | ConvertFrom-Json
            $age = (New-TimeSpan -Start ([datetime]$m.updatedAt) -End (Get-Date)).TotalDays
            if ($age -lt 7) { $stale = $false; Write-Host "LanceDB index OK ($([int]$age)d old)" -ForegroundColor Green }
        } catch { }
    }
    if ($stale -and (Test-Path $ce)) {
        Step "Incremental memory index (stale or missing)"
        try {
            $exitCode = Invoke-ContextEngineIncrementalIndex -Profile $Profile -Kind memory -Incremental
            if ($exitCode -ne 0) { Write-Host "WARN: incremental index failed" -ForegroundColor Yellow }
        } catch { Write-Host "WARN: incremental index skipped - $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}
$startStamp = Join-Path $mem "last-start-workspace.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $startStamp -Parent) | Out-Null
Set-Content -Path $startStamp -Value (Get-Date -Format "yyyy-MM-dd") -Encoding UTF8
Step "Scan bootstrap (core)"
& powershell -ExecutionPolicy Bypass -File (Get-CoreScriptPath "scan-bootstrap") -Profile $Profile -SkipStartWorkspace
$fullMetrics = Join-Path (Get-OctoClusterRoot) "eval\metrics\measure-harness-full.ps1"
if (Test-Path $fullMetrics) {
    Step "Metrics full (weekly if due)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $fullMetrics 2>&1 | Out-Null
}
Write-Host ""; Write-Host "Core start-workspace OK. New chat -> /scan <TICKET> description" -ForegroundColor Green
exit 0
