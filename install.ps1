#Requires -Version 5.1
<#
.SYNOPSIS
  Minimal octo-cluster setup for Win11 + Cursor / Claude Code.
  Installs the repository git hooks (pre-commit / pre-push boundary gates).
  Optional: links the shared skills into another folder for Claude Code.
.PARAMETER ClaudeSkillsTo
  Folder whose .claude/skills/ receives one junction per octo-cluster skill
  (e.g. a multi-repo hub folder, or $HOME for every Claude Code project).
  Cursor also loads ~/.claude/skills: linking into $HOME can duplicate skills in Cursor.
.EXAMPLE
  pwsh -File install.ps1
  pwsh -File install.ps1 -ClaudeSkillsTo ..\my-hub
#>
param([string]$ClaudeSkillsTo)

$ErrorActionPreference = 'Stop'
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = $PSScriptRoot }
Set-Location $root

if (-not (Test-Path (Join-Path $root '.githooks'))) {
    throw "Missing hooks directory: $root/.githooks"
}

git config core.hooksPath .githooks
Write-Host "Installed git hooksPath -> .githooks (pre-commit + pre-push run boundary-audit)." -ForegroundColor Green

if ($ClaudeSkillsTo) {
    $dest = Join-Path (Resolve-Path $ClaudeSkillsTo) '.claude/skills'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($skill in Get-ChildItem (Join-Path $root '.claude/skills') -Directory) {
        $link = Join-Path $dest $skill.Name
        if (Test-Path $link) { Write-Host "Skip (exists): $link" -ForegroundColor DarkGray; continue }
        New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
        Write-Host "Linked skill: $link" -ForegroundColor Green
    }
}

Write-Host "Optional: copy boundary-patterns.example.yaml -> boundary-patterns.local.yaml for custom boundary patterns." -ForegroundColor DarkGray
Write-Host ""
Write-Host "Done. Next: open the repo in Cursor or Claude Code and use /prompt, /ship, /debug, /pr-review."
