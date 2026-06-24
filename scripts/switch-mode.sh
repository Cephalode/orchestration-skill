#!/usr/bin/env bash
# Switch between Max (Opus-heavy) and Economy (Pro-plan friendly) model tiers
set -euo pipefail

MODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

case "$MODE" in
  max|max-mode)
    SOURCE="$REPO_ROOT/.claude/agents-max"
    echo "🔥 Switching to Max mode (Opus-heavy — best quality, higher token usage)"
    ;;
  economy|eco|pro)
    SOURCE="$REPO_ROOT/.claude/agents-economy"
    echo "💰 Switching to Economy mode (Pro-plan friendly — Sonnet/Haiku, lower cost)"
    ;;
  *)
    echo "Usage: ./scripts/switch-mode.sh <max|economy>"
    echo ""
    echo "Modes:"
    echo "  max       Opus for planning-lead, eng-worker-alpha, reviewer. Sonnet for eng-worker-beta, validator."
    echo "  economy   Sonnet for planning-lead, eng-worker-alpha, reviewer, validator. Haiku for eng-worker-beta."
    exit 1
    ;;
esac

if [ ! -d "$SOURCE" ]; then
  echo "Error: $SOURCE not found"
  exit 1
fi

# Copy the selected mode's agents into the active .claude/agents/
cp "$SOURCE"/*.md "$AGENTS_DIR/"
echo "✅ Active agents updated. Current .claude/agents/:"
ls -1 "$AGENTS_DIR"/*.md | xargs -n1 basename
