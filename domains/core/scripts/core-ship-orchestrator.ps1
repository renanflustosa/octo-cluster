# Ship orchestrator - runs discovered providers and repository-policy git delivery.
# Usage: core-ship-orchestrator.ps1 [-Phase all|preflight|verification|gates|git|reviews|discover]

param(
    [ValidateSet('all', 'discover', 'preflight', 'verification', 'gates', 'git', 'reviews')]
    [string]$Phase = 'all',
    [string]$RepoPath,
    [string]$Domain,
    [string]$CommitMessage,
    [string]$FeatureBranch,
    [string]$PrTitle,
    [string]$PrBodyFile,
    [switch]$SkipGit,
    [switch]$SkipCommit,
    [switch]$SkipEval,
    [switch]$SkipChildGate
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')
. (Join-Path $PSScriptRoot 'get-repo-policy.ps1')
. (Join-Path $PSScriptRoot 'resolve-execution-context.ps1')
. (Join-Path $PSScriptRoot 'discover-capabilities.ps1')
. (Join-Path $PSScriptRoot 'core-task-memory.ps1')

function ConvertTo-BranchSlug {
    param([string]$Message)
    if (-not $Message) { return '' }
    $text = $Message -replace '^(feat|fix|docs|chore|perf|refactor|test)(\([^)]+\))?:\s*', ''
    $words = @(($text -split '\s+') | Where-Object { $_ } | Select-Object -First 4)
    if ($words.Count -eq 0) { return '' }
    $slug = ($words -join '-').ToLower() -replace '[^a-z0-9-]', '' -replace '-+', '-'
    return $slug.Trim('-')
}

function Resolve-FeatureBranchFromPolicy {
    param(
        [hashtable]$GitPolicy,
        [string]$CommitMessage,
        [string]$Profile
    )
    if (-not $GitPolicy.auto_branch_from_ticket) { return $null }
    $ticket = Get-TicketFromCurrentTask -Profile $Profile
    if (-not $ticket) { return $null }
    $prefix = if ($GitPolicy.branch_prefix) { [string]$GitPolicy.branch_prefix } else { 'feat' }
    $safeTicket = ($ticket.ToLower() -replace '[^a-z0-9-]', '-' -replace '-+', '-').Trim('-')
    $slug = ConvertTo-BranchSlug -Message $CommitMessage
    if ($slug) { return "$prefix/$safeTicket-$slug" }
    return "$prefix/$safeTicket"
}

function Parse-ShipGitJson {
    param([string]$Output)
    if (-not $Output) { return $null }
    $lines = @($Output -split "`r?`n")
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i].Trim()
        if ($line.StartsWith('{') -and $line.EndsWith('}')) {
            try { return ($line | ConvertFrom-Json) } catch { }
        }
    }
    return $null
}

function Test-ShipGitSuccess {
    param(
        $GitResult,
        [hashtable]$GitPolicy
    )
    if (-not $GitResult) { return $false }
    if ($GitResult.noop -eq $true) { return $false }
    if ($GitPolicy.auto_merge -eq $true) {
        return ($GitResult.merged -eq $true)
    }
    if ($GitPolicy.pull_request -eq $true) {
        return [bool]$GitResult.pr_url
    }
    return $true
}

function Invoke-ShipProvider {
    param(
        [hashtable]$Provider,
        [hashtable]$BoundArgs = @{}
    )

    if (-not $Provider._script_path -or -not (Test-Path $Provider._script_path)) {
        throw "Provider '$($Provider.id)' script not found: $($Provider._script_path)"
    }

    Write-Host "== ship provider: $($Provider.id) ($($Provider.phase)) ==" -ForegroundColor Cyan
    $params = @('-ExecutionPolicy', 'Bypass', '-File', $Provider._script_path)
    foreach ($key in $BoundArgs.Keys) {
        $val = $BoundArgs[$key]
        if ($val -is [switch]) {
            if ($val) { $params += "-$key" }
        } else {
            $params += @("-$key", [string]$val)
        }
    }
    & powershell @params | Out-Null
    if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq '') { return 0 }
    return [int]$LASTEXITCODE
}

