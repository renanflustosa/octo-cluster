#Requires -Version 5.1
# Install Ollama via official script (no winget).
# Usage: .\scripts\install-ollama.ps1 [-PullModel llama3.2:3b]

param(
    [string]$PullModel = "llama3.2:3b",
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"

function Get-OllamaExecutable {
    $cmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
    if (Test-Path $local) { return (Resolve-Path $local).Path }
    return $null
}

if (Get-OllamaExecutable) {
    Write-Host "[ollama] already installed: $(Get-OllamaExecutable)" -ForegroundColor DarkGray
} else {
    Write-Host "[ollama] installing via https://ollama.com/install.ps1 ..." -ForegroundColor Yellow
    Invoke-Expression (Invoke-RestMethod -Uri "https://ollama.com/install.ps1" -UseBasicParsing)
    $ollamaDir = Join-Path $env:LOCALAPPDATA "Programs\Ollama"
    if (Test-Path $ollamaDir) {
        $env:PATH = "$ollamaDir;$env:PATH"
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$ollamaDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$ollamaDir;$userPath", "User")
        }
    }
    Write-Host "[ollama] waiting for service (10s)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 10
    if (-not (Get-OllamaExecutable)) {
        throw "Ollama install finished but ollama.exe not found. Reopen terminal and retry."
    }
    Write-Host "[ollama] installed OK" -ForegroundColor Green
}

$ollama = Get-OllamaExecutable

if (-not $SkipPull -and $PullModel) {
    Write-Host "[ollama] pulling model $PullModel (CPU, may take 10-20 min)..." -ForegroundColor Yellow
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    cmd /c "`"$ollama`" pull $PullModel"
    $pullExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($pullExit -ne 0) {
        Write-Host "[ollama] WARN: pull failed (exit $pullExit). Retry: ollama pull $PullModel" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[ollama] model ready: $PullModel" -ForegroundColor Green
}

Write-Host "[ollama] verify: ollama list" -ForegroundColor DarkGray
& $ollama list
exit 0
