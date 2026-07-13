#Requires -Version 5.1
# 8CL-159 — read-only workstation inventory (hardware, OS, dev stack, Cursor, storage).
# Usage: .\scripts\workstation-inventory.ps1 [-Json] [-OutFile <path>]

param(
    [switch]$Json,
    [string]$OutFile = ""
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_load-env.ps1")

function Get-DirSizeBytes {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [long]$sum
    } catch { return $null }
}

function Get-CommandVersion {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { return $null }
    try {
        $v = & $Name --version 2>&1 | Select-Object -First 1
        return ($v | Out-String).Trim()
    } catch { return "present" }
}

$root = Get-OctoClusterRoot
$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$dateTag = Get-Date -Format "yyyy-MM-dd"

$inv = [ordered]@{
    collectedAt = $stamp
    ticket      = "8CL-159"
    hostname    = $env:COMPUTERNAME
    user        = $env:USERNAME
}

# Hardware
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ram = Get-CimInstance Win32_PhysicalMemory
$gpu = Get-CimInstance Win32_VideoController
$disks = Get-CimInstance Win32_DiskDrive
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

$inv.hardware = [ordered]@{
    cpu = [ordered]@{
        name           = $cpu.Name
        cores          = $cpu.NumberOfCores
        threads        = $cpu.NumberOfLogicalProcessors
        maxClockMhz    = $cpu.MaxClockSpeed
        architecture   = $cpu.Architecture
    }
    memory = [ordered]@{
        totalGb    = [math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB, 2)
        modules    = @($ram | ForEach-Object {
            [ordered]@{
                capacityGb = [math]::Round($_.Capacity / 1GB, 2)
                speedMhz   = $_.Speed
                manufacturer = $_.Manufacturer
            }
        })
    }
    gpu = @($gpu | ForEach-Object {
        [ordered]@{
            name        = $_.Name
            driverVersion = $_.DriverVersion
            adapterRamMb = if ($_.AdapterRAM) { [math]::Round($_.AdapterRAM / 1MB, 0) } else { $null }
        }
    })
    disks = @($disks | ForEach-Object {
        [ordered]@{
            model    = $_.Model
            sizeGb   = [math]::Round($_.Size / 1GB, 2)
            interface = $_.InterfaceType
        }
    })
    volumes = @($logical | ForEach-Object {
        [ordered]@{
            drive       = $_.DeviceID
            sizeGb      = [math]::Round($_.Size / 1GB, 2)
            freeGb      = [math]::Round($_.FreeSpace / 1GB, 2)
            fileSystem  = $_.FileSystem
        }
    })
}

# OS
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$powerPlan = try {
    $active = powercfg /getactivescheme 2>&1 | Out-String
    ($active -split '\(')[1] -replace '\).*', '' -replace '^\s+', ''
} catch { $null }

$inv.os = [ordered]@{
    caption      = $os.Caption
    version      = $os.Version
    build        = $os.BuildNumber
    arch         = $os.OSArchitecture
    lastBoot     = $os.LastBootUpTime.ToString("yyyy-MM-ddTHH:mm:ss")
    totalVisibleMemoryGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    freePhysicalMemoryGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    manufacturer = $cs.Manufacturer
    model        = $cs.Model
    powerPlan    = $powerPlan
}

# Environment / workspace
$coreWorkspacePath = $null
$pvRoot = [Environment]::GetEnvironmentVariable('PERSONAL_VAULT_ROOT', 'User')
if ($pvRoot) {
    $candidate = Join-Path $pvRoot 'workspaces\octo-cluster.code-workspace'
    if (Test-Path -LiteralPath $candidate) { $coreWorkspacePath = $candidate }
}

$inv.workspace = [ordered]@{
    octoCluster         = $env:OCTO_CLUSTER
    aiExecutionContext  = $env:AI_EXECUTION_CONTEXT
    platformContextPath = Join-Path $root "contexts\runtime\platform.json"
    coreWorkspacePath   = $coreWorkspacePath
    githubRoot          = if (Test-Path "C:\GitHub") { "C:\GitHub" } else { $null }
    repos = @(
        @{ name = "octo-cluster"; path = $root; exists = $true }
    )
}

