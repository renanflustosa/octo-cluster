# Optional Promptfoo eval gate (discovered provider).
param([switch]$SkipEval)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\..\scripts\_load-env.ps1')

if ($SkipEval) {
    Write-Host "`[promptfoo-eval] skipped" -ForegroundColor Yellow
    exit 0
}

$promptfooDir = Join-Path (Get-OctoClusterRoot) "eval\promptfoo"
$configFile = Join-Path $promptfooDir "promptfooconfig.yaml"
if (-not (Test-Path $configFile)) {
    Write-Host "`[promptfoo-eval] config missing - skip" -ForegroundColor Yellow
    exit 0
}

Write-Host "== promptfoo-eval ==" -ForegroundColor Cyan
Push-Location $promptfooDir
try {
    $ErrorActionPreference = "Continue"
    npx --yes promptfoo eval 2>&1 | Out-Host
    $evalCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($evalCode -ne 0) {
        Write-Host "`[BLOCKED] Promptfoo eval failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "`[ok] Promptfoo eval passed" -ForegroundColor Green
    exit 0
} finally {
    Pop-Location
}
