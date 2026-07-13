# Chat-friendly LinkedIn draft preview (no browser).
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')
. (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
. (Join-Path $PSScriptRoot 'linkedin-publish-common.ps1')

$root = Get-OctoClusterRoot
$manifestPathResolved = Resolve-LinkedInManifestPath -ManifestPath $ManifestPath -Root $root

if (-not (Test-Path $manifestPathResolved)) {
    Write-Error "Manifest not found: $manifestPathResolved"
    exit 1
}

$manifest = Get-Content -Path $manifestPathResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$shipCtx = Get-ShipExecutionContext -RepoPath $root
$preflight = Get-LinkedInPublishPreflight -WorkspaceRoot $root -RepoPath $root -ShipContext $shipCtx

$ticket = if ($manifest.ticket) { [string]$manifest.ticket } else { 'draft' }
$hookEn = Get-PostHookLine -PostText ([string]$manifest.posts.en)
$hookPt = Get-PostHookLine -PostText ([string]$manifest.posts.pt)
$imageEn = Get-ImageBasename -ImagePath ([string]$manifest.images.en) -Root $root
$imagePt = Get-ImageBasename -ImagePath ([string]$manifest.images.pt) -Root $root

Write-Host "LINKEDIN_PREVIEW ticket=$ticket"
Write-Host "MANIFEST=$manifestPathResolved"
Write-Host "HOOK_EN=$hookEn"
Write-Host "HOOK_PT=$hookPt"
Write-Host "IMAGE_EN=$imageEn"
Write-Host "IMAGE_PT=$imagePt"
Write-Host "PROVIDER=$($preflight.providerId)"

if ($preflight.ok) {
    Write-Host 'PREFLIGHT_OK=true'
    Write-Host 'PREFLIGHT_REASON='
    if ($env:LINKEDIN_TOKEN_FILE) {
        Write-Host 'TOKEN_FILE=[REDACTED]'
    }
} else {
    Write-Host 'PREFLIGHT_OK=false'
    Write-Host "PREFLIGHT_REASON=$($preflight.reason)"
}

Write-Host 'ACTION=Reply "publicar" to publish both locales (EN then PT)'
