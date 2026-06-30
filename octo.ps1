#Requires -Version 5.1
<#
.SYNOPSIS
  Octo Cluster pipeline CLI entry point (scan, ship, model, close, start-workspace, ...).

.DESCRIPTION
  Self-locating wrapper around scripts/invoke-pipeline.ps1 (in-process — no nested -File).
  Prefer flat parameters (-Ticket, -CommitMessage, …) or -ScriptArgsJson over -ScriptArgs
  when calling via powershell -File from an outer shell.
#>
param(
    [Parameter(Mandatory = $true)][string]$Pipeline,
    [ValidateSet('discover', 'run')]
    [string]$Action = 'run',
    [ValidateSet('all', 'discover', 'preflight', 'verification', 'gates', 'git', 'reviews')]
    [string]$Phase = 'all',
    [hashtable]$ScriptArgs = @{},
    [string]$ScriptArgsJson = '',
    [string]$Domain,
    [string]$RepoPath,
    [string]$Ticket,
    [string]$Profile,
    [string]$CommitMessage,
    [string]$FeatureBranch,
    [string]$PrTitle,
    [string]$PrBodyFile,
    [switch]$SkipGit,
    [switch]$SkipCommit,
    [switch]$SkipIndex,
    [switch]$WithStack
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'scripts\_octo-args.ps1')

$mergedArgs = Merge-OctoScriptArgs -Base $ScriptArgs -ScriptArgsJson $ScriptArgsJson -Flat @{
    Ticket    = $Ticket
    Profile   = $Profile
    SkipIndex = $SkipIndex
    WithStack = $WithStack
}

$target = Join-Path $PSScriptRoot 'scripts\invoke-pipeline.ps1'
& $target -Pipeline $Pipeline -Action $Action -Phase $Phase -ScriptArgs $mergedArgs `
    -Domain $Domain -RepoPath $RepoPath -CommitMessage $CommitMessage `
    -FeatureBranch $FeatureBranch -PrTitle $PrTitle -PrBodyFile $PrBodyFile `
    -SkipGit:$SkipGit -SkipCommit:$SkipCommit
exit $LASTEXITCODE
