#!/usr/bin/env python3
"""
SOSA Orchestrator — Token Budget Estimator

Reads SOSA Governor audit logs and budget config to produce a real-time
snapshot of token consumption and remaining budget.

Usage:
    python3 estimate_budget.py --plugin-root /path/to/sosa-governor --date 2026-03-31

Output: JSON to stdout with budget state.
"""

import json
import sys
import os
import glob
from datetime import datetime, timedelta
from pathlib import Path
import argparse


# Token cost heuristics per tool-call pattern
TOKEN_COSTS = {
    "high_chrome": 8000,      # Chrome page interaction (navigate + read + act)
    "medium_chrome": 4000,    # Chrome read-only
    "search_read": 1500,      # Search/list/fetch operations
    "write_action": 3000,     # Create/update/send operations
    "file_creation": 12000,   # Document generation
    "simple_query": 800,      # Info queries, status checks
}

# Map tool patterns to cost categories
TOOL_COST_MAP = {
    r"Claude_in_Chrome__(navigate|computer|form_input)": "high_chrome",
    r"Claude_in_Chrome__(read_page|get_page_text|find)": "medium_chrome",
    r"(search|list|fetch|get|read)": "search_read",
    r"(create|update|send|reply|delete|move)": "write_action",
    r"(write_file|write_pdf|create_doc)": "file_creation",
}


def find_sosa_governor_root():
    """Discover SOSA Governor plugin path dynamically."""
    candidates = glob.glob("/sessions/*/mnt/.remote-plugins/plugin_*/config/budgets.json")
    for c in candidates:
        plugin_dir = str(Path(c).parent.parent)
        plugin_json = os.path.join(plugin_dir, ".claude-plugin", "plugin.json")
        if os.path.exists(plugin_json):
            with open(plugin_json) as f:
                meta = json.load(f)
                if meta.get("name") == "sosa-governor":
                    return plugin_dir
    return None


def load_budgets(governor_root):
    """Load budget configuration from SOSA Governor."""
    budget_path = os.path.join(governor_root, "config", "budgets.json")
    if not os.path.exists(budget_path):
        return None
    with open(budget_path) as f:
        return json.load(f)


def load_audit_log(governor_root, date_str):
    """Load today's audit log entries."""
    audit_path = os.path.join(governor_root, "audit", f"{date_str}.jsonl")
    entries = []
    if os.path.exists(audit_path):
        with open(audit_path) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    return entries


def estimate_tool_tokens(tool_name):
    """Estimate tokens for a single tool call based on its name."""
    import re
    tool_lower = tool_name.lower()
    for pattern, cost_key in TOOL_COST_MAP.items():
        if re.search(pattern, tool_lower):
            return TOKEN_COSTS[cost_key]
    return TOKEN_COSTS["simple_query"]  # Default


def load_session_ledger(orchestrator_root):
    """Load the session ledger for historical tracking."""
    ledger_path = os.path.join(orchestrator_root, "config", "session-ledger.json")
    if os.path.exists(ledger_path):
        with open(ledger_path) as f:
            return json.load(f)
    return {"sessions": {}}


