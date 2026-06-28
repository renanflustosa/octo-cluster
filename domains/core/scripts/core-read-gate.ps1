# Suggest map/diff before full Read on large files.
# Usage: core-read-gate.ps1 -Path <file> [-RepoRoot ...] [-LineThreshold 80]

param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$RepoRoot = "",
    [int]$LineThreshold = 80,
    [string]$DiffScript = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')

$coreScripts = Get-CoreScriptsRoot

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

$resolved = (Resolve-Path $Path).Path
$baseName = Split-Path $resolved -Leaf
$isTest = $baseName -match '\.(test|spec|integration)\.(ts|tsx|js|jsx)$'

if ($isTest) {
    Write-Output "# read-gate: test file - Read allowed without map"
    exit 0
}

$lineCount = @(Get-Content -LiteralPath $resolved -ErrorAction Stop).Count
$emit = @()

if ($lineCount -gt $LineThreshold) {
    Write-Output "# read-gate: $baseName has $lineCount lines (>$LineThreshold) - prefer map before Read"
    Write-Output ""
    & powershell -ExecutionPolicy Bypass -File (Join-Path $coreScripts "core-map.ps1") -Path $resolved
    $emit += "map"
}

if (-not $RepoRoot) {
    $dir = Split-Path $resolved -Parent
    for ($i = 0; $i -lt 8; $i++) {
        if (Test-Path (Join-Path $dir ".git")) {
            $RepoRoot = $dir
            break
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
}

if ($DiffScript -and (Test-Path $DiffScript) -and $RepoRoot -and (Test-Path (Join-Path $RepoRoot ".git"))) {
    Push-Location $RepoRoot
    try {
        $dirty = git status --porcelain -- $resolved 2>$null
        if ($dirty) {
            Write-Output ""
            Write-Output "# read-gate: file has uncommitted changes - delta context:"
            & powershell -ExecutionPolicy Bypass -File $DiffScript -RepoRoot $RepoRoot -Delta
            $emit += "delta"
        }
    } finally { Pop-Location }
}

if ($emit.Count -eq 0) {
    Write-Output "# read-gate: OK - small file ($lineCount lines), Read allowed"
}

exit 0