function Invoke-ShipPhase {
    param(
        [Parameter(Mandatory = $true)][string]$PhaseName,
        [string]$RepoPath,
        [hashtable]$ShipContext,
        [hashtable]$ExtraArgs = @{}
    )

    $providers = Get-DiscoveredCapabilities -Pipeline ship -Phase $PhaseName -RepoPath $RepoPath -ShipContext $ShipContext
    if (-not $providers -or $providers.Count -eq 0) {
        Write-Host "`[ship] no providers for phase $PhaseName" -ForegroundColor DarkGray
        return @{ exit_code = 0; tracker = 'skipped' }
    }

    $bound = @{}
    if ($SkipEval) { $bound.SkipEval = $true }
    if ($SkipChildGate) { $bound.SkipChildGate = $true }
    foreach ($key in $ExtraArgs.Keys) { $bound[$key] = $ExtraArgs[$key] }

    $trackerStatus = 'ok'
    foreach ($provider in $providers) {
        $blocking = $true
        if ($null -ne $provider.blocking) { $blocking = [bool]$provider.blocking }
        if ($PhaseName -in @('reviews', 'close')) { $blocking = $false }

        $providerArgs = @{}
        foreach ($key in $bound.Keys) { $providerArgs[$key] = $bound[$key] }
        if ($provider._legacy) { $providerArgs.SkipEval = $true }

        $code = Invoke-ShipProvider -Provider $provider -BoundArgs $providerArgs
        if ($code -ne 0) {
            if ($blocking) {
                Write-Host "`[BLOCKED] provider $($provider.id) failed (exit $code)" -ForegroundColor Red
                return @{ exit_code = $code; tracker = 'failed' }
            }
            Write-Host "`[warn] non-blocking provider $($provider.id) failed (exit $code)" -ForegroundColor Yellow
            $trackerStatus = 'failed'
        }
    }
    return @{ exit_code = 0; tracker = $trackerStatus }
}

function Invoke-ShipAutoClose {
    param(
        [string]$Ticket,
        [string]$RepoPath,
        [hashtable]$ShipContext,
        [hashtable]$GitPolicy
    )

    $profile = if ($ShipContext.memory_profile) { [string]$ShipContext.memory_profile } else { 'octo-cluster' }
    $baseBranch = if ($GitPolicy.base_branch) { [string]$GitPolicy.base_branch } else { 'main' }

    Write-Host "== ship phase: close (auto after successful git) ==" -ForegroundColor Cyan
    $closePhase = Invoke-ShipPhase -PhaseName close -RepoPath $RepoPath -ShipContext $ShipContext `
        -ExtraArgs @{ Ticket = $Ticket }
    $trackerStatus = [string]$closePhase.tracker

    $closeScript = Join-Path $PSScriptRoot 'core-close.ps1'
    & powershell -ExecutionPolicy Bypass -File $closeScript `
        -Ticket $Ticket -Profile $profile -ShipVerdict READY `
        -BaseRef $baseBranch -RepoRoot $RepoPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`[ship] auto-close memory failed (exit $LASTEXITCODE)" -ForegroundColor Red
        return @{ closed = $false; tracker = $trackerStatus }
    }

    Write-Host "`[ship] auto-closed card $Ticket (tracker=$trackerStatus)" -ForegroundColor Green
    return @{ closed = $true; tracker = $trackerStatus }
}

if (-not $RepoPath) {
    $RepoPath = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Not inside a git repository." }
}
$RepoPath = (Resolve-Path $RepoPath).Path

$shipCtx = Get-ShipExecutionContext -RepoPath $RepoPath
if ($Domain -and -not $env:AI_EXECUTION_CONTEXT) {
    Write-Host "[deprecation] -Domain is deprecated; use AI_EXECUTION_CONTEXT" -ForegroundColor Yellow
}

$runPhases = if ($Phase -eq 'all') {
    @('discover', 'preflight', 'verification', 'gates', 'git', 'reviews')
} else {
    @($Phase)
}

$skillPath = Get-DiscoveredCapabilitySkill -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx
Write-Host "SHIP_SKILL=$skillPath" -ForegroundColor DarkGray
Write-Host ("SHIP_CONTEXT=" + ($shipCtx | ConvertTo-Json -Compress)) -ForegroundColor DarkGray

