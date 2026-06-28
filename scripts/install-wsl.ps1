#Requires -Version 5.1
# Install WSL2 + Ubuntu via Microsoft web download (no winget, no Store required).
# Usage: .\scripts\install-wsl.ps1 [-Distribution Ubuntu] [-NoLaunch]
# NOTE: Requires Administrator. Reboot likely required.

param(
    [string]$Distribution = "Ubuntu",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "[wsl] elevation required, restarting as Administrator..." -ForegroundColor Yellow
    $args = @("-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "-Distribution", $Distribution)
    if ($NoLaunch) { $args += "-NoLaunch" }
    Start-Process powershell -Verb RunAs -ArgumentList $args -Wait
    exit $LASTEXITCODE
}

Write-Host "== WSL2 install OPE-159 no winget ==" -ForegroundColor Cyan

$distList = cmd /c "wsl -l -v 2>nul"
if ($LASTEXITCODE -eq 0 -and $distList -match $Distribution) {
    Write-Host "[wsl] $Distribution already registered" -ForegroundColor Green
    cmd /c "wsl -l -v"
    exit 0
}

$installArgs = @("--install", "--web-download", "-d", $Distribution)
if ($NoLaunch) { $installArgs += @("--no-launch") }

Write-Host "[wsl] running: wsl $($installArgs -join ' ')" -ForegroundColor DarkGray
cmd /c "wsl $($installArgs -join ' ')"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[wsl] install exit $LASTEXITCODE, may need reboot then re-run" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

Write-Host "[wsl] install command completed" -ForegroundColor Green
Write-Host "[wsl] REBOOT if prompted, then: wsl -l -v" -ForegroundColor Yellow
cmd /c "wsl -l -v 2>nul"
exit 0
