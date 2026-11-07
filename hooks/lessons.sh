#!/usr/bin/env bash
# Hook entry for scripts/lessons.ps1. pwsh takes ~0.7 s to start, so this prefilter starts it only
# when a lesson or a pending failure can be involved; most Bash calls exit here in a few ms.
event="$1"
data="${CLAUDE_PLUGIN_DATA:-$HOME/.octo-cluster}"
input=$(cat)

matches_lesson() { [ -s "$data/keys.txt" ] && printf '%s' "$input" | grep -qiEf "$data/keys.txt"; }

case "$event" in
  fail) ;;
  pre) matches_lesson || exit 0 ;;
  ok) [ -f "$data/pending" ] || matches_lesson || exit 0 ;;
  edit) [ -f "$data/pending" ] || exit 0 ;;
  *) echo "lessons.sh: unknown event '$event'" >&2; exit 1 ;;
esac

# pwsh is optional (README prerequisites); without it the feature is off.
command -v pwsh >/dev/null 2>&1 || exit 0
root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
printf '%s' "$input" | pwsh -NoProfile -NonInteractive -File "$root/scripts/lessons.ps1" "$event"
