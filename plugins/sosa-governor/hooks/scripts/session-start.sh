#!/bin/bash
# SOSA Governor — SessionStart Hook
# Outputs governance context so Claude knows SOSA is active.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}"
AUDIT_DIR="$PLUGIN_ROOT/audit"
TODAY=$(date -u +"%Y-%m-%d")
AUDIT_FILE="$AUDIT_DIR/$TODAY.jsonl"

# Count today's actions
TOTAL=0
HIGH=0
DENIED=0
if [[ -f "$AUDIT_FILE" ]]; then
  TOTAL=$(wc -l < "$AUDIT_FILE" | tr -d ' ')
  HIGH=$(grep -c '"impact_level":"high"' "$AUDIT_FILE" 2>/dev/null || echo 0)
  DENIED=$(grep -c '"decision":"denied"' "$AUDIT_FILE" 2>/dev/null || echo 0)
fi

cat <<EOF
SOSA Governor is active. All MCP tool calls are classified by impact level:
- LOW: auto-approved (read-only operations)
- MEDIUM: logged and approved (internal writes)
- HIGH: requires explicit user approval (external communication, destructive actions)

Today's stats: $TOTAL tool calls, $HIGH high-impact, $DENIED denied.

Trust gradient is active — tools earn autonomy after repeated successful approvals.
Config: ${PLUGIN_ROOT}/config/
EOF

exit 0
