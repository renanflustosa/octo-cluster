# Resolve OCTO_CLUSTER and load shared path helpers.
# Dot-source from any domain script:
#   . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')

. (Join-Path $PSScriptRoot '_env.ps1')

if (-not $env:OCTO_CLUSTER -or -not (Test-Path -LiteralPath $env:OCTO_CLUSTER)) {
    throw "OCTO_CLUSTER could not be resolved. Open octo-cluster.code-workspace or set OCTO_CLUSTER to your octo-cluster clone."
}
