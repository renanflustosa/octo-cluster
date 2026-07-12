#Requires -Version 5.1
<#
.SYNOPSIS
  Enable GitHub auto-merge on a repository (idempotent; also invoked by /ship when auto_merge policy is set).
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
        Write-Host "[enable-auto-merge] WhatIf: would set allow_auto_merge on $slug" -ForegroundColor Yellow
        return $slug
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = gh api "repos/$slug" --jq '.allow_auto_merge' 2>$null
        if ($LASTEXITCODE -eq 0 -and ($raw | Out-String).Trim() -eq 'true') {
            Write-Host "[enable-auto-merge] already enabled on $slug" -ForegroundColor DarkGray
            return $slug
        }
        gh api "repos/$slug" -X PATCH -f allow_auto_merge=true | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable allow_auto_merge on $slug (admin repo permission required)"
        }
        Write-Host "[ok] allow_auto_merge enabled on $slug" -ForegroundColor Green
        return $slug
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Enable-GitHubAutoMergeSetting -Repo $Repo -WhatIf:$WhatIf
}
