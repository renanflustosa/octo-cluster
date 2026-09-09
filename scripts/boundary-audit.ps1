#Requires -Version 5.1
<#
.SYNOPSIS
  Public-framework boundary gate: blocks configured identifiers in tracked/staged files.
.DESCRIPTION
  Loads patterns from boundary-patterns.local.yaml (gitignored) and optional boundary-patterns.yaml.
  Copy boundary-patterns.example.yaml to boundary-patterns.local.yaml to customize.
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
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = Split-Path $PSScriptRoot -Parent }
Set-Location $root

$allowedRepoPolicyFiles = @(
    'default.yaml',
    'octo-cluster.yaml',
    'consumer-demo.yaml',
    'feature-branch-main.yaml',
    'node-pnpm-feature-branch-main.yaml',
    'private-secrets-vault.yaml'
)

$contentExcludePaths = @(
    'scripts/boundary-audit.ps1',
    'boundary-patterns.example.yaml'
)

function Read-YamlStringList {
    param(
        [string[]]$Lines,
        [ref]$Index,
        [string]$Key
    )
    $results = @()
    while ($Index.Value -lt $Lines.Count) {
        $line = $Lines[$Index.Value]
        if ($line -match '^\s*-\s+(.+)$') {
            $raw = $Matches[1].Trim()
            if (($raw.StartsWith("'") -and $raw.EndsWith("'")) -or ($raw.StartsWith('"') -and $raw.EndsWith('"'))) {
                $raw = $raw.Substring(1, $raw.Length - 2)
            }
            if ($raw) { $results += $raw }
            $Index.Value++
            continue
        }
        if ($line -match '^\S') { break }
        $Index.Value++
    }
    return $results
}

function Read-BoundaryPatternFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return @{ Content = @(); Filename = @() }
    }

    $lines = Get-Content $Path
    $content = @()
    $filename = @()
    $i = 0

    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -match '^\s*#') { $i++; continue }
        if ($line -match '^content_patterns:\s*$') {
            $i++
            $content += Read-YamlStringList -Lines $lines -Index ([ref]$i) -Key 'content_patterns'
            continue
        }
        if ($line -match '^filename_patterns:\s*$') {
            $i++
            $filename += Read-YamlStringList -Lines $lines -Index ([ref]$i) -Key 'filename_patterns'
            continue
        }
        $i++
    }

    return @{ Content = $content; Filename = $filename }
}

function Get-BoundaryPatterns {
    param([string]$Root)

    $mergedContent = @()
    $mergedFilename = @()

    foreach ($name in @('boundary-patterns.local.yaml', 'boundary-patterns.yaml')) {
        $path = Join-Path $Root $name
        $cfg = Read-BoundaryPatternFile -Path $path
        if ($cfg.Content.Count -gt 0) { $mergedContent += $cfg.Content }
        if ($cfg.Filename.Count -gt 0) { $mergedFilename += $cfg.Filename }
    }

    return @{
        Content  = @($mergedContent | Select-Object -Unique)
        Filename = @($mergedFilename | Select-Object -Unique)
    }
}

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
    param(
        [string]$RelativePath,
        [string[]]$FilenamePatterns
    )
    $base = [System.IO.Path]::GetFileName($RelativePath).ToLowerInvariant()
    $full = $RelativePath.ToLowerInvariant().Replace('\', '/')

    if ($full -match '^repo-policies/.+\.yaml$') {
        if ($allowedRepoPolicyFiles -notcontains $base) {
            return "repo-policies allowlist (only default, octo-cluster, consumer-demo)"
        }
    }

    foreach ($pat in $FilenamePatterns) {
        if ($base -match $pat -or $full -match "/$pat" -or $full -match "$pat/") {
            return "filename pattern '$pat'"
        }
    }
    return $null
}

$patterns = Get-BoundaryPatterns -Root $root
$contentPatterns = $patterns.Content
$filenamePatterns = $patterns.Filename

$findings = @()
$paths = Get-AuditPaths

foreach ($rel in $paths) {
    if (-not $rel) { continue }
    $reason = Test-FilenameViolation -RelativePath $rel -FilenamePatterns $filenamePatterns
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
        passed          = $passed
        staged          = [bool]$Staged
        patterns_loaded = @{
            content  = $contentPatterns.Count
            filename = $filenamePatterns.Count
        }
        findings = $findings
    } | ConvertTo-Json -Depth 5
    if (-not $passed) { exit 1 }
    exit 0
}

$scope = if ($Staged) { 'staged changes' } else { 'tracked source' }
if ($passed) {
    $patternNote = if ($contentPatterns.Count -eq 0 -and $filenamePatterns.Count -eq 0) {
        ' (no patterns configured — copy boundary-patterns.example.yaml to boundary-patterns.local.yaml)'
    } else { '' }
    Write-Host "boundary-audit: OK (no consumer identifiers in $scope)$patternNote" -ForegroundColor Green
    exit 0
}

Write-Host "boundary-audit: FAILED ($scope)" -ForegroundColor Red
foreach ($f in $findings) {
    Write-Host ("  [{0}/{1}] {2}" -f $f.kind, $f.pattern, $f.match) -ForegroundColor Yellow
}
Write-Host 'Consumer identifiers are treated as secrets — generalize, move to private overlay, or remove.' -ForegroundColor DarkGray
exit 1
