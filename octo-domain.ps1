#Requires -Version 5.1
<#
.SYNOPSIS
  Octo Cluster domain harness CLI entry point (read-gate, context-search, scan-bootstrap, ...).

.DESCRIPTION
  Self-locating wrapper around scripts/invoke-domain-script.ps1 (in-process).
  Prefer flat parameters (-Path, -Ticket, …) or -ScriptArgsJson over -ScriptArgs
  when calling via powershell -File from an outer shell.
#>
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [hashtable]$ScriptArgs = @{},
    [string]$ScriptArgsJson = '',
    [string]$Domain,
    [string]$Path,
    [string]$Ticket,
    [string]$Profile,
    [switch]$SkipIndex,
    [switch]$WithStack
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'scripts\_octo-args.ps1')

$mergedArgs = Merge-OctoScriptArgs -Base $ScriptArgs -ScriptArgsJson $ScriptArgsJson -Flat @{
    Path      = $Path
    Ticket    = $Ticket
    Profile   = $Profile
    SkipIndex = $SkipIndex
    WithStack = $WithStack
}

$target = Join-Path $PSScriptRoot 'scripts\invoke-domain-script.ps1'
& $target -Name $Name -ScriptArgs $mergedArgs -Domain $Domain
exit $LASTEXITCODE
