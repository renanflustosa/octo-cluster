# Resolve Cursor session token — vscdb auto, local SESSION.json fallback, env override.
param(
    [switch]$Json,
    [switch]$Redact
)

$ErrorActionPreference = 'Stop'
$pyScript = Join-Path $PSScriptRoot 'cursor_session.py'
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw 'python required for cursor-session' }

$argsList = @($pyScript)
if ($Json -or $Redact) { $argsList += '--json' }
if ($Redact) { $argsList += '--redact' }

$output = & $python.Source @argsList 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($Json) {
        Write-Output '{"ok":false,"source":"none"}'
        exit 1
    }
    throw "Cursor session token not found. Set CURSOR_SESSION_TOKEN or a local gitignored SESSION.json."
}

if ($Json -or $Redact) {
    Write-Output $output
} else {
    Write-Output ($output | Select-Object -Last 1)
}
exit 0
