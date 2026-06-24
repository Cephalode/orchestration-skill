#!/usr/bin/env bash
# Switch between Max (Opus-heavy) and Economy (Pro-plan friendly) model tiers.
# This edits the `model:` field in each .claude/agents/*.md file in-place.
# After switching, restart your Claude Code session (or run /agents) to reload.
set -euo pipefail

MODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

# Model assignments per agent per mode
# Format: "agent-filename:max-model:economy-model"
AGENT_MODELS=(
  "planning-lead:opus:sonnet"
  "eng-worker-alpha:opus:sonnet"
  "eng-worker-beta:sonnet:haiku"
  "validator:sonnet:sonnet"
  "reviewer:opus:sonnet"
  "coordinator:opus:sonnet"
)

usage() {
  echo "Usage: ./scripts/switch-mode.sh <max|economy>"
  echo ""
  echo "Modes:"
  echo "  max       Opus for planning, alpha worker, reviewer. Sonnet for beta worker, validator."
  echo "  economy   Sonnet for planning, alpha, reviewer, validator. Haiku for beta worker."
  echo ""
  echo "To customize further, edit the model: field in any .claude/agents/*.md file directly."
  exit 1
}

case "$MODE" in
  max)       echo "🔥 Switching to Max mode (Opus-heavy)"; MODE_IDX=1 ;;
  economy|eco|pro) echo "💰 Switching to Economy mode (Pro-plan friendly)"; MODE_IDX=2 ;;
  *)         usage ;;
esac

for entry in "${AGENT_MODELS[@]}"; do
  IFS=':' read -r agent max_model eco_model <<< "$entry"
  
  if [ "$MODE_IDX" -eq 1 ]; then
    MODEL="$max_model"
  else
    MODEL="$eco_model"
  fi
  
  FILE="$AGENTS_DIR/${agent}.md"
  if [ -f "$FILE" ]; then
    # macOS sed needs -i '' (empty backup suffix), Linux sed needs -i alone
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^model: .*/model: ${MODEL}/" "$FILE"
    else
      sed -i "s/^model: .*/model: ${MODEL}/" "$FILE"
    fi
    echo "  ✅ ${agent} → ${MODEL}"
  else
    echo "  ⚠️  ${agent}.md not found, skipping"
  fi
done

echo ""
echo "Done. Restart Claude Code (or run /agents) to apply changes."
