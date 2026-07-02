#Requires -Version 5.1
# COST 0 productivity harness audit (8CL-158 F6).
# Usage: .\scripts\productivity-audit.ps1 [-Json] [-Workstation]

param(
    [switch]$Json,
    [switch]$Workstation
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "_load-env.ps1")
. (Join-Path $PSScriptRoot "install-prerequisites.ps1")

function Test-Tool {
    param(
        [string]$Id,
        [string]$Label,
        [scriptblock]$Check,
        [string]$InstallHint = ""
    )
    try {
        $ok = & $Check
        if ($ok) {
            return [ordered]@{ id = $Id; label = $Label; status = "OK"; hint = $InstallHint }
        }
        return [ordered]@{ id = $Id; label = $Label; status = "MISSING"; hint = $InstallHint }
    } catch {
        return [ordered]@{ id = $Id; label = $Label; status = "WARN"; hint = $InstallHint; detail = $_.Exception.Message }
    }
}

$root = Get-OctoClusterRoot
$results = @()

$effectivePolicy = Get-ExecutionPolicy
$userPolicy = Get-ExecutionPolicy -Scope CurrentUser
$machinePolicy = Get-ExecutionPolicy -Scope LocalMachine
if ($effectivePolicy -in @('AllSigned', 'Restricted') -or
    $userPolicy -in @('AllSigned', 'Restricted') -or
    $machinePolicy -in @('AllSigned', 'Restricted')) {
    $results += [ordered]@{
        id     = 'execution_policy'
        label  = 'PowerShell execution policy'
        status = 'WARN'
        hint   = 'Use .\install.cmd / .\octo.cmd / .\audit.cmd (Bypass) — see docs/guides/onboarding.md#corporate-windows'
    }
}

$results += @(
    (Test-Tool -Id "git" -Label "Git" -InstallHint "https://git-scm.com" -Check {
        $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    })
    (Test-Tool -Id "gh" -Label "GitHub CLI" -InstallHint ".\install.ps1" -Check {
        if (Get-Command Get-GhExecutable -ErrorAction SilentlyContinue) { return [bool](Get-GhExecutable) }
        $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    })
    (Test-Tool -Id "bun" -Label "Bun" -InstallHint "irm bun.sh/install.ps1 | iex" -Check {
        if (Get-Command Get-BunExecutable -ErrorAction SilentlyContinue) {
            return [bool](Get-BunExecutable)
        }
        $bunPath = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
        return (Test-Path $bunPath) -or ($null -ne (Get-Command bun -ErrorAction SilentlyContinue))
    })
    (Test-Tool -Id "node" -Label "Node.js (optional)" -InstallHint "https://nodejs.org" -Check {
        if ($null -eq (Get-Command node -ErrorAction SilentlyContinue)) { throw "missing" }
        $true
    })
    (Test-Tool -Id "rg" -Label "ripgrep" -InstallHint ".\install.ps1 (direct zip)" -Check {
        if ($null -eq (Get-Command rg -ErrorAction SilentlyContinue)) { throw "missing" }
        $true
    })
    (Test-Tool -Id "context_engine" -Label "LanceDB context-engine" -InstallHint ".\install.ps1" -Check {
        Test-Path (Join-Path $root "engine\context-engine\node_modules\@lancedb\lancedb")
    })
    (Test-Tool -Id "memory_index" -Label "Memory vector index" -InstallHint "bun run index-incremental octo-cluster --kind memory" -Check {
        Test-Path (Join-Path $root "state\memory\octo-cluster\vector\lancedb")
    })
    (Test-Tool -Id "platform_context" -Label "Platform execution context" -InstallHint "contexts/platform.json" -Check {
        Test-Path (Join-Path $root "contexts\platform.json")
    })
)

# gh auth (WARN if missing)
$ghEntry = $results | Where-Object { $_.id -eq "gh" } | Select-Object -First 1
if ($ghEntry.status -eq "OK") {
    cmd /c "gh auth status >nul 2>nul"
    if ($LASTEXITCODE -ne 0) {
        $results += [ordered]@{ id = "gh_auth"; label = "gh auth"; status = "WARN"; hint = "gh auth login" }
    } else {
        $results += [ordered]@{ id = "gh_auth"; label = "gh auth"; status = "OK"; hint = "" }
    }
}

$validateHooks = Join-Path $root "scripts\validate-cursor-hooks.ps1"
if (Test-Path $validateHooks) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validateHooks 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $results += [ordered]@{ id = "cursor_hooks"; label = "Cursor hooks JSON"; status = "MISSING"; hint = ".\scripts\sync-cursor.ps1" }
    } else {
        $results += [ordered]@{ id = "cursor_hooks"; label = "Cursor hooks JSON"; status = "OK"; hint = "" }
    }
}

