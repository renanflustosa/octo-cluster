#Requires -Version 5.1
<#
.SYNOPSIS
  Example shell hook: block commands touching likely secret paths.
.DESCRIPTION
  Reads JSON from stdin, writes JSON to stdout. Speaks both protocols:
  - Cursor beforeShellExecution: { "command": ... } -> { "permission": "allow|deny" }
  - Claude Code PreToolUse (Bash/PowerShell): { "tool_input": { "command": ... } } -> deny JSON, or no output to defer to normal permissions
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

$isClaude = $payload.hook_event_name -eq 'PreToolUse'
$command = if ($isClaude) { [string]$payload.tool_input.command } else { [string]$payload.command }
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
        $message = "Hook blocked command matching secret pattern: $pat"
        if ($isClaude) {
            $response = @{ hookSpecificOutput = @{
                hookEventName            = 'PreToolUse'
                permissionDecision       = 'deny'
                permissionDecisionReason = $message
            } }
        } else {
            $response = @{ permission = 'deny'; message = $message }
        }
        $response | ConvertTo-Json -Compress -Depth 3 | Write-Output
        exit 0
    }
}

# Claude Code: stay silent so normal permission prompts still apply.
if (-not $isClaude) { @{ permission = 'allow' } | ConvertTo-Json -Compress | Write-Output }
exit 0
