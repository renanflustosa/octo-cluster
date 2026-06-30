#Requires -Version 5.1
<#
.SYNOPSIS
  Run any Octo Cluster script relative to the installation root (metrics, audits, etc.).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'scripts\_octo-args.ps1')
$target = Join-Path (Get-OctoClusterRoot) $RelativePath
if (-not (Test-Path -LiteralPath $target)) {
    throw "Script not found under Octo Cluster root: $RelativePath"
}
& $target @RemainingArgs
exit $LASTEXITCODE
