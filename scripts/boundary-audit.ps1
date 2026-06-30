#Requires -Version 5.1
<#
.SYNOPSIS
  Public-framework boundary gate: blocks consumer identifiers in tracked/staged files.
.DESCRIPTION
  Scans file paths and contents for consumer-specific names. Used by CI, pre-commit, and pre-push.
.PARAMETER Staged
  Audit only staged paths (pre-commit). Default: all tracked files (git ls-files).
.PARAMETER Json
  Emit machine-readable report.
.EXAMPLE
  .\scripts\boundary-audit.ps1
  .\scripts\boundary-audit.ps1 -Staged
#>
param(
    [switch]$Staged,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_load-env.ps1')
$root = Get-OctoClusterRoot
Set-Location $root

$contentPatterns = @(
    'sigla[-_]',
    '\bmplan\b',
    '\bmponto\b',
    'ponto-eletronico',
    'personal-vault',
    'openpolvo',
    'polvocode',
    'polvo00',
    'integracoes',
    'mplan-ingestion',
    'powerbuilder',
    'OPE-[0-9]',
    'AI_DOMAIN',
    'AI_WORKSPACE'
)

$filenamePatterns = @(
    'sigla',
    'mplan',
    'mponto',
    'ponto',
    'personal-vault',
    'openpolvo',
    'polvo',
    'integracoes',
    'ai-workspace'
)

$allowedRepoPolicyFiles = @(
    'default.yaml',
    'octo-cluster.yaml',
    'consumer-demo.yaml'
)

$contentExcludePaths = @(
    'scripts/migrate-octo-cluster.ps1',
    'docs/guides/public-framework-boundary.md',
    'scripts/boundary-audit.ps1',
    'CHANGELOG.md'
)

function Get-AuditPaths {
    if ($Staged) {
        $names = & git diff --cached --name-only --diff-filter=ACMR 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @($names | Where-Object { $_ })
    }
    $names = & git ls-files 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($names | Where-Object { $_ })
}

function Test-FilenameViolation {
    param([string]$RelativePath)
    $base = [System.IO.Path]::GetFileName($RelativePath).ToLowerInvariant()
    $full = $RelativePath.ToLowerInvariant().Replace('\', '/')

    if ($full -match '^repo-policies/.+\.yaml$') {
        if ($allowedRepoPolicyFiles -notcontains $base) {
            return "repo-policies allowlist (only default, octo-cluster, consumer-demo)"
        }
    }

    foreach ($pat in $filenamePatterns) {
        if ($base -match $pat -or $full -match "/$pat" -or $full -match "$pat/") {
            return "filename pattern '$pat'"
        }
    }
    return $null
}

$findings = @()
$paths = Get-AuditPaths

foreach ($rel in $paths) {
    if (-not $rel) { continue }
    $reason = Test-FilenameViolation -RelativePath $rel
    if ($reason) {
        $findings += [ordered]@{
            kind    = 'filename'
            pattern = $reason
            match   = $rel
        }
    }
}

foreach ($pattern in $contentPatterns) {
    if ($Staged -and $paths.Count -gt 0) {
        foreach ($rel in $paths) {
            if ($contentExcludePaths -contains $rel) { continue }
            if (-not (Test-Path $rel)) { continue }
            $hits = Select-String -Path $rel -Pattern $pattern -AllMatches -CaseSensitive:$false -ErrorAction SilentlyContinue
            foreach ($hit in @($hits)) {
                $findings += [ordered]@{
                    kind    = 'content'
                    pattern = $pattern
                    match   = "{0}:{1}:{2}" -f $rel, $hit.LineNumber, $hit.Line.Trim()
                }
            }
        }
        continue
    }

    $output = & git grep -E -i -n $pattern 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) { continue }

    foreach ($line in @($output)) {
        if (-not $line) { continue }
        $filePath = ($line -split ':', 2)[0]
        if ($contentExcludePaths -contains $filePath) { continue }
        $findings += [ordered]@{
            kind    = 'content'
            pattern = $pattern
            match   = $line
        }
    }
}

$passed = ($findings.Count -eq 0)

if ($Json) {
    @{
        passed   = $passed
        staged   = [bool]$Staged
        findings = $findings
    } | ConvertTo-Json -Depth 5
    if (-not $passed) { exit 1 }
    exit 0
}

$scope = if ($Staged) { 'staged changes' } else { 'tracked source' }
if ($passed) {
    Write-Host "boundary-audit: OK (no consumer identifiers in $scope)" -ForegroundColor Green
    exit 0
}

Write-Host "boundary-audit: FAILED ($scope)" -ForegroundColor Red
foreach ($f in $findings) {
    Write-Host ("  [{0}/{1}] {2}" -f $f.kind, $f.pattern, $f.match) -ForegroundColor Yellow
}
Write-Host 'Consumer identifiers are treated as secrets — generalize, move to private overlay, or remove.' -ForegroundColor DarkGray
exit 1
