# LanceDB hybrid search for contextual code slices.
param(
    [string]$Profile,
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$Query,
    [string]$Module,
    [string]$Kind,
    [string]$Repo,
    [switch]$VectorOnly
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
if (-not $Profile -and $RepoRoot) { $Profile = Split-Path $RepoRoot -Leaf }
if (-not $Profile) { Write-Error "Use -Profile octo-cluster or -RepoRoot <path>"; exit 1 }
$ce = Get-ContextEngineRoot
$args = @('run', '--cwd', $ce, 'search', $Profile, '--query', $Query)
if ($Module) { $args += @('--module', $Module) }
if ($Kind) { $args += @('--kind', $Kind) }
if ($Repo) { $args += @('--repo', $Repo) }
if ($VectorOnly) { $args += '--vector-only' }
exit (Invoke-ContextEngine @args)
