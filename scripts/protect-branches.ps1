#Requires -Version 5.1
<#
.SYNOPSIS
  Apply GitHub rulesets: protected branches merge only via PR (no direct push).
.PARAMETER Repo
  owner/name (default: inferred from origin remote).
.PARAMETER Branches
  Comma-separated branch names (default: main).
#>
param(
    [string]$Repo = '',
    [string]$Branches = 'main',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-GhRepoSlug {
    $url = (git remote get-url origin 2>$null)
    if (-not $url) { throw 'No origin remote; pass -Repo owner/name' }
    if ($url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)') {
        return "$($Matches.owner)/$($Matches.repo)"
    }
    throw "Cannot parse GitHub slug from origin: $url"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'gh CLI required. Run: gh auth login'
}

$repo = if ($Repo) { $Repo } else { Get-GhRepoSlug }
$branchList = @([string]$Branches -split '[,\s]+' | Where-Object { $_ })
$includes = @($branchList | ForEach-Object { "refs/heads/$_" })

Write-Host "Ruleset PR-only on $repo : $($branchList -join ', ')" -ForegroundColor Cyan

$body = @{
    name        = 'PR-only: protected branches'
    target      = 'branch'
    enforcement = 'active'
    conditions  = @{
        ref_name = @{
            include = $includes
            exclude = @()
        }
    }
    rules = @(
        @{
            type       = 'pull_request'
            parameters = @{
                dismiss_stale_reviews_on_push   = $false
                require_code_owner_review       = $false
                require_last_push_approval      = $false
                required_approving_review_count = 0
                required_review_thread_resolution = $false
            }
        },
        @{ type = 'deletion' },
        @{ type = 'non_fast_forward' }
    )
}

$json = $body | ConvertTo-Json -Depth 10
Write-Host $json -ForegroundColor DarkGray

if ($WhatIf) {
    Write-Host 'WhatIf: skipped gh api' -ForegroundColor Yellow
    exit 0
}

$existing = gh api "repos/$repo/rulesets" 2>$null | ConvertFrom-Json
$match = @($existing | Where-Object { $_.name -eq $body.name } | Select-Object -First 1)
if ($match) {
    Write-Host "Updating ruleset id $($match.id)" -ForegroundColor DarkGray
    $json | gh api "repos/$repo/rulesets/$($match.id)" -X PUT --input -
} else {
    Write-Host 'Creating ruleset' -ForegroundColor DarkGray
    $json | gh api "repos/$repo/rulesets" -X POST --input -
}

if ($LASTEXITCODE -ne 0) { throw "gh ruleset failed for $repo" }
Write-Host 'GitHub ruleset applied (PR required; force-push and deletion blocked).' -ForegroundColor Green
