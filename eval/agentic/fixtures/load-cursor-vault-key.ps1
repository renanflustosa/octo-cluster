#Requires -Version 5.1
# Load Cursor API key from vault JSON via read-secret helper (CURSOR_API_KEY_FILE or -KeyFile).

function Initialize-CursorApiKeyFromVault {
    param(
        [string]$KeyFile = '',
        [string]$VaultRoot = ''
    )

    if (-not $VaultRoot) {
        $VaultRoot = [string]$env:PERSONAL_VAULT
        if (-not $VaultRoot) { $VaultRoot = [string]$env:PERSONAL_VAULT_ROOT }
    }
    if (-not $VaultRoot) {
        throw 'BLOCKED: set PERSONAL_VAULT or PERSONAL_VAULT_ROOT'
    }

    $readSecret = Join-Path $VaultRoot 'scripts\read-secret.ps1'
    if (-not (Test-Path -LiteralPath $readSecret)) {
        throw 'BLOCKED: vault read-secret.ps1 not found'
    }
    . $readSecret

    if (-not $KeyFile) {
        $KeyFile = [string]$env:CURSOR_API_KEY_FILE
    }
    if (-not $KeyFile) {
        throw 'BLOCKED: set CURSOR_API_KEY_FILE or pass -KeyFile'
    }

    if (-not (Test-Path -LiteralPath $KeyFile)) {
        throw 'BLOCKED: key file missing'
    }

    $key = Get-VaultSecretValue -Path $KeyFile
    if (-not $key -or $key -notmatch '^crsr') {
        throw 'BLOCKED: invalid key format (expected crsr prefix)'
    }
    return $key
}
