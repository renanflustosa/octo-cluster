# Context budget audit — lines/tokens for loop artifacts (domain-agnostic).
# Usage: core-context-budget.ps1 [-Profile octo-cluster]

param(
    [string]$Profile = "",
    [switch]$Json
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')

if (-not $Profile) { $Profile = Get-DefaultMemoryProfile }

$cursor = $env:OCTO_CLUSTER
$mem = Get-MemoryRoot -Profile $Profile
$cmdDir = Join-Path $cursor ".cursor\commands"
$skillDir = Join-Path $cursor ".cursor\skills"
if (-not (Test-Path $skillDir)) {
    $skillDir = Join-Path $cursor "domains\core\skills"
}

function Get-LineCount([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    return (Get-Content $Path | Measure-Object -Line).Lines
}

function Get-TokenEst([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $chars = (Get-Content $Path -Raw).Length
    return [math]::Ceiling($chars / 4)
}

$alerts = New-Object System.Collections.Generic.List[string]
$report = [ordered]@{}

$cmdLines = 0
$cmdOver = @()
foreach ($c in Get-ChildItem $cmdDir -Filter *.md -ErrorAction SilentlyContinue) {
    $n = (Get-Content $c.FullName | Measure-Object -Line).Lines
    $cmdLines += $n
    if ($n -gt 25) { $cmdOver += "$($c.BaseName):$n" }
}
$report["commands_lines"] = $cmdLines
if ($cmdOver) { $alerts.Add("command >25 lines: $($cmdOver -join ', ')") }

$skillLines = 0
foreach ($d in Get-ChildItem $skillDir -Directory -ErrorAction SilentlyContinue) {
    $sf = Join-Path $d.FullName "SKILL.md"
    if (-not (Test-Path $sf)) { continue }
    $skillLines += (Get-LineCount $sf)
}
$report["skills_lines"] = $skillLines

$topMemory = @()
$ctxDir = Join-Path $mem "context"
if (Test-Path $ctxDir) {
    foreach ($ctx in Get-ChildItem $ctxDir -Filter *.md -ErrorAction SilentlyContinue) {
        $topMemory += [pscustomobject]@{ File = "context/$($ctx.Name)"; Lines = (Get-LineCount $ctx.FullName) }
    }
}
foreach ($name in @("overview.md", "current_task.md", "project_snapshot.md")) {
    $p = Join-Path $mem $name
    if (Test-Path $p) {
        $topMemory += [pscustomobject]@{ File = $name; Lines = (Get-LineCount $p) }
    }
}
$report["top_memory"] = ($topMemory | Sort-Object Lines -Descending | Select-Object -First 5)

$manifestPath = Join-Path $mem "vector\manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $report["index_stats"] = $manifest.stats
        $report["index_updated"] = $manifest.updatedAt
        $ageDays = ((Get-Date) - [datetime]$manifest.updatedAt).TotalDays
        if ($ageDays -gt 7) {
            $alerts.Add("vector index stale (>7d)")
        }
    } catch {
        $alerts.Add("manifest.json parse error")
    }
}

if ($Json) {
    $report["alerts"] = $alerts
    $report | ConvertTo-Json -Depth 4
    exit 0
}

Write-Output "## Context budget"
Write-Output ("commands: {0} lines | skills: {1} lines" -f $report["commands_lines"], $report["skills_lines"])
Write-Output "top memory:"
$report["top_memory"] | ForEach-Object { Write-Output ("  {0}: {1} lines" -f $_.File, $_.Lines) }
if ($report["index_stats"]) {
    $s = $report["index_stats"]
    Write-Output ("index chunks: memory={0} docs={1} code={2} (updated {3})" -f $s.memory, $s.docs, $s.code, $report["index_updated"])
}
if ($alerts.Count -eq 0) {
    Write-Output "alerts: none"
} else {
    Write-Output ("alerts ({0}):" -f $alerts.Count)
    $alerts | Select-Object -First 8 | ForEach-Object { Write-Output "  - $_" }
}
exit 0
