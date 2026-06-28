#Requires -Version 5.1
# Validate .cursor/hooks.json — every command hook returns valid JSON on stdout.
# Usage: .\scripts\validate-cursor-hooks.ps1 [-WorkspaceRoot path]

param([string]$WorkspaceRoot)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_load-env.ps1')

if ($WorkspaceRoot) {
    $env:OCTO_CLUSTER = (Resolve-Path $WorkspaceRoot).Path
}

$root = Get-OctoClusterRoot
$hooksJsonPath = Join-Path $root '.cursor\hooks.json'

if (-not (Test-Path $hooksJsonPath)) {
    Write-Host '[validate-hooks] no .cursor/hooks.json — skip' -ForegroundColor DarkGray
    exit 0
}

$config = Get-Content $hooksJsonPath -Raw | ConvertFrom-Json
$hookMap = $config.hooks
if (-not $hookMap) {
    Write-Host '[validate-hooks] hooks empty — OK' -ForegroundColor Green
    exit 0
}

$failures = New-Object System.Collections.ArrayList
$tested = 0

foreach ($eventName in @($hookMap.PSObject.Properties.Name)) {
    $entries = @($hookMap.$eventName)
    foreach ($entry in $entries) {
        if ($entry.type -eq 'prompt') { continue }
        $command = [string]$entry.command
        if (-not $command) { continue }

        if ($command -notmatch '\.ps1') {
            [void]$failures.Add("$eventName : command has no .ps1 script: $command")
            continue
        }

        if ($command -match '(-File\s+)([^\s]+\.ps1)') {
            $scriptRel = $Matches[2].Trim('"')
            $scriptPath = if ([System.IO.Path]::IsPathRooted($scriptRel)) {
                $scriptRel
            } else {
                Join-Path $root ($scriptRel -replace '/', '\')
            }
            if (-not (Test-Path $scriptPath)) {
                [void]$failures.Add("$eventName : missing script $scriptRel")
                continue
            }
        } else {
            [void]$failures.Add("$eventName : cannot parse script path from: $command")
            continue
        }

        $tested++
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $root
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Write('{}')
        $proc.StandardInput.Close()
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 2) {
            [void]$failures.Add("$eventName : $($entry.command) exit $($proc.ExitCode) stderr=$stderr")
            continue
        }

        $line = ($stdout -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if (-not $line) {
            [void]$failures.Add("$eventName : no stdout JSON from $scriptRel")
            continue
        }

        try {
            $parsed = $line | ConvertFrom-Json
            if (-not $parsed.permission) {
                [void]$failures.Add("$eventName : JSON missing permission field from $scriptRel")
            }
        } catch {
            [void]$failures.Add("$eventName : invalid JSON from $scriptRel : $line")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host '[validate-hooks] FAILED' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

Write-Host "[validate-hooks] OK ($tested hook script(s) tested)" -ForegroundColor Green
exit 0
