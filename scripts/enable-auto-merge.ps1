#Requires -Version 5.1
<#
.SYNOPSIS
  Enable GitHub auto-merge and delete-branch-on-merge on a repository (idempotent; also invoked by /ship when auto_merge policy is set).
.PARAMETER Repo
  owner/name (default: inferred from origin remote).
#>
param(
    [string]$Repo = '',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-GhRepoSlugForAutoMerge {
    $url = (git remote get-url origin 2>$null)
    if (-not $url) { throw 'No origin remote; pass -Repo owner/name' }
    if ($url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)') {
        return "$($Matches.owner)/$($Matches.repo)"
    }
    throw "Cannot parse GitHub slug from origin: $url"
}

function Set-RepoFlagIfNeeded {
    param(
        [Parameter(Mandatory = $true)][string]$Slug,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)][string]$Label,
        [switch]$WhatIf
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = gh api "repos/$Slug" --jq ".$Field" 2>$null
        if ($LASTEXITCODE -eq 0 -and ($raw | Out-String).Trim() -eq 'true') {
            Write-Host "[enable-auto-merge] $Label already enabled on $Slug" -ForegroundColor DarkGray
            return
        }
        if ($WhatIf) {
            Write-Host "[enable-auto-merge] WhatIf: would set $Field on $Slug" -ForegroundColor Yellow
            return
        }
        gh api "repos/$Slug" -X PATCH -f "${Field}=true" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable $Field on $Slug (admin repo permission required)"
        }
        Write-Host "[ok] $Label enabled on $Slug" -ForegroundColor Green
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Enable-GitHubAutoMergeSetting {
    param(
        [string]$Repo = '',
        [switch]$WhatIf
    )
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'gh CLI required. Run: gh auth login'
    }
    $slug = if ($Repo) { $Repo } else { Get-GhRepoSlugForAutoMerge }
    if ($WhatIf) {
        Write-Host "[enable-auto-merge] WhatIf: would set allow_auto_merge and delete_branch_on_merge on $slug" -ForegroundColor Yellow
        return $slug
    }
    Set-RepoFlagIfNeeded -Slug $slug -Field 'allow_auto_merge' -Label 'allow_auto_merge'
    Set-RepoFlagIfNeeded -Slug $slug -Field 'delete_branch_on_merge' -Label 'delete_branch_on_merge'
    return $slug
}

if ($MyInvocation.InvocationName -ne '.') {
    Enable-GitHubAutoMergeSetting -Repo $Repo -WhatIf:$WhatIf
}
