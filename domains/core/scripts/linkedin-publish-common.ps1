# Shared helpers for LinkedIn publish preview and invoke (domain-agnostic).
# Dot-source from show-linkedin-preview.ps1 and invoke-linkedin-publish.ps1.

function Resolve-LinkedInManifestPath {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$Root
    )
    if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
        return $ManifestPath
    }
    return Join-Path $Root ($ManifestPath -replace '/', '\')
}

function Get-PostHookLine {
    param([string]$PostText)
    if (-not $PostText) { return '' }
    $line = ($PostText -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    return [string]$line.Trim()
}

function Get-ImageBasename {
    param(
        [string]$ImagePath,
        [string]$Root
    )
    if (-not $ImagePath) { return '' }
    $resolved = if ([System.IO.Path]::IsPathRooted($ImagePath)) {
        $ImagePath
    } else {
        Join-Path $Root ($ImagePath -replace '/', '\')
    }
    return [System.IO.Path]::GetFileName($resolved)
}

function Get-LinkedInPublishProviders {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][hashtable]$ShipContext
    )

    $providers = @(Get-DiscoveredCapabilities -Pipeline linkedin -Phase publish -RepoPath $RepoPath -ShipContext $ShipContext)
    if ($providers.Count -gt 0) { return $providers }

    $privateRoot = Join-Path $WorkspaceRoot 'capabilities\_private'
    if (-not (Test-Path $privateRoot)) { return @() }

    $seen = @{}
    $found = New-Object System.Collections.ArrayList
    $activeRepoName = if ($ShipContext.active_repo) { [string]$ShipContext.active_repo } else { 'octo-cluster' }

    foreach ($packDir in Get-ChildItem -Path $privateRoot -Directory -ErrorAction SilentlyContinue) {
        $packId = $packDir.Name
        $manifestFile = Join-Path $packDir.FullName 'linkedin\manifest.yaml'
        if (-not (Test-Path $manifestFile)) { continue }

        $target = New-Object System.Collections.ArrayList
        Add-CapabilityManifestProviders -PackId $packId -Pipeline linkedin -Phase publish `
            -RepoPath $RepoPath -ShipContext $ShipContext -ActiveRepoName $activeRepoName `
            -WorkspaceRoot $WorkspaceRoot -SeenIds $seen -TargetList $target
        foreach ($p in $target) { [void]$found.Add($p) }
    }

    return @($found)
}

function Get-LinkedInTokenPreflight {
    $tokenFile = [string]$env:LINKEDIN_TOKEN_FILE
    if (-not $tokenFile) {
        return @{
            ok     = $false
            reason = 'LINKEDIN_TOKEN_FILE not set'
        }
    }
    if (-not (Test-Path $tokenFile)) {
        return @{
            ok     = $false
            reason = 'LINKEDIN_TOKEN_FILE path does not exist'
        }
    }

    $vaultRoot = [string]$env:PERSONAL_VAULT
    if (-not $vaultRoot) { $vaultRoot = [string]$env:PERSONAL_VAULT_ROOT }
    $readSecret = $null
    if ($vaultRoot) {
        $candidate = Join-Path $vaultRoot 'scripts\read-secret.ps1'
        if (Test-Path -LiteralPath $candidate) { $readSecret = $candidate }
    }
    if ($readSecret) {
        . $readSecret
        $check = Test-VaultSecretFile -FilePath $tokenFile
        if (-not $check.ok) {
            return @{ ok = $false; reason = [string]$check.reason }
        }
        return @{ ok = $true; reason = '' }
    }

    return @{
        ok     = $true
        reason = ''
    }
}

function Get-LinkedInPublishPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][hashtable]$ShipContext
    )

    $providers = @(Get-LinkedInPublishProviders -WorkspaceRoot $WorkspaceRoot -RepoPath $RepoPath -ShipContext $ShipContext)
    if ($providers.Count -eq 0) {
        return @{
            ok         = $false
            reason     = 'no publish provider found'
            providerId = ''
        }
    }

    $provider = $providers | Where-Object { $_.id } | Select-Object -First 1
    if (-not $provider._script_path -or -not (Test-Path $provider._script_path)) {
        return @{
            ok         = $false
            reason     = "provider '$($provider.id)' script missing"
            providerId = [string]$provider.id
        }
    }

    $tokenCheck = Get-LinkedInTokenPreflight
    if (-not $tokenCheck.ok) {
        return @{
            ok         = $false
            reason     = [string]$tokenCheck.reason
            providerId = [string]$provider.id
        }
    }

    return @{
        ok         = $true
        reason     = ''
        providerId = [string]$provider.id
    }
}

function Invoke-LinkedInPublishLocale {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Provider,
        [Parameter(Mandatory = $true)][string]$ManifestPathResolved,
        [Parameter(Mandatory = $true)][ValidateSet('en', 'pt')][string]$Locale
    )

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Write-Host "== linkedin publish provider: $($Provider.id) (locale=$Locale) ==" -ForegroundColor Cyan
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Provider._script_path `
            -ManifestPath $ManifestPathResolved -Locale $Locale -Confirm 2>&1
        $code = if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq '') { 0 } else { [int]$LASTEXITCODE }
        $text = ($output | Out-String).Trim()
        $errorMsg = ''
        if ($code -ne 0) {
            $errorMsg = if ($text) { ($text -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1) } else { "exit $code" }
            if ($errorMsg -match 'Write-Error|WriteErrorException') {
                $errorMsg = ($text -split "`r?`n" | Where-Object { $_ -match ':' } | Select-Object -Last 1)
                if ($errorMsg -match ':\s*(.+)') { $errorMsg = $Matches[1].Trim() }
            }
        }
        return @{
            ok       = ($code -eq 0)
            exitCode = $code
            error    = $errorMsg
            output   = $text
            provider = [string]$Provider.id
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}