if ($Workstation) {
    $results += (Test-Tool -Id "OCTO_CLUSTER_env" -Label "OCTO_CLUSTER env" -InstallHint "Set OCTO_CLUSTER to your clone root" -Check {
        $v = [Environment]::GetEnvironmentVariable("OCTO_CLUSTER", "User")
        if (-not $v) { $v = $env:OCTO_CLUSTER }
        $v -and (Test-Path $v)
    })
    $results += (Test-Tool -Id "ai_execution_context" -Label "AI_EXECUTION_CONTEXT" -InstallHint "User env var platform" -Check {
        $v = [Environment]::GetEnvironmentVariable("AI_EXECUTION_CONTEXT", "User")
        if (-not $v) { $v = $env:AI_EXECUTION_CONTEXT }
        $v -eq "platform"
    })
    $invScript = Join-Path $root "scripts\workstation-inventory.ps1"
    $results += (Test-Tool -Id "workstation_inventory" -Label "workstation-inventory.ps1" -InstallHint "8CL-159 harness" -Check {
        Test-Path $invScript
    })
    $benchScript = Join-Path $root "scripts\workstation-benchmark.ps1"
    $results += (Test-Tool -Id "workstation_benchmark" -Label "workstation-benchmark.ps1" -InstallHint "8CL-159 harness" -Check {
        Test-Path $benchScript
    })
    $results += (Test-Tool -Id "power_plan" -Label "Power plan (high perf)" -InstallHint "powercfg /setactive high performance" -Check {
        $active = powercfg /getactivescheme 2>&1 | Out-String
        $active -match "Alto desempenho|High performance|desempenho máximo|Ultimate"
    })
    try {
        $ollamaOk = $false
        if (Get-Command Get-OllamaExecutable -ErrorAction SilentlyContinue) {
            $ollamaOk = [bool](Get-OllamaExecutable)
        } else {
            $ollamaOk = $null -ne (Get-Command ollama -ErrorAction SilentlyContinue)
        }
        if ($ollamaOk) {
            $results += [ordered]@{ id = "ollama"; label = "Ollama (optional)"; status = "OK"; hint = "" }
        } else {
            $results += [ordered]@{ id = "ollama"; label = "Ollama (optional)"; status = "WARN"; hint = ".\scripts\install-ollama.ps1" }
        }
    } catch {
        $results += [ordered]@{ id = "ollama"; label = "Ollama (optional)"; status = "WARN"; hint = ".\scripts\install-ollama.ps1" }
    }
    try {
        $list = (wsl -l -q 2>$null | Out-String) -replace "`0", ""
        if ($list -match "Ubuntu") {
            $results += [ordered]@{ id = "wsl"; label = "WSL2 Ubuntu (optional)"; status = "OK"; hint = "" }
        } else {
            $results += [ordered]@{ id = "wsl"; label = "WSL2 Ubuntu (optional)"; status = "WARN"; hint = ".\scripts\install-wsl.ps1" }
        }
    } catch {
        $results += [ordered]@{ id = "wsl"; label = "WSL2 Ubuntu (optional)"; status = "WARN"; hint = ".\scripts\install-wsl.ps1" }
    }
    try {
        $dockerCli = Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\resources\bin\docker.exe"
        if (-not (Test-Path $dockerCli)) {
            $dockerCli = Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe"
        }
        if (Test-Path $dockerCli) {
            $results += [ordered]@{ id = "docker"; label = "Docker (optional)"; status = "OK"; hint = "" }
        } else {
            $results += [ordered]@{ id = "docker"; label = "Docker (optional)"; status = "WARN"; hint = ".\scripts\install-docker.ps1" }
        }
    } catch {
        $results += [ordered]@{ id = "docker"; label = "Docker (optional)"; status = "WARN"; hint = ".\scripts\install-docker.ps1" }
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host "== productivity audit (COST 0) ==" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = switch ($r.status) { "OK" { "Green" } "WARN" { "Yellow" } default { "Red" } }
    $line = "{0,-20} {1}" -f $r.label, $r.status
    if ($r.hint -and $r.status -ne "OK") { $line += " -> $($r.hint)" }
    Write-Host $line -ForegroundColor $color
}

$bad = @($results | Where-Object { $_.status -eq "MISSING" })
if ($bad.Count -gt 0) {
    Write-Host "[NEEDS FIXES] $($bad.Count) required tool(s) missing" -ForegroundColor Red
    exit 1
}
Write-Host "[READY] productivity harness OK" -ForegroundColor Green
exit 0