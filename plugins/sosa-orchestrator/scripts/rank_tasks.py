#!/usr/bin/env python3
"""
SOSA Orchestrator — Task Ranker

Reads task profiles and current budget state, then produces a prioritized
task queue with feasibility analysis.

Usage:
    python3 rank_tasks.py --profiles config/task-profiles.json --budget-state <budget_json> --tasks "task1,task2,task3"

Output: JSON to stdout with ranked task list and feasibility report.
"""

import json
import sys
import argparse
from pathlib import Path


def load_profiles(profiles_path):
    """Load task profiles from config."""
    with open(profiles_path) as f:
        return json.load(f)


def compute_priority_score(profile):
    """
    Priority = (Business Impact × Urgency × Dependency Weight) / Normalized Token Cost

    Higher score = run first.
    """
    impact = profile.get("business_impact", 5)
    urgency = profile.get("urgency", 3)

    # Dependency weight: tasks that others depend on get a boost
    dep_weight = 1.0
    deps = profile.get("dependencies", [])
    if len(deps) == 0:
        dep_weight = 1.2  # Self-contained tasks are slightly easier to schedule
    elif len(deps) >= 3:
        dep_weight = 0.8  # Heavy dependencies = riskier

    # Normalize token cost: scale avg_tokens to 1-10 range
    avg_tokens = profile.get("avg_tokens", 30000)
    # 5K = 1, 50K = 5, 100K = 10
    token_factor = max(1, min(10, avg_tokens / 10000))

    score = (impact * urgency * dep_weight) / token_factor
    return round(score, 2)


def rank_tasks(task_names, profiles, budget_remaining):
    """Rank tasks by priority score and check budget feasibility."""
    ranked = []

    for name in task_names:
        profile = profiles.get(name)
        if not profile:
            # Unknown task — assign defaults
            profile = {
                "category": "development",
                "business_impact": 5,
                "urgency": 3,
                "avg_tokens": 30000,
                "p95_tokens": 50000,
                "dependencies": [],
                "frequency": "on-demand",
                "description": f"Unknown task: {name}"
            }

        score = compute_priority_score(profile)
        ranked.append({
            "task": name,
            "priority_score": score,
            "category": profile.get("category", "unknown"),
            "business_impact": profile.get("business_impact", 5),
            "urgency": profile.get("urgency", 3),
            "avg_tokens": profile.get("avg_tokens", 30000),
            "p95_tokens": profile.get("p95_tokens", 50000),
            "description": profile.get("description", ""),
            "frequency": profile.get("frequency", "on-demand")
        })

    # Sort by priority score descending
    ranked.sort(key=lambda x: x["priority_score"], reverse=True)

    # Feasibility analysis
    running_total = 0
    feasibility = "🟢"
    cutoff_index = len(ranked)

    for i, task in enumerate(ranked):
        running_total += task["avg_tokens"]
        task["cumulative_tokens"] = running_total
        if running_total <= budget_remaining:
            task["feasibility"] = "✅ Fits"
        elif running_total <= budget_remaining * 1.2:
            task["feasibility"] = "⚠️ Tight"
            if feasibility == "🟢":
                feasibility = "🟡"
        else:
            task["feasibility"] = "🛑 Over budget"
            if feasibility != "🔴":
                feasibility = "🔴"
                cutoff_index = min(cutoff_index, i)

    total_estimated = sum(t["avg_tokens"] for t in ranked)
    total_p95 = sum(t["p95_tokens"] for t in ranked)

    return {
        "ranked_tasks": ranked,
        "summary": {
            "total_tasks": len(ranked),
            "total_estimated_tokens": total_estimated,
            "total_p95_tokens": total_p95,
            "budget_remaining": budget_remaining,
            "feasibility": feasibility,
            "tasks_that_fit": cutoff_index,
            "tasks_at_risk": len(ranked) - cutoff_index,
            "headroom": budget_remaining - total_estimated
        }
    }


def main():
    parser = argparse.ArgumentParser(description="SOSA Orchestrator Task Ranker")
    parser.add_argument("--profiles", required=True, help="Path to task-profiles.json")
    parser.add_argument("--budget-remaining", type=int, default=400000, help="Remaining token budget")
    parser.add_argument("--tasks", required=True, help="Comma-separated list of task names to rank")
    args = parser.parse_args()

    profiles = load_profiles(args.profiles)

    # Filter out the _doc key
    profiles = {k: v for k, v in profiles.items() if k != "_doc"}

    task_list = [t.strip() for t in args.tasks.split(",") if t.strip()]
    result = rank_tasks(task_list, profiles, args.budget_remaining)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
