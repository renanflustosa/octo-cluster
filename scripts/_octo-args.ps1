# Shared argument merging and in-process script invocation for Octo entry points.
# Dot-source from octo.ps1, octo-domain.ps1, invoke-pipeline.ps1, invoke-domain-script.ps1

function Merge-OctoScriptArgs {
    param(
        [hashtable]$Base = @{},
        [string]$ScriptArgsJson = '',
        [hashtable]$Flat = @{}
    )

    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }

    if ($ScriptArgsJson) {
        try {
            $parsed = ConvertFrom-Json $ScriptArgsJson
            foreach ($prop in $parsed.PSObject.Properties) {
                $result[$prop.Name] = $prop.Value
            }
        } catch {
            throw "Invalid -ScriptArgsJson: $($_.Exception.Message)"
        }
    }

    foreach ($key in $Flat.Keys) {
        $val = $Flat[$key]
        if ($val -is [switch]) {
            if ($val) { $result[$key] = $true }
            continue
        }
        if ($null -ne $val -and [string]$val -ne '') {
            $result[$key] = $val
        }
    }

    return $result
}

function Invoke-OctoBoundScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [hashtable]$BoundArgs = @{}
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Script not found: $Path"
    }

    $params = @{}
    foreach ($key in $BoundArgs.Keys) {
        $val = $BoundArgs[$key]
        if ($val -is [switch]) {
            if ($val) { $params[$key] = $true }
        } else {
            $params[$key] = $val
        }
    }

    & $Path @params
}
