#!/usr/bin/env bash
set -euo pipefail

ROOT="${OCTO_CLUSTER:?OCTO_CLUSTER must be set}"
cd "$ROOT"

if ! command -v rg >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ripgrep
fi

echo "[devcontainer] context-engine deps..."
cd engine/context-engine
bun install
cd "$ROOT"

echo "[devcontainer] sync .cursor/..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/sync-cursor.ps1

echo "[devcontainer] git hooks..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1

mkdir -p state/memory state/logs/metrics-baseline state/metrics

echo "[devcontainer] seed + index memory..."
cd engine/context-engine
bun run seed-profile octo-cluster
bun run index-incremental octo-cluster --kind memory --incremental
bun run validate octo-cluster
cd "$ROOT"

echo "[devcontainer] productivity audit..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/productivity-audit.ps1

echo "[devcontainer] bootstrap OK — run 'gh auth login' once for PR flow"
