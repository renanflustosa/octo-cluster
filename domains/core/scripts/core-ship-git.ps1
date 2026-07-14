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
    [switch]$WaitForMerge,
    [switch]$CleanupMergedBranches,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
. (Join-Path $PSScriptRoot '..\..\..\scripts\enable-auto-merge.ps1')

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

function Invoke-ShipCommit {
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

function Assert-WorkingTreeCleanAfterCommit {
    param([switch]$Skip)
    if ($Skip -or $WhatIf) { return }
    $pending = Invoke-Git @('status', '--porcelain')
    if (-not $pending) { return }
    $paths = @($pending | ForEach-Object { ($_ -replace '^\S+\s+', '').Trim() })
    throw "[ship-git] uncommitted changes remain after commit (include in ship or stash before /ship):`n$($paths -join "`n")"
}

function Restore-CleanBaseBranch {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy
    )
    if ($WhatIf) {
        Write-Host "`[ship-git] WhatIf: would restore clean $BaseBranch" -ForegroundColor Yellow
        return
    }
    Write-Host "`[ship-git] returning to $BaseBranch" -ForegroundColor Cyan
    Invoke-Git @('checkout', $BaseBranch) | Out-Null
    Invoke-Git @('fetch', 'origin') | Out-Null
    Invoke-Git @('pull', '--ff-only', 'origin', $BaseBranch) | Out-Null
    $remaining = Invoke-Git @('status', '--porcelain')
    if ($remaining) {
        throw "[ship-git] base branch still dirty after restore:`n$remaining"
    }
}

function Get-BaseBranchFromPolicy {
    param([hashtable]$GitPolicy)
    $base = [string]$GitPolicy.base_branch
    if ($base) { return $base }
    $target = [string]$GitPolicy.target_branch
    if ($target) { return $target }
    return 'main'
}

function Test-ShouldRestoreBaseWorktree {
    param([hashtable]$GitPolicy)
    return ($script:ShipMerged -and $GitPolicy.checkout_main_after_merge -eq $true)
}

function Sync-BaseBranch {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )
    Invoke-Git @('fetch', 'origin') | Out-Null
    Invoke-Git @('checkout', $BaseBranch) | Out-Null
    Invoke-Git @('pull', '--ff-only', 'origin', $BaseBranch) | Out-Null
}

function Update-BranchFromRemoteBase {
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
        [string]$HeadBranch,
        [string]$Title,
        [string]$BodyFile
    )
    if ($SkipPullRequest) {
        Write-Host '`[ship-git] skip pull request' -ForegroundColor Yellow
        return $null
    }
    if (-not $HeadBranch) {
        $HeadBranch = (Invoke-Git @('branch', '--show-current')).Trim()
    }
    if (-not $HeadBranch) { throw 'HeadBranch is required for pull request.' }
    $existing = Get-ExistingPullRequestUrl -HeadBranch $HeadBranch -BaseBranch $BaseBranch
    if ($existing) {
        Write-Host "`[ship-git] PR already exists: $existing" -ForegroundColor Green
        return $existing
    }
    $ghArgs = @('pr', 'create', '--base', $BaseBranch)
    if ($Title) { $ghArgs += @('--title', $Title) }
    if ($BodyFile) {
        if (-not (Test-Path $BodyFile)) { throw "PR body file not found: $BodyFile" }
        $ghArgs += @('--body-file', $BodyFile)
    } else {
        $ghArgs += '--fill'
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = gh @ghArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "gh pr create failed: $out"
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Write-Host $out -ForegroundColor Green
    return ($out | Select-Object -Last 1)
}

