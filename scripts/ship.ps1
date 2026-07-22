#Requires -Version 5.1
<#
.SYNOPSIS
  Repo-agnostic ship: detect protections -> direct push to main OR temp branch + PR.
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

function Read-ShipConfig {
    param([string]$Root)
    $result = @{ Mode = $null; Protections = $false }

    $yaml = Join-Path $Root '.ship.yaml'
    if (Test-Path $yaml) {
        $text = Get-Content $yaml -Raw
        if ($text -match '(?m)^mode:\s*(direct|pr)\s*$') { $result.Mode = $Matches[1] }
        if ($text -match '(?m)^protections:\s*true\s*$') { $result.Protections = $true }
    }

    $jsonPath = Join-Path $Root '.ship.json'
    if (Test-Path $jsonPath) {
        $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
        if ($null -ne $j.mode) { $result.Mode = [string]$j.mode }
        if ($j.protections -eq $true) { $result.Protections = $true }
    }

    return $result
}

function Test-GitHookGate {
    param([string]$Root)
    foreach ($hook in @('.githooks/pre-commit', '.githooks/pre-push')) {
        $path = Join-Path $Root $hook
        if (-not (Test-Path $path)) { continue }
        $content = Get-Content $path -Raw -ErrorAction SilentlyContinue
        if ($content -match 'audit|gate|boundary') { return $true }
    }
    return $false
}

function Test-RemoteBranchProtection {
    param([string]$Branch)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
    try {
        $repo = gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
        if (-not $repo) { return $false }
        gh api "repos/$repo/branches/$([uri]::EscapeDataString($Branch))/protection" 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-ShipMode {
    param([string]$Root, [string]$Branch)

    $config = Read-ShipConfig -Root $Root
    if ($config.Mode -eq 'direct') {
        return @{ Mode = 'direct'; Reasons = @('config: mode=direct') }
    }
    if ($config.Mode -eq 'pr' -or $config.Protections) {
        return @{ Mode = 'pr'; Reasons = @('config') }
    }

    $reasons = @()
    if (Test-Path (Join-Path $Root 'scripts/boundary-audit.ps1')) {
        $reasons += 'scripts/boundary-audit.ps1'
    }
    if (Test-GitHookGate -Root $Root) {
        $reasons += 'git hooks (audit/gate)'
    }
    if (Test-RemoteBranchProtection -Branch $Branch) {
        $reasons += "remote branch protection on $Branch"
    }

    if ($reasons.Count -gt 0) {
        return @{ Mode = 'pr'; Reasons = $reasons }
    }
    return @{ Mode = 'direct'; Reasons = @('no protections detected') }
}

function Invoke-ShipGates {
    param([string]$Root)
    $audit = Join-Path $Root 'scripts/boundary-audit.ps1'
    if (-not (Test-Path $audit)) { return }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $audit -Staged
    if ($LASTEXITCODE -ne 0) { throw '[ship] boundary-audit failed - fix before shipping.' }
}

function Move-ToBaseBranch {
    param([string]$Branch)

    git fetch origin $Branch 2>$null | Out-Null
    $baseRef = "origin/$Branch"
    $null = git rev-parse --verify $baseRef 2>$null
    if ($LASTEXITCODE -ne 0) { $baseRef = $Branch }

    $current = (git branch --show-current).Trim()
    if ($current -eq $Branch) { return }

    $dirty = git status --porcelain
    $stashed = $false
    if ($dirty) {
        git stash push -u -m 'ship-auto-stash' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[ship] stash failed.' }
        $stashed = $true
    }

    git checkout $Branch 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git checkout -b $Branch $baseRef 2>$null | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "[ship] checkout $Branch failed." }

    if ($stashed) {
        git stash pop | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[ship] stash pop failed - resolve conflicts and re-run.' }
    }
}

function New-ShipTempBranch {
    param([string]$Branch)

    git fetch origin $Branch 2>$null | Out-Null
    $baseRef = "origin/$Branch"
    $null = git rev-parse --verify $baseRef 2>$null
    if ($LASTEXITCODE -ne 0) { $baseRef = $Branch }

    $tempBranch = "ship/$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $dirty = git status --porcelain
    $stashed = $false
    if ($dirty) {
        git stash push -u -m 'ship-auto-stash' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[ship] stash failed.' }
        $stashed = $true
    }

    git checkout -b $tempBranch $baseRef 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "[ship] create branch $tempBranch from $baseRef failed." }

    if ($stashed) {
        git stash pop | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[ship] stash pop failed - resolve conflicts and re-run.' }
    }

    return $tempBranch
}

