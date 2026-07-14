# Resolve repository git policy from repo-policies/default.yaml + repo-policies/<repo>.yaml
# Usage: . get-repo-policy.ps1; Get-RepoPolicy -RepoPath "$env:OCTO_CLUSTER"
#        Get-RepoPolicyFromGitRoot

param()

$ErrorActionPreference = "Stop"

function ConvertFrom-SimpleYaml {
    param([string[]]$Lines)

    $root = [ordered]@{}
    $stack = @(@{ Map = $root; Indent = -1 })

    foreach ($raw in $Lines) {
        if ($raw -match '^\s*(#|$)') { continue }

        $indent = ($raw.Length - $raw.TrimStart().Length)
        $line = $raw.Trim()

        while ($stack.Count -gt 1 -and $indent -le $stack[-1].Indent) {
            $stack = $stack[0..($stack.Count - 2)]
        }

        if ($line -match '^([^:]+):\s*$') {
            $key = $Matches[1].Trim()
            $child = [ordered]@{}
            $stack[-1].Map[$key] = $child
            $stack += @{ Map = $child; Indent = $indent }
            continue
        }

        if ($line -match '^([^:]+):\s*(.+)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($value -eq 'true') {
                $stack[-1].Map[$key] = $true
            } elseif ($value -eq 'false') {
                $stack[-1].Map[$key] = $false
            } elseif ($value -match '^["''](.+)["'']$') {
                $stack[-1].Map[$key] = $Matches[1]
            } else {
                $stack[-1].Map[$key] = $value
            }
        }
    }

    return $root
}

function Get-DefaultRepoPolicy {
    $workspace = Get-OctoClusterRoot
    $defaultPath = Join-Path $workspace "repo-policies\default.yaml"
    if (Test-Path $defaultPath) {
        $lines = Get-Content -Path $defaultPath -Encoding UTF8
        return (ConvertFrom-SimpleYaml -Lines $lines)
    }

    return [ordered]@{
        git = [ordered]@{
            strategy      = 'direct'
            target_branch = 'main'
            pull_request  = $false
        }
    }
}

function Merge-RepoPolicyMaps {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = [ordered]@{}
    foreach ($key in $Base.Keys) { $result[$key] = $Base[$key] }

    foreach ($key in $Override.Keys) {
        if ($key -eq 'git' -and $result.git -and $Override.git) {
            $mergedGit = [ordered]@{}
            foreach ($gk in $result.git.Keys) { $mergedGit[$gk] = $result.git[$gk] }
            foreach ($gk in $Override.git.Keys) { $mergedGit[$gk] = $Override.git[$gk] }
            $result['git'] = $mergedGit
        } else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}

function Get-RepoPolicyFileName {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $resolved = (Resolve-Path $RepoPath).Path
    $marker = Join-Path $resolved '.octo\repo-policy'
    if (Test-Path $marker) {
        $id = (Get-Content -Path $marker -Raw -Encoding UTF8).Trim()
        if ($id) { return $id }
    }

    if (Test-Path (Join-Path $resolved 'install.ps1')) {
        return 'octo-cluster'
    }
    return (Split-Path $resolved -Leaf)
}

function Get-RepoNameFromPath {
    param([Parameter(Mandatory = $true)][string]$RepoPath)
    return Get-RepoPolicyFileName -RepoPath $RepoPath
}

function Get-RepoPolicyPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoName,
        [string]$PoliciesRoot = $(Join-Path (Get-OctoClusterRoot) "repo-policies")
    )
    Join-Path $PoliciesRoot "$RepoName.yaml"
}

function Get-RepoPolicy {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [string]$PoliciesRoot
    )

    $repoName = Get-RepoNameFromPath -RepoPath $RepoPath
    $policiesRoot = if ($PoliciesRoot) { $PoliciesRoot } else { Join-Path (Get-OctoClusterRoot) "repo-policies" }
    $policyPath = Join-Path $policiesRoot "$repoName.yaml"

    $policy = Get-DefaultRepoPolicy
    $sources = @('default.yaml')

    if (Test-Path $policyPath) {
        $lines = Get-Content -Path $policyPath -Encoding UTF8
        $specific = ConvertFrom-SimpleYaml -Lines $lines
        $policy = Merge-RepoPolicyMaps -Base $policy -Override $specific
        $sources += "$repoName.yaml"
    }

    if (-not $policy.git) {
        Write-Host "`[repo-policy] missing git section - using default git policy" -ForegroundColor Yellow
        $policy = Merge-RepoPolicyMaps -Base (Get-DefaultRepoPolicy) -Override $policy
    }

    Write-Host "`[repo-policy] loaded $($sources -join ' + ') (strategy=$($policy.git.strategy))" -ForegroundColor DarkGray
    return $policy
}


function Get-RepoVerifyCommands {
    param([Parameter(Mandatory = $true)]$Policy)

    if ($Policy.verify -and $Policy.verify.enabled -eq $false) {
        return @()
    }

    if (-not $Policy.verify -or -not $Policy.verify.commands) {
        return @()
    }

    $raw = $Policy.verify.commands
    if ($raw -isnot [System.Collections.IDictionary]) { return @() }

    $results = New-Object System.Collections.ArrayList
    foreach ($key in $raw.Keys) {
        $entry = $raw[$key]
        if ($entry -isnot [System.Collections.IDictionary]) { continue }
        $run = [string]$entry.run
        if (-not $run) { continue }
        [void]$results.Add([ordered]@{
            id       = [string]$key
            cwd      = if ($entry.cwd) { [string]$entry.cwd } else { $null }
            run      = $run
            optional = ($entry.optional -eq $true)
            tier     = if ($entry.tier) { [string]$entry.tier } else { 'fast' }
        })
    }

    return @($results | Sort-Object { [string]$_.id })
}
function Get-RepoPolicyFromGitRoot {
    param([string]$StartPath = (Get-Location).Path)

    Push-Location $StartPath
    try {
        $root = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $root) {
            throw ('Not inside a git repository (started at {0}).' -f $StartPath)
        }
        return (Get-RepoPolicy -RepoPath $root)
    } finally {
        Pop-Location
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    Get-RepoPolicyFromGitRoot
}
