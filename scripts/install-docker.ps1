#Requires -Version 5.1
# Install Docker Desktop via direct download (no winget).
# Usage: .\scripts\install-docker.ps1 [-UserInstall]
# Requires WSL2 backend (run install-wsl.ps1 first).

param(
    [switch]$UserInstall = $true
)

$ErrorActionPreference = "Stop"

$installerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$downloadDir = Join-Path $env:TEMP "docker-desktop-install"
$installerPath = Join-Path $downloadDir "Docker Desktop Installer.exe"

function Get-DockerCliPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\resources\bin\docker.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Docker\Docker\resources\bin\docker.exe"),
        (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe")
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-DockerInstalled {
    if (Get-DockerCliPath) { return $true }
    return $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
}

function Add-DockerToUserPath {
    $binDir = Split-Path (Get-DockerCliPath) -Parent
    if (-not $binDir) { return }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$binDir;$userPath", "User")
        $env:PATH = "$binDir;$env:PATH"
    }
}

if (Test-DockerInstalled) {
    Write-Host "[docker] already installed" -ForegroundColor Green
    Add-DockerToUserPath
    & (Get-DockerCliPath) --version
    exit 0
}

cmd /c "wsl --status >nul 2>nul"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[docker] WARN: WSL not ready. Run .\scripts\install-wsl.ps1 first" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

if (-not (Test-Path $installerPath)) {
    Write-Host "[docker] downloading installer (no winget)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
}

$installArgs = @("install", "--quiet", "--accept-license")
if ($UserInstall) { $installArgs += "--user" }

Write-Host "[docker] installing..." -ForegroundColor DarkGray
$p = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
    Write-Host "[docker] install exit $($p.ExitCode)" -ForegroundColor Yellow
}

Add-DockerToUserPath
$cli = Get-DockerCliPath
if ($cli) {
    Write-Host "[docker] install complete: $(& $cli --version)" -ForegroundColor Green
    Write-Host "[docker] start Docker Desktop once from Start menu before docker run" -ForegroundColor DarkGray
} else {
    Write-Host "[docker] install may be incomplete; re-run script" -ForegroundColor Yellow
    exit 1
}
exit 0