# Dev stack
$inv.devStack = [ordered]@{
    git   = Get-CommandVersion "git"
    gh    = Get-CommandVersion "gh"
    bun   = if (Test-Path "$env:USERPROFILE\.bun\bin\bun.exe") { & "$env:USERPROFILE\.bun\bin\bun.exe" --version 2>&1 | Select-Object -First 1 } else { Get-CommandVersion "bun" }
    node  = Get-CommandVersion "node"
    rg    = Get-CommandVersion "rg"
    docker = Get-CommandVersion "docker"
    wsl   = Get-CommandVersion "wsl"
    ollama = Get-CommandVersion "ollama"
}

# WSL / Docker status
$inv.runtime = [ordered]@{}
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    try {
        $wslList = wsl -l -v 2>&1 | Out-String
        $inv.runtime.wsl = ($wslList -split "`n" | Where-Object { $_.Trim() }) -join "; "
    } catch { $inv.runtime.wsl = "error" }
}
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        $inv.runtime.docker = (docker info --format "{{.OperatingSystem}}" 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { $inv.runtime.docker = "not_running" }
    } catch { $inv.runtime.docker = "error" }
}

# Ollama models (names only)
if (Get-Command ollama -ErrorAction SilentlyContinue) {
    try {
        $models = ollama list 2>&1 | Out-String
        $inv.runtime.ollamaModels = ($models -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch "^NAME" }) -join "; "
    } catch { $inv.runtime.ollamaModels = $null }
}

# Cursor paths (no secrets)
$cursorUser = Join-Path $env:APPDATA "Cursor\User"
$inv.cursor = [ordered]@{
    userSettingsPath = Join-Path $cursorUser "settings.json"
    userSettingsExists = (Test-Path (Join-Path $cursorUser "settings.json"))
    extensionsPath = Join-Path $env:USERPROFILE ".cursor\extensions"
    mcpConfigPaths = @(
        (Join-Path $root ".cursor\mcp.json")
        (Join-Path $env:USERPROFILE ".cursor\mcp.json")
    ) | Where-Object { Test-Path $_ }
}

# Storage map (sizes in MB)
$cachePaths = [ordered]@{
    githubRoot       = "C:\GitHub"
    bunCache         = Join-Path $env:USERPROFILE ".bun"
    npmCache         = Join-Path $env:APPDATA "npm-cache"
    ollamaModels     = Join-Path $env:USERPROFILE ".ollama\models"
    dockerData       = Join-Path $env:LOCALAPPDATA "Docker"
    cursorAppData    = Join-Path $env:APPDATA "Cursor"
    lanceDb          = Join-Path $root "state\memory\octo-cluster\vector\lancedb"
    contextEngine    = Join-Path $root "engine\context-engine\node_modules"
}

$inv.storage = [ordered]@{}
foreach ($key in $cachePaths.Keys) {
    $p = $cachePaths[$key]
    $bytes = Get-DirSizeBytes -Path $p
    $inv.storage[$key] = [ordered]@{
        path   = $p
        exists = (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue)
        sizeMb = if ($null -ne $bytes) { [math]::Round($bytes / 1MB, 1) } else { $null }
    }
}

# Startup apps (registry Run keys, names only)
$startup = @()
foreach ($hive in @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)) {
    if (Test-Path $hive) {
        Get-ItemProperty $hive -ErrorAction SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $startup += [ordered]@{ key = $hive; name = $_.Name; command = ($_.Value -replace 'password=\S+', 'password=[REDACTED]') }
            }
        }
    }
}
$inv.startupApps = $startup

# Output
$logDir = Join-Path $root "state\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not $OutFile) {
    $OutFile = Join-Path $logDir "workstation-inventory-$dateTag.json"
}

$jsonOut = $inv | ConvertTo-Json -Depth 8
Set-Content -Path $OutFile -Value $jsonOut -Encoding UTF8

if ($Json) {
    Write-Output $jsonOut
} else {
    Write-Host "== workstation inventory (8CL-159) ==" -ForegroundColor Cyan
    Write-Host "CPU:    $($inv.hardware.cpu.name)" -ForegroundColor Gray
    Write-Host "RAM:    $($inv.hardware.memory.totalGb) GB" -ForegroundColor Gray
    Write-Host "OS:     $($inv.os.caption) build $($inv.os.build)" -ForegroundColor Gray
    Write-Host "Output: $OutFile" -ForegroundColor Green
}

exit 0
