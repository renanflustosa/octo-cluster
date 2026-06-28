# Run repository-policy verify commands (verification phase provider).
param([string]$RepoPath)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\..\scripts\_load-env.ps1')
. (Join-Path (Get-CoreScriptsRoot) 'get-repo-policy.ps1')

if (-not $RepoPath) {
    $RepoPath = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Not inside a git repository." }
}
$RepoPath = (Resolve-Path $RepoPath).Path

$policy = Get-RepoPolicy -RepoPath $RepoPath
$commands = Get-RepoVerifyCommands -Policy $policy

if ($commands.Count -eq 0) {
    Write-Host "[repo-verify] no verify commands configured - skip" -ForegroundColor DarkGray
    exit 0
}

Write-Host "== repo-policy-verify ($($commands.Count) command(s)) ==" -ForegroundColor Cyan
$failed = @()

foreach ($cmd in $commands) {
    $id = [string]$cmd.id
    $run = [string]$cmd.run
    if (-not $run) { continue }

    $cwd = $RepoPath
    if ($cmd.cwd) {
        $rel = [string]$cmd.cwd
        if ([System.IO.Path]::IsPathRooted($rel)) {
            $cwd = $rel
        } else {
            $cwd = Join-Path $RepoPath ($rel -replace '/', '\')
        }
    }

    Write-Host ">> verify: $id (cwd=$cwd)" -ForegroundColor DarkGray
    Push-Location $cwd
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        if ($run.TrimStart().StartsWith('powershell')) {
            Invoke-Expression $run *>$null
            $code = $LASTEXITCODE
            if ($code -eq 0) { Write-Host "[ok] verify '$id'" -ForegroundColor Green }
            else { throw "exit $code" }
        } elseif ($run.TrimStart().StartsWith('bun ')) {
            $bun = $null
            if (Get-Command Get-BunExecutable -ErrorAction SilentlyContinue) { $bun = Get-BunExecutable }
            if (-not $bun) { $bun = (Get-Command bun -ErrorAction SilentlyContinue).Source }
            if (-not $bun) { throw "Bun executable not found" }
            $bunArgs = $run.Substring(4).Trim() -split '\s+'
            & $bun @bunArgs *>$null
            $code = $LASTEXITCODE
            if ($null -eq $code) { $code = 0 }
            if ($code -ne 0) { throw "exit $code" }
            Write-Host "[ok] verify '$id'" -ForegroundColor Green
        } else {
            Invoke-Expression $run *>$null
            $code = $LASTEXITCODE
            if ($null -eq $code) { $code = 0 }
            if ($code -ne 0) { throw "exit $code" }
            Write-Host "[ok] verify '$id'" -ForegroundColor Green
        }
        $ErrorActionPreference = $prevEap
    } catch {
        $ErrorActionPreference = $prevEap
        if ($cmd.optional) {
            Write-Host "[warn] optional verify '$id' failed: $($_.Exception.Message)" -ForegroundColor Yellow
            continue
        }
        $failed += $id
        Write-Host "[fail] verify '$id': $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

if ($failed.Count -gt 0) {
    Write-Host "[BLOCKED] repo verify failed: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "[ok] repo-policy-verify passed" -ForegroundColor Green
exit 0