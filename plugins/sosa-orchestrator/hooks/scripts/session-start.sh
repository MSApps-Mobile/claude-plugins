#!/bin/bash
# SOSA Orchestrator — Session Start Hook
# Shows a quick budget snapshot when a new session begins.
# Lightweight: just reads config and prints status. Full orchestration
# happens when the skill is invoked.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$PLUGIN_ROOT/config"

# Find SOSA Governor budgets.json
GOVERNOR_BUDGETS=""
for f in /sessions/*/mnt/.remote-plugins/plugin_*/config/budgets.json; do
    if [ -f "$f" ]; then
        GOVERNOR_BUDGETS="$f"
        break
    fi
done

DATE=$(date +%Y-%m-%d)

echo ""
echo "🎯 SOSA Orchestrator Active"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$GOVERNOR_BUDGETS" ]; then
    # Extract daily budget total from budgets.json
    DAILY=$(python3 -c "
import json
with open('$GOVERNOR_BUDGETS') as f:
    b = json.load(f)
ab = b.get('agent_budgets', {})
total = sum(v.get('daily', 0) for v in ab.values())
reserve = total * b.get('daily_reserve_percent', 15) / 100
print(f'{int(total - reserve):,}')
" 2>/dev/null || echo "unknown")
    echo "📊 Daily budget: ${DAILY} tokens (date: $DATE)"
else
    echo "⚠️  SOSA Governor not found — budget tracking limited to estimates"
fi

# Check for pending scheduled tasks
echo ""
echo "💡 Say \"orchestrate\" or \"prioritize tasks\" to get a full task ranking"
echo "   Say \"budget check\" to see detailed token consumption"
echo ""
