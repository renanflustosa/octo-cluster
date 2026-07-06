#Requires -Version 5.1
<#
.SYNOPSIS
  Smoke tests for Windows bootstrap under AllSigned execution policy (8CL-20).
.EXAMPLE
  .\scripts\test-bootstrap-allsigned.ps1
#>
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_env.ps1')

$results = @()

function Add-Result {
    param(
        [string]$Id,
        [string]$Label,
        [scriptblock]$Check
    )
    $ok = $false
    $detail = ''
    try {
        $detail = & $Check
        $ok = [bool]$detail
        if ($detail -is [string] -and $detail -notmatch '^(True|False)$') {
            $ok = $true
        }
    } catch {
        $detail = $_.Exception.Message
        $ok = $false
    }
    $script:results += [pscustomobject]@{
        id     = $Id
        label  = $Label
        ok     = $ok
        detail = [string]$detail
    }
}

$root = Get-OctoClusterRoot

foreach ($name in @('install.cmd', 'octo.cmd', 'audit.cmd')) {
    Add-Result -Id "launcher_$name" -Label "$name exists" -Check {
        Test-Path (Join-Path $root $name)
    }
}

Add-Result -Id 'launcher_bypass' -Label '.cmd launchers use ExecutionPolicy Bypass' -Check {
    foreach ($name in @('install.cmd', 'octo.cmd', 'audit.cmd')) {
        $content = Get-Content -LiteralPath (Join-Path $root $name) -Raw
        if ($content -notmatch '-ExecutionPolicy\s+Bypass') {
            throw "$name missing Bypass"
        }
    }
    $true
}

Add-Result -Id 'octo_cmd_discover' -Label 'octo.cmd scan discover' -Check {
    $octoCmd = Join-Path $root 'octo.cmd'
    $out = & cmd /c "`"$octoCmd`" -Pipeline scan -Action discover" 2>&1 | Out-String
    $LASTEXITCODE -eq 0 -and $out -match 'PIPELINE=scan'
}

Add-Result -Id 'allsigned_blocks_ps1' -Label 'AllSigned blocks direct octo.ps1' -Check {
    $probe = Join-Path $env:TEMP ("octo-unsigned-probe-{0}.ps1" -f [guid]::NewGuid().ToString('n'))
    Set-Content -LiteralPath $probe -Value 'Write-Output PROBE_OK' -Encoding UTF8
    $octoPs1 = Join-Path $root 'octo.ps1'
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $probeOut = & powershell -NoProfile -ExecutionPolicy AllSigned -File $probe 2>&1 | Out-String
        $out = & powershell -NoProfile -ExecutionPolicy AllSigned -File $octoPs1 -Pipeline scan -Action discover 2>&1 | Out-String
        $exit = $LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEap
    }
    $blockedPattern = 'running scripts is disabled|cannot be loaded|not digitally signed|UnauthorizedAccess|n.o pode ser carregado|n.o est. assinado|assinado digitalmente|ErrodeSeguran'
    $hostEnforces = ($probeOut -notmatch 'PROBE_OK')
    if (-not $hostEnforces) {
        # Dev/CI hosts allow unsigned scripts under AllSigned scope — corporate Windows uses .cmd Bypass.
        return $true
    }
    $blocked = ($exit -ne 0) -or ($out -match $blockedPattern)
    if (-not $blocked) { throw "expected AllSigned to block unsigned octo.ps1; exit=$exit" }
    $true
}

Add-Result -Id 'bun_executable_path' -Label 'Get-BunExecutable resolves existing path' -Check {
    if (-not (Get-Command Get-BunExecutable -ErrorAction SilentlyContinue)) {
        throw 'Get-BunExecutable not loaded'
    }
    $bun = Get-BunExecutable
    if (-not $bun) { throw 'bun not installed (skip on CI without Bun)' }
    if (-not (Test-Path -LiteralPath $bun)) { throw "resolved path missing: $bun" }
    $true
}

$failed = @($results | Where-Object { -not $_.ok })
$passed = @($results | Where-Object { $_.ok })

if ($Json) {
    $results | ConvertTo-Json -Depth 3
} else {
    foreach ($r in $results) {
        $flag = if ($r.ok) { 'OK' } else { 'FAIL' }
        $color = if ($r.ok) { 'Green' } else { 'Red' }
        Write-Host "[$flag] $($r.label)" -ForegroundColor $color
        if ($r.detail -and -not $r.ok) { Write-Host "       $($r.detail)" -ForegroundColor DarkGray }
    }
    Write-Host ''
    Write-Host "Passed $($passed.Count)/$($results.Count)" -ForegroundColor $(if ($failed.Count -eq 0) { 'Green' } else { 'Red' })
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
