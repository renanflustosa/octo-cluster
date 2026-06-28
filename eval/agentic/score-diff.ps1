# Score git diff LOC (agentic benchmark metric).
# Inspired by DietrichGebert/ponytail benchmarks/agentic — counts added/deleted lines.
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [string]$BaseRef = 'HEAD~1',

    [string]$HeadRef = 'HEAD',

    [switch]$ExcludeTests
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $RepoRoot)) {
    Write-Error "RepoRoot not found: $RepoRoot"
}

Push-Location $RepoRoot
try {
    function Get-NumstatLines {
        param([string[]]$GitArgs)
        $raw = & git @GitArgs 2>&1
        return @($raw | Where-Object { $_ -match '^\d+\t' })
    }

    $lines = Get-NumstatLines @('diff', '--numstat', "${BaseRef}...${HeadRef}")
    if ($lines.Count -eq 0) {
        $lines = Get-NumstatLines @('diff', '--numstat', $BaseRef, $HeadRef)
    }
    if ($lines.Count -eq 0) {
        $lines = Get-NumstatLines @('diff', '--numstat', 'HEAD')
    }

    $added = 0
    $deleted = 0
    $filesChanged = 0

    $testPatterns = @('*_test.go', '*.spec.ts', '*.spec.tsx', '*_test.py', 'test_*.py')

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 3) { continue }

        $filePath = $parts[2]
        if ($ExcludeTests) {
            $skip = $false
            foreach ($pat in $testPatterns) {
                if ($filePath -like $pat) { $skip = $true; break }
            }
            if ($skip) { continue }
        }

        $a = $parts[0]
        $d = $parts[1]
        if ($a -ne '-' -and $a -match '^\d+$') { $added += [int]$a }
        if ($d -ne '-' -and $d -match '^\d+$') { $deleted += [int]$d }
        $filesChanged++
    }

    $result = [ordered]@{
        repo          = (Resolve-Path $RepoRoot).Path
        base_ref      = $BaseRef
        head_ref      = $HeadRef
        added         = $added
        deleted       = $deleted
        net           = $added - $deleted
        files_changed = $filesChanged
        exclude_tests = [bool]$ExcludeTests
    }

    $json = $result | ConvertTo-Json -Compress
    Write-Output $json
} finally {
    Pop-Location
}
