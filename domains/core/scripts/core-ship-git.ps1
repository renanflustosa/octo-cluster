# Repository-policy git delivery for /ship (direct | feature-branch).
# Usage: core-ship-git.ps1 -RepoPath "$env:OCTO_CLUSTER" -CommitMessage "feat: ..."
#        core-ship-git.ps1 -FeatureBranch "feat/my-change" -WhatIf

param(
    [string]$RepoPath,
    [string]$CommitMessage,
    [string]$FeatureBranch,
    [string]$PrTitle,
    [string]$PrBodyFile,
    [switch]$SkipCommit,
    [switch]$SkipPush,
    [switch]$SkipPullRequest,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'get-repo-policy.ps1')

function Get-ProtectedBranches {
    param([hashtable]$GitPolicy)

    $raw = $GitPolicy.protected_branches
    if ($raw) {
        return @([string]$raw -split '[,\s]+' | Where-Object { $_ })
    }

    $branches = New-Object System.Collections.ArrayList
    foreach ($key in @('base_branch', 'target_branch')) {
        $name = [string]$GitPolicy[$key]
        if ($name -and ($branches -notcontains $name)) { [void]$branches.Add($name) }
    }
    return @($branches)
}

function Assert-NotProtectedBranch {
    param(
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy,
        [string]$Hint = 'Checkout a feature branch or pass -FeatureBranch.'
    )

    $protected = Get-ProtectedBranches -GitPolicy $GitPolicy
    if ($protected -contains $Branch) {
        throw "[ship-git] branch '$Branch' is protected ($($protected -join ', ')). $Hint"
    }
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    Write-Host "git $($Args -join ' ')" -ForegroundColor DarkGray
    if ($WhatIf) { return "" }
    # Git writes progress to stderr; do not treat that as failure under $ErrorActionPreference Stop.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = git @Args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git $($Args -join ' ') failed: $out"
        }
        return $out
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Test-GitDirty {
    $status = Invoke-Git @('status', '--porcelain')
    if (-not $status) {
        Write-Host "`[ship-git] nothing to commit" -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Ensure-Commit {
    param(
        [string]$Message,
        [switch]$Skip
    )
    if ($Skip) {
        Write-Host '`[ship-git] skip commit' -ForegroundColor Yellow
        return
    }
    if (-not $Message) {
        throw "CommitMessage is required unless -SkipCommit is set."
    }
    Invoke-Git @('add', '-A') | Out-Null
    $pending = Invoke-Git @('status', '--porcelain')
    if (-not $pending) {
        Write-Host "`[ship-git] working tree clean after add - skip commit" -ForegroundColor Yellow
        return
    }
    Invoke-Git @('commit', '-m', $Message) | Out-Null
}

function Sync-BaseBranch {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )
    Invoke-Git @('fetch', 'origin') | Out-Null
    Invoke-Git @('checkout', $BaseBranch) | Out-Null
    Invoke-Git @('pull', '--ff-only', 'origin', $BaseBranch) | Out-Null
}

function Rebase-OntoRemoteBase {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )
    Invoke-Git @('fetch', 'origin') | Out-Null
    $localBase = (Invoke-Git @('rev-parse', "origin/$BaseBranch")).Trim()
    $mergeBase = (Invoke-Git @('merge-base', 'HEAD', "origin/$BaseBranch")).Trim()
    if ($localBase -ne $mergeBase) {
        Write-Host "`[ship-git] origin/$BaseBranch advanced - rebasing" -ForegroundColor Cyan
        Invoke-Git @('rebase', "origin/$BaseBranch") | Out-Null
        return $true
    }
    Write-Host "`[ship-git] origin/$BaseBranch unchanged - skip rebase" -ForegroundColor DarkGray
    return $false
}

function Get-ExistingPullRequestUrl {
    param(
        [Parameter(Mandatory = $true)][string]$HeadBranch,
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )
    if ($WhatIf) { return $null }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = gh pr list --head $HeadBranch --base $BaseBranch --json url --jq '.[0].url' 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        $url = ($out | Out-String).Trim()
        if ($url -and $url -ne 'null') { return $url }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return $null
}

function New-PullRequest {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [string]$Title,
        [string]$BodyFile
    )
    if ($SkipPullRequest) {
        Write-Host '`[ship-git] skip pull request' -ForegroundColor Yellow
        return $null
    }
    $head = (Invoke-Git @('branch', '--show-current')).Trim()
    $existing = Get-ExistingPullRequestUrl -HeadBranch $head -BaseBranch $BaseBranch
    if ($existing) {
        Write-Host "`[ship-git] PR already exists: $existing" -ForegroundColor Green
        return $existing
    }
    $args = @('pr', 'create', '--base', $BaseBranch)
    if ($Title) { $args += @('--title', $Title) }
    if ($BodyFile) {
        if (-not (Test-Path $BodyFile)) { throw "PR body file not found: $BodyFile" }
        $args += @('--body-file', $BodyFile)
    } else {
        $args += '--fill'
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = gh @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "gh pr create failed: $out"
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Write-Host $out -ForegroundColor Green
    return ($out | Select-Object -Last 1)
}

