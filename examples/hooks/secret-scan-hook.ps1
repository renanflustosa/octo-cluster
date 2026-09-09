#Requires -Version 5.1
<#
.SYNOPSIS
  Example beforeShellExecution hook: block commands touching likely secret paths.
.DESCRIPTION
  Reads JSON from stdin (Cursor hook protocol). Writes JSON to stdout.
  Not enabled by default — see README.md in this directory.
#>
$ErrorActionPreference = 'Stop'

$inputRaw = [Console]::In.ReadToEnd()
if (-not $inputRaw) { exit 0 }

try {
    $payload = $inputRaw | ConvertFrom-Json
} catch {
    exit 0
}

$command = [string]$payload.command
if (-not $command) { exit 0 }

$blockedPatterns = @(
    '\.env(\.|$|\s)',
    'credentials\.json',
    '\.pem(\s|$)',
    'id_rsa',
    'secrets/'
)

foreach ($pat in $blockedPatterns) {
    if ($command -match $pat) {
        $response = @{
            permission = 'deny'
            message    = "Hook blocked command matching secret pattern: $pat"
        }
        $response | ConvertTo-Json -Compress | Write-Output
        exit 0
    }
}

$allow = @{ permission = 'allow' }
$allow | ConvertTo-Json -Compress | Write-Output
exit 0
