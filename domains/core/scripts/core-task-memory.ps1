# Shared helpers for current_task.md (CARD, etc.). Domain-agnostic.
param()

function Get-TicketFromCurrentTask {
    param([string]$Profile = 'octo-cluster')
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    $mem = Get-MemoryRoot -Profile $Profile
    $taskFile = Join-Path $mem 'current_task.md'
    if (-not (Test-Path $taskFile)) { return $null }
    $raw = Get-Content $taskFile -Raw
    if ($raw -match 'CARD:\s*(\S+)') {
        $card = $Matches[1].Trim()
        if ($card -and $card -ne '(none)') { return $card }
    }
    return $null
}

function Get-GoalFromCurrentTask {
    param([string]$Profile = 'octo-cluster')
    . (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
    $mem = Get-MemoryRoot -Profile $Profile
    $taskFile = Join-Path $mem 'current_task.md'
    if (-not (Test-Path $taskFile)) { return $null }
    $raw = Get-Content $taskFile -Raw
    if ($raw -match 'GOAL:\s*(.+)') { return $Matches[1].Trim() }
    return $null
}