function Invoke-DirectStrategy {
    param(
        [hashtable]$GitPolicy,
        [string]$Message
    )

    $target = [string]$GitPolicy.target_branch
    if (-not $target) { $target = 'main' }

    Assert-NotProtectedBranch -Branch $target -GitPolicy $GitPolicy -Hint 'Use git.strategy feature-branch with pull_request instead of direct push.'

    $current = (Invoke-Git @('branch', '--show-current')).Trim()
    if ($current -ne $target) {
        Write-Host "`[ship-git] checkout $target" -ForegroundColor Cyan
        Invoke-Git @('checkout', $target) | Out-Null
    }

    Ensure-Commit -Message $Message -Skip:$SkipCommit

    if (-not $SkipPush) {
        Invoke-Git @('push', 'origin', $target) | Out-Null
        Write-Host "`[ship-git] pushed to origin/$target" -ForegroundColor Green
    }

    return [ordered]@{
        strategy = 'direct'
        branch   = $target
        pr_url   = $null
    }
}

function Invoke-FeatureBranchStrategy {
    param(
        [hashtable]$GitPolicy,
        [string]$Message,
        [string]$BranchName
    )

    $base = [string]$GitPolicy.base_branch
    if (-not $base) { throw "feature-branch policy requires git.base_branch" }

    if (-not $BranchName) {
        $BranchName = (Invoke-Git @('branch', '--show-current')).Trim()
        if ($BranchName -eq $base -or -not $BranchName) {
            throw "FeatureBranch is required when current branch is the base branch."
        }
    }

    Assert-NotProtectedBranch -Branch $BranchName -GitPolicy $GitPolicy

    $current = (Invoke-Git @('branch', '--show-current')).Trim()
    if ($current -ne $BranchName) {
        if ($WhatIf) {
            Write-Host "`[ship-git] would checkout/create branch $BranchName" -ForegroundColor Cyan
        } else {
            $exists = git show-ref --verify --quiet "refs/heads/$BranchName"; $code = $LASTEXITCODE
            if ($code -eq 0) {
                Invoke-Git @('checkout', $BranchName) | Out-Null
            } else {
                Invoke-Git @('checkout', '-b', $BranchName) | Out-Null
            }
        }
    }

    Ensure-Commit -Message $Message -Skip:$SkipCommit

    Invoke-Git @('fetch', 'origin') | Out-Null
    $rebased = $false
    if ($GitPolicy.sync_remote_before_pr) {
        $rebased = Rebase-OntoRemoteBase -BaseBranch $base
    }

    if (-not $SkipPush) {
        Invoke-Git @('push', '-u', 'origin', $BranchName) | Out-Null
        Write-Host "`[ship-git] pushed origin/$BranchName" -ForegroundColor Green
    }

    $prUrl = $null
    if ($GitPolicy.pull_request) {
        $prUrl = New-PullRequest -BaseBranch $base -Title $PrTitle -BodyFile $PrBodyFile
    }

    return [ordered]@{
        strategy          = 'feature-branch'
        branch            = $BranchName
        base_branch       = $base
        rebased           = $rebased
        revalidate_needed = [bool]$GitPolicy.revalidate_after_rebase -and $rebased
        pr_url            = $prUrl
    }
}

if (-not $RepoPath) {
    $RepoPath = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $RepoPath) {
        throw "RepoPath not provided and not inside a git repository."
    }
}

$RepoPath = (Resolve-Path $RepoPath).Path
Push-Location $RepoPath
try {
    $policy = Get-RepoPolicy -RepoPath $RepoPath
    $gitPolicy = $policy.git

    if (-not (Test-GitDirty) -and -not $SkipCommit) {
        if (-not $CommitMessage) {
            $branch = (Invoke-Git @('branch', '--show-current')).Trim()
            Write-Host "`[ship-git] clean working tree - no-op success" -ForegroundColor Green
            @{
                strategy = [string]$gitPolicy.strategy
                branch   = $branch
                noop     = $true
            } | ConvertTo-Json -Compress
            exit 0
        }
        Write-Host "`[ship-git] clean working tree - skip commit, continue delivery" -ForegroundColor Yellow
        $SkipCommit = $true
    }

    switch ([string]$gitPolicy.strategy) {
        'direct' {
            $result = Invoke-DirectStrategy -GitPolicy $gitPolicy -Message $CommitMessage
        }
        'feature-branch' {
            $result = Invoke-FeatureBranchStrategy -GitPolicy $gitPolicy -Message $CommitMessage -BranchName $FeatureBranch
        }
        default {
            throw "Unsupported git.strategy '$($gitPolicy.strategy)' in repo policy."
        }
    }

    $result | ConvertTo-Json -Compress
    exit 0
} finally {
    Pop-Location
}
