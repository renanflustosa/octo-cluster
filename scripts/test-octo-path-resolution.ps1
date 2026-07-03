#Requires -Version 5.1
<#
.SYNOPSIS
  Validates Octo Cluster path resolution across session, User env, and self-locating entry points.
.EXAMPLE
  .\scripts\test-octo-path-resolution.ps1
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

Add-Result -Id 'install_marker' -Label 'install.ps1 at resolved root' -Check {
    Test-Path (Join-Path $root 'install.ps1')
}

Add-Result -Id 'user_env' -Label 'User-level OCTO_CLUSTER' -Check {
    $user = [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User')
    (Test-OctoClusterRoot $user) -and ((Resolve-Path $user).Path -eq $root)
}

Add-Result -Id 'octo_ps1' -Label 'octo.ps1 entry exists' -Check {
    Test-Path (Join-Path $root 'octo.ps1')
}

Add-Result -Id 'self_locate_no_session' -Label 'Self-locate without session env' -Check {
    $saved = $env:OCTO_CLUSTER
    try {
        $env:OCTO_CLUSTER = $null
        $probe = Resolve-OctoClusterRoot -Preferred $null
        $probe -eq $root
    } finally {
        $env:OCTO_CLUSTER = $saved
    }
}

Add-Result -Id 'user_subexpression_invoke' -Label 'User env subexpression invokes octo.ps1' -Check {
    $user = [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User')
    if (-not (Test-OctoClusterRoot $user)) { return $false }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $user 'octo.ps1') -Pipeline scan -Action discover 2>&1 | Out-String
    $LASTEXITCODE -eq 0 -and $out -match 'PIPELINE=scan'
}

Add-Result -Id 'close_flat_ticket' -Label 'octo.ps1 close accepts flat -Ticket through -File' -Check {
    $user = [Environment]::GetEnvironmentVariable('OCTO_CLUSTER', 'User')
    if (-not (Test-OctoClusterRoot $user)) { return $false }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $user 'octo.ps1') -Pipeline close -Action run -Ticket 'OCTO-PATH-TEST' 2>&1 | Out-String
    # Binding succeeds if we reach core-close (archived or missing task file), not ScriptArgs transform error
    $LASTEXITCODE -eq 0 -and $out -notmatch 'ParameterArgumentTransformationError|Cannot convert the "System.Collections.Hashtable"'
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
    Write-Host ""
    Write-Host "Passed $($passed.Count)/$($results.Count)" -ForegroundColor $(if ($failed.Count -eq 0) { 'Green' } else { 'Red' })
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
