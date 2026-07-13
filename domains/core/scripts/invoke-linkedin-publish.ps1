# Discover and run LinkedIn publish providers (pipeline=linkedin, phase=publish).
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [ValidateSet('en', 'pt')]
    [string]$Locale,

    [switch]$AllLocales,

    [switch]$Confirm,

    [switch]$PreflightOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')
. (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
. (Join-Path $PSScriptRoot 'linkedin-publish-common.ps1')

function Write-PublishResult {
    param(
        $Manifest,
        [string]$ManifestPath,
        [hashtable]$Result
    )

    $draftDir = Split-Path $ManifestPath -Parent
    $ticket = if ($Manifest.ticket) { [string]$Manifest.ticket } else { 'draft' }
    $ts = if ($Manifest.timestamp) { [string]$Manifest.timestamp } else { (Get-Date).ToString('yyyyMMdd-HHmm') }
    $outPath = Join-Path $draftDir "$ticket-$ts-publish-result.json"

    $payload = [ordered]@{
        ticket    = $ticket
        timestamp = $ts
        manifest  = $ManifestPath
        results   = $Result
    }

    $json = $payload | ConvertTo-Json -Depth 6
    Set-Content -Path $outPath -Value $json -Encoding UTF8
    Write-Host "PUBLISH_RESULT=$outPath" -ForegroundColor Green
    Write-Host $json
}

$root = Get-OctoClusterRoot
$manifestPathResolved = Resolve-LinkedInManifestPath -ManifestPath $ManifestPath -Root $root

if (-not (Test-Path $manifestPathResolved)) {
    Write-Error "Manifest not found: $manifestPathResolved"
    exit 1
}

$manifest = Get-Content -Path $manifestPathResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$repoPath = $root
$shipCtx = Get-ShipExecutionContext -RepoPath $repoPath
$preflight = Get-LinkedInPublishPreflight -WorkspaceRoot $root -RepoPath $repoPath -ShipContext $shipCtx

if ($PreflightOnly) {
    if ($preflight.ok) {
        Write-Host '[linkedin-publish] preflight OK' -ForegroundColor Green
        Write-Host "PROVIDER=$($preflight.providerId)"
        exit 0
    }
    Write-Host "[linkedin-publish] preflight failed: $($preflight.reason)" -ForegroundColor Yellow
    Write-Host "PROVIDER=$($preflight.providerId)"
    exit 1
}

if (-not $Confirm) {
    Write-Error 'Publishing requires -Confirm (user confirmed in chat preview).'
    exit 1
}

if ($AllLocales -and $Locale) {
    Write-Error 'Use -AllLocales or -Locale, not both.'
    exit 1
}

if (-not $AllLocales -and -not $Locale) {
    Write-Error 'Specify -Locale (en|pt) or -AllLocales.'
    exit 1
}

$locales = if ($AllLocales) { @('en', 'pt') } else { @($Locale) }

if (-not $preflight.ok) {
    $result = [ordered]@{}
    foreach ($loc in $locales) {
        $result[$loc] = [ordered]@{
            ok       = $false
            error    = [string]$preflight.reason
            provider = [string]$preflight.providerId
        }
    }
    Write-PublishResult -Manifest $manifest -ManifestPath $manifestPathResolved -Result $result
    if ($preflight.reason -eq 'no publish provider found') { exit 2 }
    exit 1
}

$providers = @(Get-LinkedInPublishProviders -WorkspaceRoot $root -RepoPath $repoPath -ShipContext $shipCtx)
$provider = $providers | Where-Object { $_.id } | Select-Object -First 1

if (-not $provider -or -not $provider._script_path -or -not (Test-Path $provider._script_path)) {
    Write-Error 'All publish providers failed or missing scripts.'
    exit 1
}

$localeDelaySec = 10
$delayRaw = [string]$env:LINKEDIN_PUBLISH_LOCALE_DELAY_SECONDS
if ($delayRaw -and [int]::TryParse($delayRaw, [ref]$null)) {
    $localeDelaySec = [Math]::Max(0, [int]$delayRaw)
}

$result = [ordered]@{}
$localeIndex = 0
foreach ($loc in $locales) {
    if ($localeIndex -gt 0 -and $localeDelaySec -gt 0) {
        Write-Host "[linkedin-publish] waiting ${localeDelaySec}s before locale=$loc" -ForegroundColor DarkGray
        Start-Sleep -Seconds $localeDelaySec
    }
    $localeIndex++

    $run = Invoke-LinkedInPublishLocale -Provider $provider -ManifestPathResolved $manifestPathResolved -Locale $loc
    $entry = [ordered]@{
        ok       = [bool]$run.ok
        provider = [string]$run.provider
    }
    if ($run.ok) {
        if ($run.postId) { $entry.postId = [string]$run.postId }
        Write-Host "[linkedin-publish] published locale=$loc via $($run.provider)" -ForegroundColor Green
    } else {
        $entry.error = if ($run.error) { [string]$run.error } else { "exit $($run.exitCode)" }
        if ($run.httpStatus -gt 0) { $entry.httpStatus = [int]$run.httpStatus }
        if ($run.apiCode) { $entry.apiCode = [string]$run.apiCode }
        if ($run.apiMessage) { $entry.apiMessage = [string]$run.apiMessage }
        Write-Host "[linkedin-publish] locale=$loc failed: $($entry.error)" -ForegroundColor Red
    }
    $result[$loc] = $entry
}

Write-PublishResult -Manifest $manifest -ManifestPath $manifestPathResolved -Result $result

$okCount = @($result.Values | Where-Object { $_.ok -eq $true }).Count
$failCount = $locales.Count - $okCount

if ($okCount -eq $locales.Count) { exit 0 }
if ($okCount -eq 0) { exit 1 }
exit 3