function Invoke-Gh {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    if ($WhatIf) {
        Write-Host "gh $($Args -join ' ')" -ForegroundColor DarkGray
        return ""
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = gh @Args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "gh $($Args -join ' ') failed: $out"
        }
        return $out
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Resolve-PrNumber {
    param(
        [string]$PrUrl,
        [Parameter(Mandatory = $true)][string]$HeadBranch,
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )
    if ($PrUrl -match '/pull/(\d+)') { return [int]$Matches[1] }
    if ($WhatIf) { return 0 }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = gh pr view --head $HeadBranch --base $BaseBranch --json number --jq '.number' 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Could not resolve PR number for head=$HeadBranch base=$BaseBranch" }
        $num = [int](($out | Out-String).Trim())
        if ($num -le 0) { throw "Could not resolve PR number for head=$HeadBranch base=$BaseBranch" }
        return $num
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Get-MergeMethodArgs {
    param([hashtable]$GitPolicy)
    switch ([string]$GitPolicy.merge_method) {
        'merge' { return @('--merge') }
        'rebase' { return @('--rebase') }
        default { return @('--squash') }
    }
}

function Enable-PrAutoMerge {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy
    )
    $ghArgs = @('pr', 'merge', [string]$PrNumber, '--auto') + (Get-MergeMethodArgs -GitPolicy $GitPolicy)
    Write-Host "`[ship-git] enabling auto-merge on PR #$PrNumber" -ForegroundColor Cyan
    Invoke-Gh -Args $ghArgs | Out-Null
}

function Get-PrStatus {
    param([Parameter(Mandatory = $true)][int]$PrNumber)
    if ($WhatIf) {
        return [pscustomobject]@{ state = 'OPEN'; mergeable = 'MERGEABLE'; checks_failed = $false; checks_pending = $true }
    }
    $json = Invoke-Gh -Args @('pr', 'view', [string]$PrNumber, '--json', 'state,mergeable,statusCheckRollup')
    $view = ($json | Out-String).Trim() | ConvertFrom-Json
    $failed = $false
    $pending = $false
    foreach ($check in @($view.statusCheckRollup)) {
        if ($check.state -eq 'FAILURE' -or $check.conclusion -eq 'FAILURE') { $failed = $true }
        if ($check.state -eq 'PENDING' -or $check.status -eq 'IN_PROGRESS') { $pending = $true }
        if ($check.conclusion -eq 'SUCCESS' -or $check.state -eq 'SUCCESS') { continue }
        if ($check.conclusion -and $check.conclusion -notin @('SUCCESS', 'NEUTRAL', 'SKIPPED')) { $failed = $true }
    }
    return [pscustomobject]@{
        state          = [string]$view.state
        mergeable      = [string]$view.mergeable
        checks_failed  = $failed
        checks_pending = $pending
    }
}

function Wait-ForPrMerged {
    param(
        [Parameter(Mandatory = $true)][int]$PrNumber,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy
    )
    $timeoutMin = 20
    if ($GitPolicy.ci_wait_timeout_minutes) {
        $timeoutMin = [int]$GitPolicy.ci_wait_timeout_minutes
    }
    $waitForCi = $true
    if ($null -ne $GitPolicy.wait_for_ci) { $waitForCi = [bool]$GitPolicy.wait_for_ci }
    $deadline = (Get-Date).AddMinutes($timeoutMin)
    Write-Host "`[ship-git] waiting for PR #$PrNumber merge (timeout ${timeoutMin}m)" -ForegroundColor Cyan

    while ((Get-Date) -lt $deadline) {
        $status = Get-PrStatus -PrNumber $PrNumber
        if ($status.state -eq 'MERGED') {
            return @{ merge_state = 'MERGED'; merged = $true }
        }
        if ($status.state -eq 'CLOSED') {
            return @{ merge_state = 'CLOSED'; merged = $false }
        }
        if ($waitForCi -and $status.checks_failed) {
            return @{ merge_state = 'failed'; merged = $false }
        }
        if ($status.mergeable -eq 'CONFLICTING') {
            return @{ merge_state = 'conflict'; merged = $false }
        }
        Start-Sleep -Seconds 15
    }
    return @{ merge_state = 'waiting'; merged = $false }
}

function Remove-ShipBranch {
    param(
        [Parameter(Mandatory = $true)][string]$BranchName,
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy
    )
    try {
        if (-not $GitPolicy.delete_branch_after_merge) { return $false }
        $current = (Invoke-Git @('branch', '--show-current')).Trim()
        if ($current -eq $BranchName) {
            Invoke-Git @('checkout', $BaseBranch) | Out-Null
        }
        # GitHub deletes the remote branch after merge. This force delete is safe
        # only because the caller has already confirmed the PR state is MERGED.
        Invoke-Git @('branch', '-D', $BranchName) | Out-Null
        return $true
    } catch {
        Write-Host "`[ship-git] branch cleanup warning: $_" -ForegroundColor Yellow
        return $false
    }
}

function Remove-MergedLocalBranches {
    param(
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy
    )
    if ($WhatIf -or -not $GitPolicy.delete_branch_after_merge) { return }

    Invoke-Git @('fetch', '--prune', 'origin') | Out-Null
    $current = (Invoke-Git @('branch', '--show-current')).Trim()
    $branches = @(Invoke-Git @('for-each-ref', 'refs/heads', '--format=%(refname:short)'))
    foreach ($branch in $branches) {
        $branch = $branch.Trim()
        if (-not $branch -or $branch -eq $BaseBranch -or $branch -eq $current) { continue }
        try {
            $merged = (Invoke-Gh -Args @('pr', 'list', '--head', $branch, '--base', $BaseBranch, '--state', 'merged', '--json', 'number', '--jq', 'length')).Trim()
            if ($merged -eq '0') { continue }
            Invoke-Git @('branch', '-D', $branch) | Out-Null
            Write-Host "`[ship-git] removed merged local branch $branch" -ForegroundColor DarkGray
        } catch {
            Write-Host "`[ship-git] branch cleanup warning for ${branch}: $_" -ForegroundColor Yellow
        }
    }
}

function Invoke-PostPullRequestAutomation {
    param(
        [Parameter(Mandatory = $true)][string]$PrUrl,
        [Parameter(Mandatory = $true)][string]$BranchName,
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][hashtable]$GitPolicy,
        [bool]$RevalidateNeeded
    )

    if (-not $GitPolicy.auto_merge) { return @{} }
    if ($WhatIf) {
        Write-Host "`[ship-git] WhatIf: would auto-merge and cleanup branch $BranchName" -ForegroundColor Yellow
        return @{ merged = $false; merge_state = 'whatif'; branch_deleted = $false }
    }

    Enable-GitHubAutoMergeSetting -WhatIf:$WhatIf | Out-Null
    $prNumber = Resolve-PrNumber -PrUrl $PrUrl -HeadBranch $BranchName -BaseBranch $BaseBranch
    Enable-PrAutoMerge -PrNumber $prNumber -GitPolicy $GitPolicy
    if (-not $WaitForMerge) {
        return @{
            merged         = $false
            merge_state    = 'auto_merge_enabled'
            branch_deleted = $false
            main_sha       = $null
        }
    }
    $wait = Wait-ForPrMerged -PrNumber $prNumber -GitPolicy $GitPolicy

    $branchDeleted = $false
    $mainSha = $null
    if ($wait.merged) {
        $branchDeleted = Remove-ShipBranch -BranchName $BranchName -BaseBranch $BaseBranch -GitPolicy $GitPolicy
        $script:ShipMerged = $true
        $mainSha = (Invoke-Git @('rev-parse', 'HEAD')).Trim()
    } elseif ($RevalidateNeeded) {
        Write-Host "`[ship-git] revalidate recommended after rebase (revalidate_after_rebase)" -ForegroundColor Yellow
    }

    return @{
        merged         = [bool]$wait.merged
        merge_state    = [string]$wait.merge_state
        branch_deleted = $branchDeleted
        main_sha       = $mainSha
    }
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

    Invoke-ShipCommit -Message $Message -Skip:$SkipCommit
    Assert-WorkingTreeCleanAfterCommit -Skip:$SkipCommit

    if (-not $SkipPush) {
        Invoke-Git @('push', 'origin', $target) | Out-Null
        Write-Host "`[ship-git] pushed to origin/$target" -ForegroundColor Green
        $script:DeliveryStarted = $true
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
            $null = git show-ref --verify --quiet "refs/heads/$BranchName"; $code = $LASTEXITCODE
            if ($code -eq 0) {
                Invoke-Git @('checkout', $BranchName) | Out-Null
            } else {
                Invoke-Git @('checkout', '-b', $BranchName) | Out-Null
            }
        }
    }

    Invoke-ShipCommit -Message $Message -Skip:$SkipCommit
    Assert-WorkingTreeCleanAfterCommit -Skip:$SkipCommit

    Invoke-Git @('fetch', 'origin') | Out-Null
    $rebased = $false
    if ($GitPolicy.sync_remote_before_pr) {
        $rebased = Update-BranchFromRemoteBase -BaseBranch $base
    }

    if (-not $SkipPush) {
        Invoke-Git @('push', '-u', 'origin', $BranchName) | Out-Null
        Write-Host "`[ship-git] pushed origin/$BranchName" -ForegroundColor Green
        $script:DeliveryStarted = $true
    }

    $prUrl = $null
    if ($GitPolicy.pull_request) {
        $prUrl = New-PullRequest -BaseBranch $base -HeadBranch $BranchName -Title $PrTitle -BodyFile $PrBodyFile
    }

    $revalidateNeeded = [bool]$GitPolicy.revalidate_after_rebase -and $rebased
    $automation = @{}
    if ($prUrl -and $GitPolicy.auto_merge) {
        $automation = Invoke-PostPullRequestAutomation `
            -PrUrl $prUrl `
            -BranchName $BranchName `
            -BaseBranch $base `
            -GitPolicy $GitPolicy `
            -RevalidateNeeded $revalidateNeeded
    }

    return [ordered]@{
        strategy          = 'feature-branch'
        branch            = $BranchName
        base_branch       = $base
        rebased           = $rebased
        revalidate_needed = $revalidateNeeded
        pr_url            = $prUrl
        merged            = $automation.merged
        merge_state       = $automation.merge_state
        branch_deleted    = $automation.branch_deleted
        main_sha          = $automation.main_sha
    }
}

if (-not $RepoPath) {
    $RepoPath = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $RepoPath) {
        throw "RepoPath not provided and not inside a git repository."
    }
}

$RepoPath = (Resolve-Path $RepoPath).Path
$script:DeliveryStarted = $false
$script:ShipMerged = $false
$gitPolicy = @{}
$baseBranch = 'main'
Push-Location $RepoPath
try {
    $policy = Get-RepoPolicy -RepoPath $RepoPath
    $gitPolicy = $policy.git
    $baseBranch = Get-BaseBranchFromPolicy -GitPolicy $gitPolicy
    Remove-MergedLocalBranches -BaseBranch $baseBranch -GitPolicy $gitPolicy
    if ($CleanupMergedBranches) {
        @{
            strategy = [string]$gitPolicy.strategy
            cleanup  = 'completed'
        } | ConvertTo-Json -Compress
        exit 0
    }

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

    if ($WaitForMerge -and $gitPolicy.auto_merge -eq $true -and $result.merged -ne $true) {
        throw "[ship-git] auto-merge did not complete (state=$($result.merge_state))."
    }
    $result | ConvertTo-Json -Compress
    exit 0
} catch {
    if ($script:DeliveryStarted) {
        $prMerged = $false
        if ($FeatureBranch -and -not $WhatIf) {
            try {
                $prNum = Resolve-PrNumber -PrUrl '' -HeadBranch $FeatureBranch -BaseBranch $baseBranch
                $st = Get-PrStatus -PrNumber $prNum
                $prMerged = ($st.state -eq 'MERGED')
            } catch { }
        }
        if ($prMerged) {
            Write-Host "`[ship-git] PR merged remotely - restoring clean base before exit" -ForegroundColor Yellow
            Restore-CleanBaseBranch -BaseBranch $baseBranch -GitPolicy $gitPolicy
            @{
                strategy    = [string]$gitPolicy.strategy
                branch      = $FeatureBranch
                merged      = $true
                merge_state = 'MERGED'
            } | ConvertTo-Json -Compress
            exit 0
        }
    }
    throw
} finally {
    if (Test-ShouldRestoreBaseWorktree -GitPolicy $gitPolicy) {
        try {
            Restore-CleanBaseBranch -BaseBranch $baseBranch -GitPolicy $gitPolicy
        } catch {
            Write-Host "`[ship-git] finally restore warning: $_" -ForegroundColor Yellow
        }
    }
    Pop-Location
}
