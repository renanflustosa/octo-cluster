#Requires -Version 5.1
# POC: compact OKF-style index from Markdown frontmatter (type:).
# See docs/adr/ADR-005-okf-session-index.md. Does not wire Cursor hooks.
param(
    [int]$MaxConcepts = 60,
    [string]$FixturesRoot = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = [string](Resolve-Path (Join-Path $PSScriptRoot '..\..'))
if (-not $FixturesRoot) {
    $FixturesRoot = Join-Path $repoRoot 'engine\context-engine\fixtures\profiles'
}

$outLines = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $FixturesRoot)) {
    $outLines.Add("OKF index: fixtures root missing: $FixturesRoot")
    $outLines.Add('Knowledge: 0 documented concepts')
    $outLines | ForEach-Object { Write-Output $_ }
    exit 0
}

function Get-OkfFrontmatter {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    if ($raw -notmatch '(?s)\A---\r?\n(.*?)\r?\n---') { return $null }
    $block = $Matches[1]
    if ($block -notmatch '(?m)^type:\s*(.+)$') { return $null }
    $type = $Matches[1].Trim().Trim('"').Trim("'")
    $title = ''
    $description = ''
    if ($block -match '(?m)^title:\s*(.+)$') {
        $title = $Matches[1].Trim().Trim('"').Trim("'")
    }
    if ($block -match '(?m)^description:\s*(.+)$') {
        $description = $Matches[1].Trim().Trim('"').Trim("'")
    }
    return @{
        Type        = $type
        Title       = $title
        Description = $description
    }
}

$files = @(Get-ChildItem -LiteralPath $FixturesRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue)
$concepts = @()

foreach ($f in $files) {
    $meta = Get-OkfFrontmatter -Path $f.FullName
    if ($null -eq $meta) { continue }
    $rel = $f.FullName
    if ($rel.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $rel.Substring($repoRoot.Length).TrimStart('\')
    }
    $rel = $rel.Replace('\', '/')
    $summary = $meta.Description
    if ([string]::IsNullOrWhiteSpace($summary)) { $summary = $meta.Title }
    if ([string]::IsNullOrWhiteSpace($summary)) { $summary = '(no description)' }
    $concepts += [pscustomobject]@{
        Rel     = $rel
        Type    = $meta.Type
        Summary = $summary
    }
}

$count = $concepts.Count
$outLines.Add('<okf-poc>')
$outLines.Add("Knowledge: $count documented concept(s) in fixtures")
$outLines.Add('')

$shown = 0
foreach ($c in $concepts) {
    if ($shown -ge $MaxConcepts) { break }
    $outLines.Add(('  {0,-48} [{1}] - {2}' -f $c.Rel, $c.Type, $c.Summary))
    $shown++
}

if ($count -gt $MaxConcepts) {
    $more = $count - $MaxConcepts
    $outLines.Add("  ... truncated ($more more)")
}

$outLines.Add('</okf-poc>')
$outLines | ForEach-Object { Write-Output $_ }
exit 0
