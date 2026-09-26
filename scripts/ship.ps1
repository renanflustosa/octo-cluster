#Requires -Version 5.1
<#
.SYNOPSIS
  Repo-agnostic delivery of commits already made: direct push to main, or branch + PR when main requires it.
.DESCRIPTION
  Never stages or commits: /ship creates the logical commits first. This script inspects (-WhatIf) or delivers
  origin/<Branch>..HEAD. It never stashes, resets, force-pushes or rebases.
.EXAMPLE
  pwsh -File scripts/ship.ps1 -WhatIf
  pwsh -File scripts/ship.ps1
  pwsh -File scripts/ship.ps1 -BranchName feature/x -PrTitle "feat: x" -PrBody $body
#>
param(
    [string]$Branch = 'main',
    [ValidateSet('auto', 'direct', 'pr')][string]$Mode = 'auto',
    [string]$BranchName,
    [string]$PrTitle,
    [string]$PrBody,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [switch]$PassThru,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($PassThru) {
        $out = (& git @GitArgs 2>&1 | ForEach-Object { "$_" })
    } else {
        & git @GitArgs 2>&1 | Out-Null
    }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($PassThru) { return @{ Output = $out; ExitCode = $code } }
    return $code
}

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

function Get-RemoteProtection {
    param([string]$Branch)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        return @{ State = 'unknown'; Reason = 'gh not installed' }
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $repo = (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $repo) { return @{ State = 'unknown'; Reason = 'gh repo view failed' } }
        $b = [uri]::EscapeDataString($Branch)
        # `protected` covers classic protection and rulesets, and needs only read access.
        $protected = (gh api "repos/$repo/branches/$b" --jq .protected 2>$null)
        if ($LASTEXITCODE -ne 0) { return @{ State = 'unknown'; Reason = "gh api branches/$Branch failed" } }
        if ("$protected".Trim() -ne 'true') { return @{ State = 'open'; Reason = "GitHub: $Branch not protected" } }

        $types = @(gh api "repos/$repo/rules/branches/$b" --jq '.[].type' 2>$null |
            ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Sort-Object -Unique)
        if ($LASTEXITCODE -eq 0 -and $types.Count -gt 0) {
            # These rules never block a fast-forward push of new commits.
            $blocking = @($types | Where-Object { $_ -notin @('deletion', 'non_fast_forward', 'creation') })
            if ($blocking.Count -eq 0) {
                return @{ State = 'open'; Reason = "GitHub rules allow direct push ($($types -join ', '))" }
            }
            return @{ State = 'protected'; Reason = "GitHub rules on ${Branch}: $($blocking -join ', ')" }
        }
        # Protected but no ruleset rules: classic branch protection.
        return @{ State = 'protected'; Reason = "GitHub branch protection on $Branch" }
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Get-ShipMode {
    param([string]$Root, [string]$Branch, [string]$Mode)
    if ($Mode -ne 'auto') { return @{ Mode = $Mode; Reasons = @("-Mode $Mode") } }

    $config = Read-ShipConfig -Root $Root
    if ($config.Mode -eq 'direct') { return @{ Mode = 'direct'; Reasons = @('config: mode=direct') } }
    if ($config.Mode -eq 'pr' -or $config.Protections) { return @{ Mode = 'pr'; Reasons = @('config: mode=pr') } }

    $remote = Get-RemoteProtection -Branch $Branch
    switch ($remote.State) {
        'protected' { return @{ Mode = 'pr'; Reasons = @($remote.Reason) } }
        'open' { return @{ Mode = 'direct'; Reasons = @($remote.Reason) } }
        default {
            return @{ Mode = 'direct'; Reasons = @("protection unknown ($($remote.Reason)): direct push is tried; a protection rejection falls back to PR") }
        }
    }
}

function Invoke-ShipGates {
    param([string]$Root)
    $audit = Join-Path $Root 'scripts/boundary-audit.ps1'
    if (-not (Test-Path $audit)) { return }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $audit
    if ($LASTEXITCODE -ne 0) { throw '[ship] boundary-audit failed - fix before shipping.' }
}

function Assert-PrArgs {
    param([string]$Branch, [string]$Current, [string]$BranchName, [string]$PrTitle, [string]$PrBody)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw '[ship] gh CLI required for PR delivery.' }
    if (-not $PrTitle -or -not $PrBody) { throw '[ship] PR delivery needs -PrTitle and -PrBody.' }
    if (-not $Current -or $Current -eq $Branch) {
        if (-not $BranchName) { throw "[ship] PR delivery from $Branch needs -BranchName (feature/..., fix/... or chore/...)." }
        if ($BranchName -cnotmatch '^(feature|fix|chore)/[a-z0-9][a-z0-9._-]*$') {
            throw "[ship] -BranchName '$BranchName' must match feature|fix|chore/<short-name>."
        }
    }
}

