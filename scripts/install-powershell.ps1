#Requires -Version 5.1
# Install PowerShell 7+ via GitHub release (no winget / no Microsoft Store).
# Usage: .\scripts\install-powershell.ps1 [-Version 7.6.3]

param(
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'

function Get-PwshExecutable {
    foreach ($candidate in @(
        (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Join-Path ${env:ProgramFiles} 'PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe')
    )) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

function Get-InstalledPwshVersion {
    $exe = Get-PwshExecutable
    if (-not $exe) { return $null }
    try {
        $output = (& $exe -NoProfile -v 2>&1 | Out-String).Trim()
        if ($output -match 'PowerShell\s+([\d\.]+)') {
            return [version]$Matches[1]
        }
        return $null
    } catch {
        return $null
    }
}

function Add-PwshToUserPath {
    param([Parameter(Mandatory = $true)][string]$Directory)
    if (-not (Test-Path $Directory)) { return }
    $dir = (Resolve-Path $Directory).Path
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -like ("*" + $dir + "*")) { return }
    [Environment]::SetEnvironmentVariable('Path', ($dir + ';' + $userPath), 'User')
    if ($env:PATH -notlike ("*" + $dir + "*")) {
        $env:PATH = $dir + ';' + $env:PATH
    }
    Write-Host "[pwsh] PATH += $dir" -ForegroundColor DarkGray
}

function Install-PowerShell7 {
    param([string]$TargetVersion = '')

    Write-Host '[pwsh] resolving latest release from GitHub...' -ForegroundColor DarkGray
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' `
        -Headers @{ 'User-Agent' = 'octo-cluster-install' }

    $tagVersion = [version]($release.tag_name.TrimStart('v'))
    $want = if ($TargetVersion) { [version]$TargetVersion.TrimStart('v') } else { $tagVersion }

    $installed = Get-InstalledPwshVersion
    if ($installed -and $installed -ge $want) {
        Write-Host "[pwsh] already installed: $installed (need >= $want)" -ForegroundColor DarkGray
        $exe = Get-PwshExecutable
        if ($exe) { Add-PwshToUserPath -Directory (Split-Path $exe -Parent) }
        return $true
    }

    if ($installed) {
        Write-Host "[pwsh] upgrading $installed -> $want ..." -ForegroundColor Yellow
    } else {
        Write-Host "[pwsh] installing PowerShell $want (direct download, no winget)..." -ForegroundColor Yellow
    }

    $msiAsset = @($release.assets | Where-Object { $_.name -match '^PowerShell-[\d\.]+-win-x64\.msi$' } | Select-Object -First 1)[0]
    $zipAsset = @($release.assets | Where-Object { $_.name -match '^PowerShell-[\d\.]+-win-x64\.zip$' } | Select-Object -First 1)[0]
    if (-not $zipAsset) { throw 'pwsh: win-x64.zip not found in latest GitHub release' }

    $downloadDir = Join-Path $env:TEMP 'powershell-install'
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    $msiOk = $false

    if ($isAdmin -and $msiAsset) {
        $msiPath = Join-Path $downloadDir $msiAsset.name
        Write-Host "[pwsh] downloading $($msiAsset.name) ..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $msiPath -UseBasicParsing
        Write-Host '[pwsh] installing MSI (ADD_PATH=1) ...' -ForegroundColor DarkGray
        $msiArgs = @(
            '/i', $msiPath,
            '/quiet', '/norestart',
            'USE_MU=1', 'USE_MUC=1',
            'ADD_PATH=1',
            'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0',
            'ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=0',
            'ENABLE_PSREMOTING=0',
            'REGISTER_MANIFEST=1'
        )
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { $msiOk = $true }
        else { Write-Host "[pwsh] MSI exit $($p.ExitCode) - falling back to zip" -ForegroundColor Yellow }
    }

    if (-not $msiOk) {
        $installRoot = Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7'
        $zipPath = Join-Path $downloadDir ($zipAsset.name -replace '\.zip$', ('-' + [guid]::NewGuid().ToString('n') + '.zip'))
        $extractDir = Join-Path $downloadDir 'extract'
        Write-Host "[pwsh] downloading $($zipAsset.name) ..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $pwshExe = Get-ChildItem -Path $extractDir -Filter 'pwsh.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $pwshExe) { throw 'pwsh.exe not found in release zip' }
        $sourceRoot = $pwshExe.DirectoryName
        if (Test-Path $installRoot) { Remove-Item $installRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
        Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force
        Add-PwshToUserPath -Directory $installRoot
        Write-Host "[pwsh] extracted to $installRoot" -ForegroundColor DarkGray
    } else {
        Add-PwshToUserPath -Directory (Join-Path ${env:ProgramFiles} 'PowerShell\7')
    }

    $after = Get-InstalledPwshVersion
    if (-not $after -or $after -lt $want) {
        throw 'PowerShell 7 install finished but pwsh not found or version too old - reopen terminal and re-run .\install.ps1'
    }

    Write-Host "[pwsh] installed OK ($after)" -ForegroundColor Green
    return $true
}

if ($MyInvocation.InvocationName -ne '.') {
    Install-PowerShell7 -TargetVersion $Version
    $exe = Get-PwshExecutable
    if ($exe) { & $exe -NoProfile -v }
    exit 0
}
