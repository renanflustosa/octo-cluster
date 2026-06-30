# Resolve OCTO_CLUSTER and load shared path helpers.
# Dot-source from any domain script:
#   . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')

. (Join-Path $PSScriptRoot '_env.ps1')

try {
    $null = Get-OctoClusterRoot
} catch {
    throw $_
}
