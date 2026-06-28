#Requires -Version 5.1
# Install Go via official MSI from https://go.dev/dl/ (no winget).
# Usage: .\scripts\install-go.ps1 [-Version go1.25.11]

param(
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'

function Get-GoExecutable {
    $cmd = Get-Command go -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($bin in @(
        (Join-Path ${env:ProgramFiles} 'Go\bin\go.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\go\bin\go.exe')
    )) {
        if (Test-Path $bin) { return (Resolve-Path $bin).Path }
    }
    return $null
}

function Add-GoToUserPath {
    foreach ($binDir in @(
        (Join-Path ${env:ProgramFiles} 'Go\bin'),
        (Join-Path $env:LOCALAPPDATA 'Programs\go\bin')
    )) {
        if (-not (Test-Path $binDir)) { continue }
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$binDir*") {
            [Environment]::SetEnvironmentVariable('Path', "$binDir;$userPath", 'User')
        }
        if ($env:PATH -notlike "*$binDir*") {
            $env:PATH = "$binDir;$env:PATH"
        }
    }
}

if (Get-GoExecutable) {
    Write-Host "[go] already installed: $(Get-GoExecutable)" -ForegroundColor DarkGray
    Add-GoToUserPath
    & go version
    exit 0
}

Write-Host '[go] resolving release from https://go.dev/dl/?mode=json ...' -ForegroundColor Yellow
$releases = Invoke-RestMethod -Uri 'https://go.dev/dl/?mode=json' -Headers @{ 'User-Agent' = 'octo-cluster-install' }

$pick = $null
if ($Version) {
    $pick = @($releases | Where-Object { $_.version -eq $Version.TrimStart('go') -or $_.version -eq $Version } | Select-Object -First 1)[0]
    if (-not $pick) { throw "Go version not found in official feed: $Version" }
} else {
    $pick = @($releases | Where-Object { $_.stable -eq $true } | Select-Object -First 1)[0]
}

$msi = @($pick.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'installer' } | Select-Object -First 1)[0]
$zip = @($pick.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'archive' } | Select-Object -First 1)[0]
if (-not $zip) { throw 'windows-amd64 archive not found in official release feed' }

$downloadDir = Join-Path $env:TEMP 'go-install'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$msiOk = $false

if ($isAdmin -and $msi) {
    $msiPath = Join-Path $downloadDir $msi.filename
    $url = "https://go.dev/dl/$($msi.filename)"
    Write-Host "[go] downloading $($msi.filename) from go.dev ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
    Write-Host '[go] installing MSI (official Windows installer) ...' -ForegroundColor DarkGray
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $msiPath, '/quiet', '/norestart') -Wait -PassThru
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { $msiOk = $true; Add-GoToUserPath }
    else { Write-Host "[go] MSI exit $($p.ExitCode) — falling back to official zip" -ForegroundColor Yellow }
}

if (-not $msiOk) {
    $installRoot = Join-Path $env:LOCALAPPDATA 'Programs\go'
    $zipPath = Join-Path $downloadDir $zip.filename
    $extractDir = Join-Path $downloadDir 'extract'
    $url = "https://go.dev/dl/$($zip.filename)"
    Write-Host "[go] downloading $($zip.filename) from go.dev ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    if (Test-Path $installRoot) { Remove-Item $installRoot -Recurse -Force }
    Move-Item (Join-Path $extractDir 'go') $installRoot
    $env:GOROOT = $installRoot
    $goBin = Join-Path $installRoot 'bin'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$goBin*") {
        [Environment]::SetEnvironmentVariable('Path', "$goBin;$userPath", 'User')
    }
    if ($env:PATH -notlike "*$goBin*") {
        $env:PATH = "$goBin;$env:PATH"
    }
    Write-Host "[go] extracted official zip to $installRoot" -ForegroundColor DarkGray
}

Add-GoToUserPath
if (-not (Get-GoExecutable)) {
    throw 'Go MSI finished but go.exe not found. Reopen terminal or log off/on.'
}

Write-Host '[go] installed OK' -ForegroundColor Green
& go version
exit 0
