param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
$ce = Get-ContextEngineRoot
exit (Invoke-ContextEngine run --cwd $ce map $Path)
