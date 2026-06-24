#!/usr/bin/env bash
# Switch between Max (Opus-heavy) and Economy (Pro-plan friendly) model tiers.
#
# This edits the `mode:` line in orchestration.config.yaml, then regenerates
# .claude/agents/ from the config via generate-agents.py.
set -euo pipefail

MODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG="$REPO_ROOT/orchestration.config.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "Error: config not found at $CONFIG"
  exit 1
fi

case "$MODE" in
  max)
    # sed -i '' for macOS, sed -i for GNU sed
    sed -i '' 's/^mode: .*/mode: max/' "$CONFIG" 2>/dev/null || sed -i 's/^mode: .*/mode: max/' "$CONFIG"
    echo "🔥 Switched to Max mode (Opus-heavy — best quality, higher token usage)"
    ;;
  economy|eco|pro)
    sed -i '' 's/^mode: .*/mode: economy/' "$CONFIG" 2>/dev/null || sed -i 's/^mode: .*/mode: economy/' "$CONFIG"
    echo "💰 Switched to Economy mode (Pro-plan friendly — Sonnet/Haiku, lower cost)"
    ;;
  *)
    echo "Usage: ./scripts/switch-mode.sh <max|economy>"
    echo ""
    echo "  max       Opus-heavy. For Claude Max plans."
    echo "  economy   Sonnet/Haiku. For Claude Pro plans."
    exit 1
    ;;
esac

# Regenerate agents from the updated config
"$SCRIPT_DIR/generate-agents.py"
echo "ℹ️  Restart Claude Code so it reloads the regenerated agent definitions."