def compute_budget_state(budgets, audit_entries, ledger, date_str):
    """Compute current budget state from all sources."""
    # Daily budget = sum of all agent budgets
    agent_budgets = budgets.get("agent_budgets", {})
    daily_total = sum(ab.get("daily", 0) for ab in agent_budgets.values())
    reserve = daily_total * budgets.get("daily_reserve_percent", 15) / 100
    daily_available = daily_total - reserve

    # Estimate tokens consumed from audit log
    tokens_from_audit = sum(estimate_tool_tokens(e.get("tool", "")) for e in audit_entries)

    # Add any previously logged session data for today
    today_ledger = ledger.get("sessions", {}).get(date_str, {})
    tokens_from_ledger = today_ledger.get("daily_total", 0) if isinstance(today_ledger, dict) else 0

    # Use the higher of audit-based or ledger-based estimate
    tokens_consumed = max(tokens_from_audit, tokens_from_ledger)

    tokens_remaining = max(0, daily_available - tokens_consumed)
    utilization = tokens_consumed / daily_available if daily_available > 0 else 1.0

    # Per-category breakdown from audit
    category_consumed = {}
    for entry in audit_entries:
        tool = entry.get("tool", "")
        # Map tool to category (simplified — match against agent_budgets tasks)
        matched_cat = "operations"  # default
        for cat, config in agent_budgets.items():
            tasks = config.get("tasks", [])
            for task_keyword in tasks:
                if task_keyword.replace("-", "_") in tool.lower() or task_keyword in tool.lower():
                    matched_cat = cat
                    break
        tokens = estimate_tool_tokens(tool)
        category_consumed[matched_cat] = category_consumed.get(matched_cat, 0) + tokens

    # Category-level budget status
    category_status = {}
    for cat, config in agent_budgets.items():
        cat_budget = config.get("daily", 0)
        cat_consumed = category_consumed.get(cat, 0)
        cat_remaining = max(0, cat_budget - cat_consumed)
        cat_util = cat_consumed / cat_budget if cat_budget > 0 else 0
        category_status[cat] = {
            "budget": cat_budget,
            "consumed": cat_consumed,
            "remaining": cat_remaining,
            "utilization": round(cat_util, 3),
            "priority": config.get("priority", "medium"),
            "overage_policy": config.get("overage_policy", "notify_and_continue"),
            "status": "🟢" if cat_util < 0.8 else ("🟡" if cat_util < 1.0 else "🔴")
        }

    # Weekly tracking
    monthly_budget = budgets.get("monthly_token_budget", 25000000)
    weekly_budget = monthly_budget / 4.33  # Approx weeks per month

    # Determine health
    if utilization < 0.6:
        health = "🟢 Healthy"
    elif utilization < 0.8:
        health = "🟡 Watch"
    elif utilization < 1.0:
        health = "🔴 Critical"
    else:
        health = "⛔ Over Budget"

    return {
        "date": date_str,
        "daily_budget": daily_available,
        "daily_reserve": reserve,
        "tokens_consumed": tokens_consumed,
        "tokens_remaining": tokens_remaining,
        "utilization": round(utilization, 3),
        "health": health,
        "tool_calls_today": len(audit_entries),
        "category_status": category_status,
        "weekly_budget": round(weekly_budget),
        "monthly_budget": monthly_budget,
        "soft_limit_tokens": round(daily_available * budgets.get("overage_actions", {}).get("soft_limit_percent", 80) / 100),
        "hard_limit_tokens": daily_available
    }


def main():
    parser = argparse.ArgumentParser(description="SOSA Orchestrator Budget Estimator")
    parser.add_argument("--plugin-root", help="Path to SOSA Governor plugin root")
    parser.add_argument("--orchestrator-root", help="Path to SOSA Orchestrator plugin root")
    parser.add_argument("--date", default=datetime.now().strftime("%Y-%m-%d"), help="Date to check (YYYY-MM-DD)")
    args = parser.parse_args()

    # Find SOSA Governor
    governor_root = args.plugin_root or find_sosa_governor_root()
    if not governor_root:
        print(json.dumps({"error": "SOSA Governor plugin not found. Install sosa-governor first."}))
        sys.exit(1)

    # Find orchestrator root for ledger
    orchestrator_root = args.orchestrator_root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    budgets = load_budgets(governor_root)
    if not budgets:
        print(json.dumps({"error": "budgets.json not found in SOSA Governor config."}))
        sys.exit(1)

    audit_entries = load_audit_log(governor_root, args.date)
    ledger = load_session_ledger(orchestrator_root)
    state = compute_budget_state(budgets, audit_entries, ledger, args.date)

    print(json.dumps(state, indent=2))


if __name__ == "__main__":
    main()
