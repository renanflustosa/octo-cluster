#Requires -Version 5.1
# OPE-159 — workstation performance baseline (before/after audit).
# Usage: .\scripts\workstation-benchmark.ps1 [-Label before|after] [-OutFile <path>]

param(
    [ValidateSet("before", "after", "custom")]
    [string]$Label = "custom",
    [string]$OutFile = "",
    [switch]$Json
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_load-env.ps1")
. (Join-Path $PSScriptRoot "context-engine-runtime.ps1")

function Measure-Ms {
    param([scriptblock]$Block)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Block
    $sw.Stop()
    return [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
}

$root = Get-OctoClusterRoot
$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

$bench = [ordered]@{
    collectedAt = $stamp
    ticket      = "OPE-159"
    label       = $Label
    metrics     = [ordered]@{}
}

# Idle RAM / CPU snapshot
$os = Get-CimInstance Win32_OperatingSystem
$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$bench.metrics.ramFreeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$bench.metrics.ramTotalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$bench.metrics.cpuLoadPct = [math]::Round($cpuLoad, 1)

# Boot time estimate (seconds since last boot)
$boot = $os.LastBootUpTime
$bench.metrics.uptimeHours = [math]::Round(((Get-Date) - $boot).TotalHours, 2)

# Git operations (octo-cluster)
if (Test-Path (Join-Path $root ".git")) {
    Push-Location $root
    try {
        $bench.metrics.gitStatusMs = Measure-Ms { git status --porcelain 2>&1 | Out-Null }
        $bench.metrics.gitRevParseMs = Measure-Ms { git rev-parse --show-toplevel 2>&1 | Out-Null }
    } finally { Pop-Location }
}

# LanceDB search latency
$ce = Get-ContextEngineRoot
if (Test-Path $ce) {
    $bun = Get-BunExecutable
    if ($bun) {
        $searchMs = Measure-Ms {
            Push-Location $ce
            try {
                cmd /c "`"$bun`" run search octo-cluster --query `"hardware optimization workstation`" >nul 2>nul"
            } finally { Pop-Location }
        }
        $bench.metrics.lanceDbSearchMs = $searchMs
    }
}

# Context-engine validate timing
if (Test-Path $ce) {
    $bun = Get-BunExecutable
    if ($bun) {
        $validateMs = Measure-Ms {
            Push-Location $ce
            try {
                cmd /c "`"$bun`" run validate octo-cluster >nul 2>nul"
            } finally { Pop-Location }
        }
        $bench.metrics.contextEngineValidateMs = $validateMs
    }
}

# Productivity audit timing
$auditScript = Join-Path $root "scripts\productivity-audit.ps1"
if (Test-Path $auditScript) {
    $bench.metrics.productivityAuditMs = Measure-Ms {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $auditScript 2>&1 | Out-Null
    }
}

# Disk throughput (winsat — may require elevation; graceful fallback)
$winsatOut = Join-Path $env:TEMP "winsat-disk-ope159.txt"
try {
    $winsatMs = Measure-Ms {
        $p = Start-Process -FilePath "winsat.exe" -ArgumentList "disk -drive c" -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $winsatOut -ErrorAction SilentlyContinue
    }
    $bench.metrics.winsatDiskMs = $winsatMs
    if (Test-Path $winsatOut) {
        $content = Get-Content $winsatOut -Raw -ErrorAction SilentlyContinue
        if ($content -match 'Disk\s+Sequential\s+64\.0\s+Read\s+([\d.]+)\s+MB/s') {
            $bench.metrics.diskSeqReadMbps = [double]$Matches[1]
        }
        Remove-Item $winsatOut -Force -ErrorAction SilentlyContinue
    }
} catch {
    $bench.metrics.winsatDiskMs = $null
    $bench.metrics.diskSeqReadMbps = $null
}

# Docker ping (if available)
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $bench.metrics.dockerInfoMs = Measure-Ms { docker info 2>&1 | Out-Null }
}

# WSL status (if available)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $bench.metrics.wslListMs = Measure-Ms { wsl -l -v 2>&1 | Out-Null }
}

# Output path
$metricsDir = Join-Path $root "state\logs\metrics-baseline"
New-Item -ItemType Directory -Force -Path $metricsDir | Out-Null
if (-not $OutFile) {
    $suffix = if ($Label -eq "custom") { (Get-Date -Format "yyyyMMdd-HHmmss") } else { $Label }
    $OutFile = Join-Path $metricsDir "ope-159-$suffix.json"
}

$jsonOut = $bench | ConvertTo-Json -Depth 6
Set-Content -Path $OutFile -Value $jsonOut -Encoding UTF8

if ($Json) {
    Write-Output $jsonOut
} else {
    Write-Host "== workstation benchmark (OPE-159) ==" -ForegroundColor Cyan
    Write-Host "Label:  $Label" -ForegroundColor Gray
    foreach ($k in $bench.metrics.Keys) {
        Write-Host ("  {0,-28} {1}" -f $k, $bench.metrics[$k]) -ForegroundColor DarkGray
    }
    Write-Host "Output: $OutFile" -ForegroundColor Green
}

exit 0
