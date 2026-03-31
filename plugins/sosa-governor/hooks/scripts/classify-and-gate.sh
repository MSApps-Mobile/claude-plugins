#!/bin/bash
# SOSA Governor — PreToolUse Hook
# Classifies MCP tool calls by impact level and gates high-impact actions.
#
# Exit codes:
#   0 = allow (low/medium impact, or trusted high-impact)
#   2 = deny  (high-impact, not yet trusted)
#
# Reads JSON from stdin with: tool_name, tool_input, session_id, transcript_path

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}"
REGISTRY="$PLUGIN_ROOT/config/impact-registry.json"
TRUST_STATE="$PLUGIN_ROOT/config/trust-state.json"
AUDIT_DIR="$PLUGIN_ROOT/audit"
mkdir -p "$AUDIT_DIR"

# Read hook input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_INPUT_SUMMARY=$(echo "$INPUT" | jq -c '.tool_input // {}' | head -c 500)

# Skip non-MCP tools (let built-in tools through)
if [[ ! "$TOOL_NAME" =~ ^mcp__ ]]; then
  exit 0
fi

# --- CLASSIFICATION ---
# Check tool against impact registry
classify_tool() {
  local tool="$1"
  local level

  # Check high-impact tools
  level=$(jq -r --arg tool "$tool" '
    .tools.high[]? | select(.pattern as $p | $tool | test($p)) | "high"
  ' "$REGISTRY" 2>/dev/null | head -1)
  if [[ -n "$level" ]]; then echo "high"; return; fi

  # Check medium-impact tools
  level=$(jq -r --arg tool "$tool" '
    .tools.medium[]? | select(.pattern as $p | $tool | test($p)) | "medium"
  ' "$REGISTRY" 2>/dev/null | head -1)
  if [[ -n "$level" ]]; then echo "medium"; return; fi

  # Check low-impact tools
  level=$(jq -r --arg tool "$tool" '
    .tools.low[]? | select(.pattern as $p | $tool | test($p)) | "low"
  ' "$REGISTRY" 2>/dev/null | head -1)
  if [[ -n "$level" ]]; then echo "low"; return; fi

  # Default
  jq -r '.default_level // "medium"' "$REGISTRY" 2>/dev/null
}

# Get reason for classification
get_reason() {
  local tool="$1"
  local level="$2"
  jq -r --arg tool "$tool" --arg level "$level" '
    .tools[$level][]? | select(.pattern as $p | $tool | test($p)) | .reason
  ' "$REGISTRY" 2>/dev/null | head -1
}

IMPACT_LEVEL=$(classify_tool "$TOOL_NAME")
REASON=$(get_reason "$TOOL_NAME" "$IMPACT_LEVEL")

# --- AUDIT LOG ---
# Always log the tool call regardless of level
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date -u +"%Y-%m-%d")
AUDIT_FILE="$AUDIT_DIR/$TODAY.jsonl"

log_entry() {
  local decision="$1"
  jq -n \
    --arg ts "$TIMESTAMP" \
    --arg sid "$SESSION_ID" \
    --arg tool "$TOOL_NAME" \
    --arg level "$IMPACT_LEVEL" \
    --arg reason "$REASON" \
    --arg decision "$decision" \
    --arg input "$TOOL_INPUT_SUMMARY" \
    '{timestamp: $ts, session_id: $sid, tool: $tool, impact_level: $level, reason: $reason, decision: $decision, input_summary: $input}' \
    >> "$AUDIT_FILE" 2>/dev/null
}

# --- TRUST GRADIENT ---
get_trust_score() {
  local tool="$1"
  jq -r --arg tool "$tool" '.tools[$tool] // 0' "$TRUST_STATE" 2>/dev/null
}

update_trust() {
  local tool="$1"
  local delta="$2"
  local current
  current=$(get_trust_score "$tool")
  local new_score
  new_score=$(echo "$current + $delta" | bc 2>/dev/null || echo "$current")

  # Update trust state (atomic write via temp file)
  local tmp
  tmp=$(mktemp)
  jq --arg tool "$tool" --argjson score "$new_score" \
    '.tools[$tool] = $score' "$TRUST_STATE" > "$tmp" 2>/dev/null && \
    mv "$tmp" "$TRUST_STATE" 2>/dev/null || rm -f "$tmp"
}

# --- DECISION ---
case "$IMPACT_LEVEL" in
  low)
    log_entry "allow"
    exit 0
    ;;
  medium)
    log_entry "allow_logged"
    exit 0
    ;;
  high)
    TRUST=$(get_trust_score "$TOOL_NAME")
    THRESHOLD=$(jq -r '.trust_threshold // 1.0' "$TRUST_STATE" 2>/dev/null)

    # Check if tool has earned trust
    if (( $(echo "$TRUST >= $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
      log_entry "allow_trusted"
      exit 0
    fi

    # HIGH IMPACT + NOT TRUSTED → DENY
    log_entry "denied"

    echo "SOSA Governor: HIGH-IMPACT action blocked." >&2
    echo "" >&2
    echo "Tool: $TOOL_NAME" >&2
    echo "Impact: $IMPACT_LEVEL" >&2
    echo "Reason: $REASON" >&2
    echo "Trust score: $TRUST (threshold: $THRESHOLD)" >&2
    echo "" >&2
    echo "To approve this action, ask the user for explicit confirmation." >&2
    echo "After approval, the trust score will increase for future auto-approval." >&2

    exit 2
    ;;
esac
