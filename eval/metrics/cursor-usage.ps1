# Cursor dashboard usage API — delta events since timestamp (ms).
param(
    [long]$SinceMs = 0,
    [switch]$SummaryOnly,
    [string]$Token = ''
)

$ErrorActionPreference = 'Stop'
$pyScript = Join-Path $PSScriptRoot 'cursor_usage.py'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw 'python required for cursor-usage' }

$argsList = @($pyScript)
if ($SinceMs -gt 0) { $argsList += @('--since-ms', [string]$SinceMs) }
if ($SummaryOnly) { $argsList += '--summary-only' }
if ($Token) { $argsList += @('--token', $Token) }

$output = & $python.Source @argsList 2>&1 | Out-String
Write-Output $output.Trim()
exit $LASTEXITCODE