$gitResult = $null
$repoPolicy = Get-RepoPolicy -RepoPath $RepoPath
$gitPolicy = $repoPolicy.git
$profile = if ($shipCtx.memory_profile) { [string]$shipCtx.memory_profile } else { 'octo-cluster' }

foreach ($phaseName in $runPhases) {
    switch ($phaseName) {
        'discover' {
            Write-Host "SHIP_REPO=$RepoPath" -ForegroundColor DarkGray
            Write-Host ("SHIP_POLICY=" + ($repoPolicy | ConvertTo-Json -Compress)) -ForegroundColor DarkGray
            $providerCount = @(Get-DiscoveredCapabilities -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx).Count
            Write-Host "SHIP_PROVIDERS=$providerCount" -ForegroundColor DarkGray
            foreach ($provider in Get-DiscoveredCapabilities -Pipeline ship -RepoPath $RepoPath -ShipContext $shipCtx) {
                Write-Host ("  provider: $($provider.id) ($($provider.phase))") -ForegroundColor DarkGray
            }
        }
        'git' {
            if ($SkipGit) {
                Write-Host "`[ship] skip git phase" -ForegroundColor Yellow
                continue
            }
            if (-not $FeatureBranch) {
                $FeatureBranch = Resolve-FeatureBranchFromPolicy `
                    -GitPolicy $gitPolicy `
                    -CommitMessage $CommitMessage `
                    -Profile $profile
                if ($FeatureBranch) {
                    Write-Host "`[ship] derived FeatureBranch=$FeatureBranch" -ForegroundColor Cyan
                }
            }
            $gitScript = Join-Path $PSScriptRoot 'core-ship-git.ps1'
            $gitArgs = @{ RepoPath = $RepoPath }
            if ($CommitMessage) { $gitArgs.CommitMessage = $CommitMessage }
            if ($FeatureBranch) { $gitArgs.FeatureBranch = $FeatureBranch }
            if ($PrTitle) { $gitArgs.PrTitle = $PrTitle }
            if ($PrBodyFile) { $gitArgs.PrBodyFile = $PrBodyFile }
            if ($SkipCommit) { $gitArgs.SkipCommit = $true }

            $params = @('-ExecutionPolicy', 'Bypass', '-File', $gitScript)
            foreach ($key in $gitArgs.Keys) {
                $val = $gitArgs[$key]
                if ($val -is [switch]) {
                    if ($val) { $params += "-$key" }
                } else {
                    $params += @("-$key", [string]$val)
                }
            }
            Write-Host "== ship phase: git (repository-policy) ==" -ForegroundColor Cyan
            $gitOut = & powershell @params 2>&1 | Out-String
            Write-Host ($gitOut.TrimEnd())
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            $gitResult = Parse-ShipGitJson -Output $gitOut
        }
        default {
            $phaseResult = Invoke-ShipPhase -PhaseName $phaseName -RepoPath $RepoPath -ShipContext $shipCtx
            if ($phaseResult.exit_code -ne 0) { exit $phaseResult.exit_code }
        }
    }
}

if ($Phase -eq 'gates' -or $Phase -eq 'all') {
    $logDir = Join-Path (Get-OctoClusterRoot) "state\logs\metrics-baseline"
    $stampFile = Join-Path $logDir "last-core-gate-pass.txt"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8
}

$autoCloseResult = $null
if (($Phase -eq 'all') -and $gitPolicy.auto_close_after_ship) {
    $ticket = Get-TicketFromCurrentTask -Profile $profile
    if ($ticket -and (Test-ShipGitSuccess -GitResult $gitResult -GitPolicy $gitPolicy)) {
        $autoCloseResult = Invoke-ShipAutoClose -Ticket $ticket -RepoPath $RepoPath `
            -ShipContext $shipCtx -GitPolicy $gitPolicy
    } elseif ($ticket -and $gitResult) {
        Write-Host "`[ship] skip auto-close: git phase did not meet success criteria" -ForegroundColor Yellow
    }
}

Write-Host "`[ok] ship orchestrator completed (phase=$Phase)" -ForegroundColor Green
if ($autoCloseResult) {
    Write-Host ("SHIP_AUTO_CLOSE=" + ($autoCloseResult | ConvertTo-Json -Compress)) -ForegroundColor Cyan
}
exit 0
