# PowerShell wrapper for engine/metrics/metrics_db.py (Octo Cluster metrics kernel).
param(
    [ValidateSet('init', 'insert-card', 'insert-harness', 'migrate-csv', 'trends')]
    [string]$StoreAction,

    [string]$JsonPayload = '',
    [int]$Last = 10,
    [string]$Arm = 'all',
    [string]$DbPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')

$root = Get-OctoClusterRoot
$pyScript = Join-Path $PSScriptRoot 'metrics_db.py'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw 'python not found — required for metrics store' }

$argsList = @($pyScript, $StoreAction)
if ($DbPath) { $argsList = @($pyScript, '--db', $DbPath, $StoreAction) }

switch ($StoreAction) {
    'insert-card' {
        if (-not $JsonPayload) { throw 'insert-card requires -JsonPayload' }
        $argsList += @('--json', $JsonPayload)
    }
    'insert-harness' {
        if (-not $JsonPayload) { throw 'insert-harness requires -JsonPayload' }
        $argsList += @('--json', $JsonPayload)
    }
    'migrate-csv' {
        $argsList += @('--workspace', $root)
    }
    'trends' {
        $argsList += @('--last', [string]$Last, '--arm', $Arm)
    }
}

& $python.Source @argsList
exit $LASTEXITCODE