function Invoke-ShipPr {
    param([string]$Branch, [string]$Current, [string]$BranchName, [string]$PrTitle, [string]$PrBody)

    $head = $Current
    if (-not $Current -or $Current -eq $Branch) {
        # switch -c keeps the working tree; leftover uncommitted changes stay untouched.
        if ((Invoke-Git switch -c $BranchName) -ne 0) { throw "[ship] create branch $BranchName failed (already exists?)." }
        if ($Current -eq $Branch) {
            # The commits now live on $BranchName; local $Branch returns to the remote tip (ref move only).
            if ((Invoke-Git branch -f $Branch "origin/$Branch") -ne 0) { throw "[ship] reset local $Branch ref failed." }
        }
        $head = $BranchName
    } elseif ($BranchName -and $BranchName -ne $Current) {
        Write-Host "[ship] already on $Current - ignoring -BranchName $BranchName." -ForegroundColor Yellow
    }
    Write-Host "[ship] branch: $head" -ForegroundColor Cyan

    $push = Invoke-Git -PassThru push -u origin $head
    if ($push.ExitCode -ne 0) { $push.Output | Write-Host; throw "[ship] push of $head failed." }

    $prUrl = gh pr create --base $Branch --head $head --title $PrTitle --body $PrBody
    if ($LASTEXITCODE -ne 0) { throw "[ship] gh pr create failed (branch $head is pushed)." }
    Write-Host "[ship] PR opened: $prUrl" -ForegroundColor Green
}

function Invoke-ShipDirect {
    param([string]$Branch)
    $push = Invoke-Git -PassThru push origin "HEAD:refs/heads/$Branch"
    if ($push.ExitCode -eq 0) {
        $remote = ((Invoke-Git -PassThru ls-remote origin "refs/heads/$Branch").Output | Select-Object -First 1)
        $sha = ((Invoke-Git -PassThru rev-parse HEAD).Output | Select-Object -Last 1).Trim()
        if (-not "$remote".StartsWith($sha)) { throw "[ship] push reported success but origin/$Branch is not $sha." }
        Write-Host "[ship] pushed $sha to origin/$Branch." -ForegroundColor Green
        return 'pushed'
    }
    $text = $push.Output -join "`n"
    Write-Host $text
    if ($text -match 'GH006|GH013|protected branch|pull request|repository rule') { return 'protected' }
    throw "[ship] push to origin/$Branch failed."
}

$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { throw '[ship] not inside a git repository.' }
Set-Location $root

if ((Invoke-Git fetch --quiet origin $Branch) -ne 0) { throw "[ship] git fetch origin $Branch failed." }
$base = "origin/$Branch"
$current = ((Invoke-Git -PassThru branch --show-current).Output | Select-Object -Last 1)
$current = "$current".Trim()
$ahead = [int]((Invoke-Git -PassThru rev-list --count "$base..HEAD").Output | Select-Object -Last 1)
$behind = [int]((Invoke-Git -PassThru rev-list --count "HEAD..$base").Output | Select-Object -Last 1)
$shipMode = Get-ShipMode -Root $root -Branch $Branch -Mode $Mode
$reasons = ($shipMode.Reasons -join ', ')

if ($WhatIf) {
    $sym = (Invoke-Git -PassThru ls-remote --symref origin HEAD).Output | Where-Object { $_ -match '^ref: refs/heads/' } | Select-Object -First 1
    $default = if ("$sym" -match '^ref: refs/heads/(\S+)') { $Matches[1] } else { '(unknown)' }
    Write-Host "[ship] repo: $root"
    Write-Host "[ship] branch: $(if ($current) { $current } else { '(detached)' }) | vs ${base}: ahead $ahead, behind $behind | origin default: $default"
    Write-Host "[ship] mode=$($shipMode.Mode) ($reasons)" -ForegroundColor Cyan
    if ($ahead -gt 0) {
        Write-Host "[ship] commits already ahead of ${base}:"
        git log --oneline "$base..HEAD"
    }
    git status --short
    exit 0
}

if ((Invoke-Git -PassThru diff --cached --name-only).Output) {
    throw '[ship] staged changes are not committed - commit or unstage them first.'
}
if ($ahead -eq 0) {
    Write-Host "[ship] nothing to ship: HEAD has no commits beyond $base." -ForegroundColor Yellow
    exit 0
}
if ($behind -gt 0) {
    throw "[ship] HEAD is $behind commit(s) behind $base (behind or diverged) - integrate $base first; no automatic rebase."
}
$leftover = @((Invoke-Git -PassThru status --porcelain).Output | Where-Object { $_ })
if ($leftover.Count -gt 0) {
    Write-Host "[ship] $($leftover.Count) uncommitted path(s) stay local and are not shipped." -ForegroundColor Yellow
}

Write-Host "[ship] mode=$($shipMode.Mode) ($reasons); shipping $ahead commit(s)" -ForegroundColor Cyan
if ($shipMode.Mode -eq 'pr') {
    Assert-PrArgs -Branch $Branch -Current $current -BranchName $BranchName -PrTitle $PrTitle -PrBody $PrBody
}
Invoke-ShipGates -Root $root

if ($shipMode.Mode -eq 'direct') {
    if ((Invoke-ShipDirect -Branch $Branch) -eq 'pushed') { exit 0 }
    if (-not $PrTitle) {
        Write-Host "[ship] origin/$Branch rejected the direct push (protection). Re-run with -BranchName, -PrTitle and -PrBody." -ForegroundColor Yellow
        exit 3
    }
    Write-Host '[ship] direct push rejected by protection - falling back to PR.' -ForegroundColor Yellow
    Assert-PrArgs -Branch $Branch -Current $current -BranchName $BranchName -PrTitle $PrTitle -PrBody $PrBody
}

Invoke-ShipPr -Branch $Branch -Current $current -BranchName $BranchName -PrTitle $PrTitle -PrBody $PrBody
exit 0
