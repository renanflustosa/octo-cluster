# Bun + context-engine helpers for core harness scripts.
# Dot-sourced from scripts/_env.ps1

function Test-BunNpmShimPath {
    param([string]$Path)
    if (-not $Path) { return $false }
    $normalized = $Path -replace '/', '\'
    return ($normalized -match '\\npm\\' -or $normalized -match 'node_modules[\\/]\.bin')
}

function Get-BunExecutable {
    $cmd = Get-Command bun -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $src = $cmd.Source
        if ((Test-Path -LiteralPath $src) -and -not (Test-BunNpmShimPath $src)) {
            return (Resolve-Path -LiteralPath $src).Path
        }
    }

    $candidates = @(
        (Join-Path $env:USERPROFILE ".bun\bin\bun.exe"),
        (Join-Path $env:LOCALAPPDATA "bun\bin\bun.exe"),
        "C:\Program Files\bun\bin\bun.exe"
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return (Resolve-Path $path).Path }
    }
    return $null
}

function Install-BunRuntime {
    if (Get-BunExecutable) { return $true }

    Write-Host "[context-engine] Bun not found; installing via bun.sh..." -ForegroundColor Yellow
    try {
        Invoke-Expression (Invoke-RestMethod -Uri "https://bun.sh/install.ps1" -UseBasicParsing)
    } catch {
        Write-Host "[context-engine] bun.sh install failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $env:PATH = "$(Join-Path $env:USERPROFILE '.bun\bin');$env:PATH"
    if (Get-BunExecutable) { return $true }

    Write-Host "[context-engine] Bun install failed. Run: irm bun.sh/install.ps1 | iex" -ForegroundColor Red
    return $false
}

function Ensure-ContextEngineDeps {
    param([switch]$AllowInstall)

    $ce = Get-ContextEngineRoot
    if (-not (Test-Path (Join-Path $ce "package.json"))) {
        throw "Missing context-engine package at $ce"
    }
    if (Test-Path (Join-Path $ce "node_modules\@lancedb\lancedb")) {
        return $ce
    }

    $bun = Get-BunExecutable
    if (-not $bun -and $AllowInstall) {
        Install-BunRuntime | Out-Null
        $bun = Get-BunExecutable
    }
    if (-not $bun) {
        throw "Bun is required for context-engine. Run: .\install.ps1  (or: powershell -c `"irm bun.sh/install.ps1|iex`")"
    }

    Write-Host "[context-engine] installing deps (LanceDB + embeddings)..." -ForegroundColor DarkGray
    Push-Location $ce
    try {
        & $bun install
        if ($LASTEXITCODE -ne 0) { throw "bun install failed in $ce (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }

    if (-not (Test-Path (Join-Path $ce "node_modules\@lancedb\lancedb"))) {
        throw "LanceDB package missing after bun install in $ce"
    }

    return $ce
}

function Invoke-ContextEngine {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$EngineArgs
    )

    if (-not $EngineArgs -or $EngineArgs.Count -eq 0) {
        throw "Invoke-ContextEngine requires bun arguments"
    }

    $null = Ensure-ContextEngineDeps
    $bun = Get-BunExecutable
    if (-not $bun) { throw "Bun executable not found. Run: .\install.ps1" }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $bun @EngineArgs 2>&1 | Out-Null
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($null -eq $LASTEXITCODE) { return 0 }
    return [int]$LASTEXITCODE
}

function Invoke-ContextEngineIncrementalIndex {
    param(
        [Parameter(Mandatory = $true)][string]$Profile,
        [string]$Kind = 'memory',
        [switch]$Incremental
    )

    $ce = Get-ContextEngineRoot
    $args = @('run', '--cwd', $ce, 'index-incremental', $Profile, '--kind', $Kind)
    if ($Incremental) { $args += '--incremental' }
    Invoke-ContextEngine @args
}
