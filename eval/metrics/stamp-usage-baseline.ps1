# Stamp Cursor usage baseline at /scan (delta scan→close).
param(
    [Parameter(Mandatory = $true)]
    [string]$Ticket,

    [string]$Profile = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '..\..\scripts\_load-env.ps1')

if (-not $Profile) {
    $ctx = Get-ShipExecutionContext
    $Profile = if ($ctx.memory_profile) { [string]$ctx.memory_profile } else { 'octo-cluster' }
}

$memRoot = Get-MemoryRoot -Profile $Profile
New-Item -ItemType Directory -Force -Path $memRoot | Out-Null
$outPath = Join-Path $memRoot 'usage-baseline.json'

$startedAt = (Get-Date).ToUniversalTime()
$startedMs = [long]([DateTimeOffset]$startedAt).ToUnixTimeMilliseconds()

$baseline = [ordered]@{
    ticket          = $Ticket
    profile         = $Profile
    started_at      = $startedAt.ToString('o')
    started_at_ms   = $startedMs
    cycle_event_count = $null
}

$usageScript = Join-Path $PSScriptRoot 'cursor-usage.ps1'
if (Test-Path $usageScript) {
    try {
        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $usageScript -SummaryOnly 2>$null
        if ($raw) {
            $parsed = ($raw | Out-String).Trim() | ConvertFrom-Json
            if ($parsed.ok -and $parsed.summary) {
                $baseline['usage_summary'] = $parsed.summary
            }
        }
    } catch {
        Write-Host "[stamp-usage-baseline] usage-summary skipped: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

$baseline | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "[stamp-usage-baseline] $Ticket -> $outPath (ms=$startedMs)" -ForegroundColor DarkGray
exit 0