function Invoke-ShipDirect {
    param(
        [string]$Root,
        [string]$Branch,
        [string]$CommitMessage,
        [switch]$SkipPush
    )

    Move-ToBaseBranch -Branch $Branch
    git add -A
    Invoke-ShipGates -Root $Root
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw '[ship] commit failed.' }

    if ($SkipPush) {
        Write-Host '[ship] committed - skip push (-SkipPush).' -ForegroundColor Yellow
        return
    }

    git push origin $Branch
    if ($LASTEXITCODE -ne 0) { throw '[ship] push failed.' }
    Write-Host "[ship] pushed to origin/$Branch." -ForegroundColor Green
}

function Invoke-ShipPr {
    param(
        [string]$Root,
        [string]$Branch,
        [string]$CommitMessage,
        [switch]$SkipPush
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw '[ship] gh CLI required for PR mode (protections detected). Install GitHub CLI or set mode: direct in .ship.yaml.'
    }

    $tempBranch = New-ShipTempBranch -Branch $Branch
    Write-Host "[ship] temp branch: $tempBranch" -ForegroundColor Cyan

    git add -A
    Invoke-ShipGates -Root $Root
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw '[ship] commit failed.' }

    if ($SkipPush) {
        Write-Host "[ship] committed on $tempBranch - skip push (-SkipPush)." -ForegroundColor Yellow
        return
    }

    git push -u origin $tempBranch
    if ($LASTEXITCODE -ne 0) { throw '[ship] push failed.' }

    $prBody = @"
## Ship via /ship (protections detected)

- [ ] Review changes
- [ ] CI green
"@
    $prUrl = gh pr create --base $Branch --head $tempBranch --title $CommitMessage --body $prBody
    if ($LASTEXITCODE -ne 0) { throw '[ship] gh pr create failed.' }
    Write-Host "[ship] PR opened: $prUrl" -ForegroundColor Green
}

$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { throw '[ship] not inside a git repository.' }
Set-Location $root

$dirty = git status --porcelain
if (-not $dirty) {
    Write-Host '[ship] nothing to commit - clean tree.' -ForegroundColor Yellow
    exit 0
}

$shipMode = Get-ShipMode -Root $root -Branch $Branch
$mode = $shipMode.Mode
$reasons = ($shipMode.Reasons -join ', ')

if ($WhatIf) {
    Write-Host "[ship] WhatIf: mode=$mode ($reasons)" -ForegroundColor Cyan
    if ($mode -eq 'direct') {
        Write-Host "[ship] WhatIf: checkout $Branch -> add -> gates -> commit -> push origin/$Branch"
    } else {
        Write-Host "[ship] WhatIf: temp branch ship/<timestamp> from $Branch -> add -> gates -> commit -> push -> gh pr create"
    }
    git status --short
    exit 0
}

if (-not $CommitMessage) { throw '[ship] -CommitMessage is required.' }

Write-Host "[ship] mode=$mode ($reasons)" -ForegroundColor Cyan

if ($mode -eq 'direct') {
    Invoke-ShipDirect -Root $root -Branch $Branch -CommitMessage $CommitMessage -SkipPush:$SkipPush
} else {
    Invoke-ShipPr -Root $root -Branch $Branch -CommitMessage $CommitMessage -SkipPush:$SkipPush
}

exit 0
