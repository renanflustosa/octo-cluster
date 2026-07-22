#Requires -Version 5.1
<#
.SYNOPSIS
  Direct-push ship: boundary gate -> commit -> push. Win11 + Cursor, solo workflow.
.EXAMPLE
  pwsh -File scripts/ship.ps1 -CommitMessage "fix: short summary"
  pwsh -File scripts/ship.ps1 -WhatIf
#>
param(
    [string]$CommitMessage,
    [string]$Branch = 'main',
    [switch]$SkipPush,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { throw '[ship] not inside a git repository.' }
Set-Location $root

$dirty = git status --porcelain
if (-not $dirty) {
    Write-Host '[ship] nothing to commit - clean tree.' -ForegroundColor Yellow
    exit 0
}

if ($WhatIf) {
    Write-Host "[ship] WhatIf: would commit and push to origin/$Branch" -ForegroundColor Cyan
    git status --short
    exit 0
}

if (-not $CommitMessage) { throw '[ship] -CommitMessage is required.' }

$current = (git branch --show-current).Trim()
if ($current -ne $Branch) {
    throw "[ship] on branch '$current', expected '$Branch'. Checkout $Branch or pass -Branch."
}

git add -A

# Boundary gate (public repo): block consumer identifiers in the staged change.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'boundary-audit.ps1') -Staged
if ($LASTEXITCODE -ne 0) { throw '[ship] boundary-audit failed - fix before shipping.' }

git commit -m $CommitMessage
if ($LASTEXITCODE -ne 0) { throw '[ship] commit failed.' }

if ($SkipPush) {
    Write-Host '[ship] committed - skip push (-SkipPush).' -ForegroundColor Yellow
    exit 0
}

git push origin $Branch
if ($LASTEXITCODE -ne 0) { throw '[ship] push failed.' }
Write-Host "[ship] pushed to origin/$Branch." -ForegroundColor Green
exit 0
