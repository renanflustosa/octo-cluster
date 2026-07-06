#!/usr/bin/env bash
# Bootstrap octo-cluster on Linux/macOS (native host). Harness runs via pwsh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OCTO_CLUSTER="$ROOT"
export AI_EXECUTION_CONTEXT="${AI_EXECUTION_CONTEXT:-platform}"

echo "OCTO_CLUSTER=$OCTO_CLUSTER"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[install.sh] missing: $1 — install via apt/curl or use Dev Container (see docs/guides/onboarding.md)" >&2
    exit 1
  fi
}

need git
need pwsh
need bun
need gh
need rg

cd "$ROOT"

echo "[install.sh] sync .cursor/..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/sync-cursor.ps1

echo "[install.sh] git hooks..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1

mkdir -p state/memory state/logs/metrics-baseline state/metrics

echo "[install.sh] context-engine deps + memory index..."
cd engine/context-engine
bun install
bun run seed-profile octo-cluster
bun run index-incremental octo-cluster --kind memory --incremental
bun run validate octo-cluster
cd "$ROOT"

echo "[install.sh] productivity audit..."
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/productivity-audit.ps1

cat <<EOF

Done. Next steps:
  1. export OCTO_CLUSTER=$ROOT  (add to ~/.bashrc for persistence)
  2. gh auth login   (once, for PRs/issues)
  3. ./scripts/octo -Pipeline scan -Action discover

Dev Container is the canonical path on all hosts — see docs/guides/onboarding.md

EOF
