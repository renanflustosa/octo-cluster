# Shared helpers for Cursor command hooks — stdout must be valid JSON only.

function Emit-HookJson {
    param([Parameter(Mandatory = $true)][hashtable]$Payload)
    [Console]::Out.WriteLine(($Payload | ConvertTo-Json -Compress))
}

function Emit-HookAllow {
    Emit-HookJson @{ permission = 'allow' }
}

function Emit-HookDeny {
    param(
        [Parameter(Mandatory = $true)][string]$UserMessage,
        [string]$AgentMessage
    )
    if (-not $AgentMessage) { $AgentMessage = $UserMessage }
    Emit-HookJson @{
        permission    = 'deny'
        user_message  = $UserMessage
        agent_message = $AgentMessage
    }
}

function Emit-HookAsk {
    param(
        [Parameter(Mandatory = $true)][string]$UserMessage,
        [string]$AgentMessage
    )
    if (-not $AgentMessage) { $AgentMessage = $UserMessage }
    Emit-HookJson @{
        permission    = 'ask'
        user_message  = $UserMessage
        agent_message = $AgentMessage
    }
}

function Read-HookStdinJson {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw -or -not $raw.Trim()) { return $null }
    try {
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}
