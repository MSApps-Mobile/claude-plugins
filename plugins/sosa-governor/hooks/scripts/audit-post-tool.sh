#!/bin/bash
# SOSA Governor — PostToolUse Hook
# Logs completed tool calls and updates trust scores for approved high-impact actions.
#
# When Claude successfully executes a high-impact tool (meaning the user approved it
# after the PreToolUse hook denied it), we increase the trust score for that tool.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}"
TRUST_STATE="$PLUGIN_ROOT/config/trust-state.json"
REGISTRY="$PLUGIN_ROOT/config/impact-registry.json"
AUDIT_DIR="$PLUGIN_ROOT/audit"
mkdir -p "$AUDIT_DIR"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Skip non-MCP tools
if [[ ! "$TOOL_NAME" =~ ^mcp__ ]]; then
  exit 0
fi

# Classify the tool
classify_tool() {
  local tool="$1"
  local level

  level=$(jq -r --arg tool "$tool" '
    .tools.high[]? | select(.pattern as $p | $tool | test($p)) | "high"
  ' "$REGISTRY" 2>/dev/null | head -1)
  if [[ -n "$level" ]]; then echo "high"; return; fi

  level=$(jq -r --arg tool "$tool" '
    .tools.medium[]? | select(.pattern as $p | $tool | test($p)) | "medium"
  ' "$REGISTRY" 2>/dev/null | head -1)
  if [[ -n "$level" ]]; then echo "medium"; return; fi

  echo "low"
}

IMPACT_LEVEL=$(classify_tool "$TOOL_NAME")

# Log completion
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date -u +"%Y-%m-%d")
AUDIT_FILE="$AUDIT_DIR/$TODAY.jsonl"

jq -n \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg level "$IMPACT_LEVEL" \
  --arg event "completed" \
  '{timestamp: $ts, session_id: $sid, tool: $tool, impact_level: $level, event: $event}' \
  >> "$AUDIT_FILE" 2>/dev/null

# If high-impact tool completed successfully, user must have approved it.
# Increase trust score.
if [[ "$IMPACT_LEVEL" == "high" ]]; then
  GAIN=$(jq -r '.gain_on_approval // 0.1' "$TRUST_STATE" 2>/dev/null)
  CURRENT=$(jq -r --arg tool "$TOOL_NAME" '.tools[$tool] // 0' "$TRUST_STATE" 2>/dev/null)
  NEW_SCORE=$(echo "$CURRENT + $GAIN" | bc 2>/dev/null || echo "$CURRENT")

  tmp=$(mktemp)
  jq --arg tool "$TOOL_NAME" --argjson score "$NEW_SCORE" \
    '.tools[$tool] = $score' "$TRUST_STATE" > "$tmp" 2>/dev/null && \
    mv "$tmp" "$TRUST_STATE" 2>/dev/null || rm -f "$tmp"
fi

exit 0
