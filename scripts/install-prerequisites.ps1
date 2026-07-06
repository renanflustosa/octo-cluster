#Requires -Version 5.1
# Fast prerequisite installs via direct downloads (no winget).
# Dot-sourced from install.ps1

function Add-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Directory)
    if (-not (Test-Path $Directory)) { return }
    $dir = (Resolve-Path $Directory).Path
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -like ("*" + $dir + "*")) { return }
    [Environment]::SetEnvironmentVariable('Path', ($dir + ';' + $userPath), 'User')
    $env:PATH = $dir + ';' + $env:PATH
    Write-Host "[prereq] PATH += $dir" -ForegroundColor DarkGray
}

function Get-GhExecutable {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $portable = Join-Path $env:LOCALAPPDATA 'Programs\gh\bin\gh.exe'
    if (Test-Path $portable) { return (Resolve-Path $portable).Path }
    $programFiles = "${env:ProgramFiles}\GitHub CLI\gh.exe"
    if (Test-Path $programFiles) { return (Resolve-Path $programFiles).Path }
    return $null
}

function Install-GhCli {
    if (Get-GhExecutable) {
        Write-Host '[prereq] gh already installed' -ForegroundColor DarkGray
        return $true
    }

    Write-Host '[prereq] installing GitHub CLI (direct zip)...' -ForegroundColor Yellow
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/latest' -Headers @{ 'User-Agent' = 'octo-cluster-install' }
    $asset = @($release.assets | Where-Object { $_.name -match 'windows_amd64\.zip$' } | Select-Object -First 1)[0]
    if (-not $asset) { throw 'gh: windows_amd64.zip not found in latest release' }

    $tempZip = Join-Path $env:TEMP ('gh-' + [guid]::NewGuid().ToString('n') + '.zip')
    $tempDir = Join-Path $env:TEMP ('gh-extract-' + [guid]::NewGuid().ToString('n'))
    $installRoot = Join-Path $env:LOCALAPPDATA 'Programs\gh'

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
        $ghExe = Get-ChildItem -Path $tempDir -Filter 'gh.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $ghExe) { throw 'gh: gh.exe not found in zip' }

        if (Test-Path $installRoot) { Remove-Item $installRoot -Recurse -Force }
        $ghBin = Join-Path $installRoot 'bin'
        New-Item -ItemType Directory -Force -Path $ghBin | Out-Null
        Copy-Item -Path (Join-Path $ghExe.DirectoryName '*') -Destination $ghBin -Recurse -Force
        Add-UserPathEntry -Directory $ghBin
        return [bool](Get-GhExecutable)
    } finally {
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-RgExecutable {
    $cmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $portable = Join-Path $env:LOCALAPPDATA 'Programs\ripgrep\rg.exe'
    if (Test-Path $portable) { return (Resolve-Path $portable).Path }
    return $null
}

function Install-Ripgrep {
    if (Get-RgExecutable) {
        Write-Host '[prereq] ripgrep already installed' -ForegroundColor DarkGray
        return $true
    }

    Write-Host '[prereq] installing ripgrep (direct zip)...' -ForegroundColor Yellow
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/BurntSushi/ripgrep/releases/latest' -Headers @{ 'User-Agent' = 'octo-cluster-install' }
    $asset = @($release.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1)[0]
    if (-not $asset) { throw 'ripgrep: windows zip not found in latest release' }

    $tempZip = Join-Path $env:TEMP ('rg-' + [guid]::NewGuid().ToString('n') + '.zip')
    $tempDir = Join-Path $env:TEMP ('rg-extract-' + [guid]::NewGuid().ToString('n'))
    $installRoot = Join-Path $env:LOCALAPPDATA 'Programs\ripgrep'

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
        $rgExe = Get-ChildItem -Path $tempDir -Filter 'rg.exe' -Recurse | Select-Object -First 1
        if (-not $rgExe) { throw 'rg.exe missing in zip' }

        New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
        Copy-Item -Path $rgExe.FullName -Destination (Join-Path $installRoot 'rg.exe') -Force
        Add-UserPathEntry -Directory $installRoot
        return [bool](Get-RgExecutable)
    } finally {
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host '[prereq] git OK' -ForegroundColor DarkGray
        return $true
    }
    Write-Host '[prereq] git not found — install from https://git-scm.com/download/win then re-run install.ps1' -ForegroundColor Red
    return $false
}

function Get-OllamaExecutable {
    $cmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if (Test-Path $local) { return (Resolve-Path $local).Path }
    return $null
}

function Install-Ollama {
    param([string]$PullModel = 'llama3.2:3b', [switch]$SkipPull)

    if (Get-OllamaExecutable) {
        Write-Host '[prereq] ollama already installed' -ForegroundColor DarkGray
    } else {
        Write-Host '[prereq] installing Ollama (official script, no winget)...' -ForegroundColor Yellow
        Invoke-Expression (Invoke-RestMethod -Uri 'https://ollama.com/install.ps1' -UseBasicParsing)
        $ollamaDir = Join-Path $env:LOCALAPPDATA 'Programs\Ollama'
        if (Test-Path $ollamaDir) { Add-UserPathEntry -Directory $ollamaDir }
        if (-not (Get-OllamaExecutable)) { throw 'Ollama install failed — run .\scripts\install-ollama.ps1' }
    }

    if (-not $SkipPull -and $PullModel) {
        $exe = Get-OllamaExecutable
        Write-Host "[prereq] ollama pull $PullModel ..." -ForegroundColor DarkGray
        & $exe pull $PullModel
        if ($LASTEXITCODE -ne 0) { throw "ollama pull $PullModel failed" }
    }
    return [bool](Get-OllamaExecutable)
}

function Install-PlatformPrerequisites {
    param([switch]$SkipOptional)

    if ($IsLinux -or $IsMacOS) {
        Write-Host '[prereq] Linux/macOS detected — use ./install.sh (native) or Dev Container.' -ForegroundColor Yellow
        Write-Host '[prereq] install-prerequisites.ps1 is Windows-only; skipping Windows zip installers.' -ForegroundColor DarkGray
        return
    }

    Write-Host '== platform prerequisites (direct download, no winget) ==' -ForegroundColor Cyan

    $runtime = Join-Path $PSScriptRoot 'context-engine-runtime.ps1'
    if (Test-Path $runtime) { . $runtime }

    $pwshScript = Join-Path $PSScriptRoot 'install-powershell.ps1'
    if (Test-Path $pwshScript) { . $pwshScript }

    $gitOk = Ensure-Git
    if (-not $gitOk) { throw 'Git is required. Install from https://git-scm.com/download/win' }

    if (-not (Get-BunExecutable)) {
        if (-not (Install-BunRuntime)) { throw 'Bun install failed. Try: irm bun.sh/install.ps1 | iex' }
    } else {
        Write-Host '[prereq] bun OK' -ForegroundColor DarkGray
    }

    $bunBin = Join-Path $env:USERPROFILE '.bun\bin'
    Add-UserPathEntry -Directory $bunBin

    if (-not (Install-PowerShell7)) { throw 'PowerShell 7 (pwsh) install failed — run .\scripts\install-powershell.ps1' }

    if (-not (Install-GhCli)) { throw 'GitHub CLI (gh) install failed' }

    if (-not $SkipOptional) {
        try { Install-Ripgrep | Out-Null } catch { Write-Warning "ripgrep optional install skipped: $($_.Exception.Message)" }
    }

    Write-Host '[prereq] done' -ForegroundColor Green
}
