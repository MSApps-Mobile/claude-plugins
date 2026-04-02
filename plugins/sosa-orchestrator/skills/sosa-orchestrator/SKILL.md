---
name: sosa-orchestrator
description: >
  SOSA Orchestrator — the brain of your Claude session. Tracks token budgets in real time across Cowork, Claude Code, and scheduled tasks, then ranks every pending task by importance vs. token cost and decides what to run, defer, or pause. Use this skill whenever you say: "orchestrate", "prioritize tasks", "token budget", "what should I run next", "how many tokens left", "rank my tasks", "stop low priority", "session budget", "am I running out of tokens", "what can I still afford", "triage tasks", "budget check", or any mention of balancing work against remaining tokens. Also triggers automatically at session start (via hook) and whenever a task completes to re-evaluate priorities. Even if you just say "what's the plan" or "what should I focus on" in the context of multiple pending tasks, use this skill.
metadata:
  version: "1.0.0"
  sosa_level: "3"
  pillar_focus: "Orchestrated"
  platforms: ["claude-code", "cowork"]
---

# SOSA Orchestrator

**The resource-aware brain that decides what runs, what waits, and what stops.**

## Why This Exists

Every Claude session — Cowork, Claude Code, scheduled tasks — burns through a finite token budget. Without active orchestration, a low-priority health check can eat the tokens you needed for a revenue-critical invoice run. The Orchestrator solves this by maintaining a live priority×cost matrix and making smart allocation decisions throughout the session.

It integrates tightly with the **SOSA Governor** (which gates individual tool calls) and the **Token Efficiency Audit** (which optimizes long-term patterns). The Orchestrator operates at the *task level* — deciding which tasks deserve tokens right now.

---

## Core Concepts

### Token Budget Hierarchy

Budgets cascade from broad to narrow. The orchestrator reads these from `config/budgets.json` (shared with SOSA Governor):

```
Monthly budget (25M tokens)
  → Weekly allocation (rolling average)
    → Daily budget (minus 15% reserve)
      → Agent category budgets (revenue, communication, operations, development, monitoring)
        → Individual task estimates
```

### Task Priority Score

Every task gets a **Priority Score** computed as:

```
Priority = (Business Impact × Urgency × Dependency Weight) / Estimated Token Cost
```

Where:
- **Business Impact** (1-10): Revenue tasks score 8-10, monitoring scores 1-3
- **Urgency** (1-5): Deadline-driven tasks score higher
- **Dependency Weight** (1-3): Tasks that unblock other tasks score higher
- **Estimated Token Cost**: Based on historical averages or skill complexity heuristics

Higher score = should run first. The orchestrator maintains a sorted queue.

### Budget Categories (from SOSA Governor config)

| Category | Daily Budget | Priority | Overage Policy |
|----------|-------------|----------|----------------|
| Revenue | 150K tokens | Critical | Borrow from reserve |
| Communication | 120K tokens | High | Borrow from reserve |
| Development | 100K tokens | Medium | Notify and continue |
| Operations | 80K tokens | Medium | Queue until tomorrow |
| Monitoring | 30K tokens | Low | Throttle |

---

## Execution Model: Plan → Act → Verify

### Phase 1: Plan — Assess the Landscape

**Step 1 — Gather token state.** Collect budget data from all available sources:

1. **SOSA Governor audit logs** — Read today's `audit/YYYY-MM-DD.jsonl` from the SOSA Governor plugin. Count tool calls, estimate tokens consumed per call (use the heuristics table below).
2. **Session conversation length** — Count messages and tool calls in the current session. Each message ≈ 500-2000 tokens input, each tool call response ≈ 1000-5000 tokens.
3. **Scheduled task history** — Check `mcp__scheduled-tasks__list_scheduled_tasks` for today's completed and pending runs.
4. **budgets.json** — Read the cascading budget config to know daily/weekly/monthly limits.

**Token estimation heuristics** (when exact counts aren't available):

| Operation Type | Estimated Tokens |
|---------------|-----------------|
| Simple read/search tool call | 1,000-2,000 |
| Chrome page read | 3,000-8,000 |
| Chrome page interaction (navigate + read + act) | 5,000-15,000 |
| File creation (docx, xlsx, pdf) | 8,000-25,000 |
| Multi-step workflow (invoicing, lead review) | 20,000-80,000 |
| Skill with subagents | 30,000-100,000 |
| Simple conversation turn | 500-1,500 |

**Step 2 — Inventory pending tasks.** Gather everything that needs to run:

- Check the TodoList for in-progress and pending items
- Check scheduled tasks for anything due today
- Ask the user what they want to accomplish (if interactive)
- Check CLAUDE.md for recurring task definitions

**Step 3 — Score and rank.** For each task, compute the Priority Score and build the ranked queue. Present it as a clear table:

```
| Rank | Task | Category | Impact | Est. Tokens | Priority Score | Status |
|------|------|----------|--------|-------------|----------------|--------|
| 1 | Aman invoicing | Revenue | 9 | ~45K | 18.0 | ⏳ Pending |
| 2 | LinkedIn lead review | Revenue | 8 | ~35K | 16.0 | ⏳ Pending |
| 3 | WhatsApp replies (Gali) | Communication | 7 | ~15K | 14.0 | ⏳ Pending |
| ...
```

**Step 4 — Budget feasibility check.** Sum estimated tokens for all tasks. Compare against remaining daily budget. Flag any issues:

- 🟢 **All clear** — Budget covers everything with margin
- 🟡 **Tight** — Can finish top priorities but lower tasks may get cut
- 🔴 **Over budget** — Cannot complete all tasks. Must defer or optimize.

### Phase 2: Act — Execute with Awareness

**During task execution**, the orchestrator maintains a running token ledger:

1. **Before each task starts**: Show the user the current state:
   ```
   📊 Budget: ~180K remaining of 480K daily | Task: "LinkedIn lead review" (~35K est.)
   After this task: ~145K remaining | Enough for: 3-4 more medium tasks
   ```

2. **Token efficiency mode**: When budget drops below 40%, automatically:
   - Suggest compressed approaches (shorter reports, skip optional sections)
   - Recommend batching similar operations
   - Flag if a task is consuming more than estimated

3. **Pause trigger**: If a running task exceeds 150% of its estimate, pause and report:
   ```
   ⚠️ PAUSE — "LinkedIn lead review" has consumed ~52K tokens (estimate was 35K).

   Remaining budget: ~128K tokens
   Still pending: Aman invoicing (~45K), Toggl check (~5K), Gali replies (~15K)

   Options:
   A) Continue this task (may consume ~20K more)
   B) Stop here — I'll save a partial report with what I have so far
   C) Switch to higher-priority task first, come back to this later

   What would you like to do?
   ```

4. **Task completion**: After each task, update the ledger and re-rank remaining tasks. The priority order may shift based on actual consumption.

### Phase 3: Verify — Confirm State

After the session's work is done (or budget is exhausted):

1. **Generate session summary**:
   ```
   📋 Session Summary — 2026-03-31

   Completed: 4 tasks | Deferred: 2 tasks | Stopped: 1 task
   Tokens used: ~310K of 480K daily budget (65%)
   Budget health: 🟢 Within limits

   Completed:
   ✅ Aman invoicing (42K tokens) — Revenue
   ✅ LinkedIn lead review (38K tokens) — Revenue
   ✅ Gali WhatsApp replies (12K tokens) — Communication
   ✅ Toggl health check (4K tokens) — Monitoring

   Deferred (budget-aware):
   ⏸️ Plugin development — Low urgency, moved to tomorrow
   ⏸️ Receipt collection — Queued per operations overage policy

   Stopped:
   🛑 GitHub migration — Exceeded estimate by 180%, partial progress saved
   ```

2. **Update budget state** — Write consumed totals to `config/session-ledger.json` so future sessions know what's been spent this week/month.

3. **Recommendations for next session**:
   - Tasks that rolled over and their priority
   - Budget forecast for the rest of the week
   - Any efficiency patterns noticed (e.g., "Chrome-heavy tasks consistently over-estimate — consider using MCP tools where possible")

---

## Stop/Pause Protocol

The orchestrator **never silently kills a task**. When it decides a task should stop, it always:

1. **Explains why** — Which budget limit is at risk (session, daily, weekly, monthly)
2. **Shows the math** — Tokens consumed, tokens remaining, what's still queued
3. **Presents options** — Continue anyway, stop gracefully, switch to something else
4. **Explains consequences** — "If you continue, you may not have budget for Aman invoicing which is due today" or "You're at 85% of your weekly budget on Tuesday — continuing means Thursday/Friday sessions will be constrained"
5. **Waits for user decision** — Always. No autonomous stops.

### Budget Horizon Warnings

The orchestrator thinks beyond the current session:

| Horizon | Warning Trigger | Message |
|---------|----------------|---------|
| Session | >80% of daily estimate consumed | "This session has used 80% of today's budget. X tasks remain." |
| Daily | >90% of daily budget | "Daily budget nearly exhausted. Remaining tasks will queue to tomorrow." |
| Weekly | >70% by Wednesday | "Weekly burn rate is high — consider deferring non-critical tasks." |
| Monthly | >80% by the 20th | "Monthly budget is ahead of pace. Review task scheduling." |

---

## Integration Points

### With SOSA Governor
- Reads `config/budgets.json` for budget limits
- Reads `audit/YYYY-MM-DD.jsonl` for actual tool-call counts
- Respects impact classifications — doesn't override Governor's gate decisions
- Adds an orchestration layer *above* the Governor: Governor gates individual tools, Orchestrator gates entire tasks

### With Token Efficiency Audit
- Triggers efficiency recommendations when a task consistently over-consumes
- Applies optimization patterns (O6a-O6e) to reduce estimated costs
- Feeds actual-vs-estimated data back to improve future estimates

### With Scheduled Tasks
- Reads scheduled task definitions and their due times
- Factors scheduled tasks into the daily budget allocation
- Can recommend rescheduling low-priority scheduled tasks when budget is tight

---

## Configuration

### `config/task-profiles.json`

Pre-configured profiles for known recurring tasks. The orchestrator uses these for estimation:

```json
{
  "linkedin-lead-review": {
    "category": "revenue",
    "business_impact": 8,
    "avg_tokens": 35000,
    "p95_tokens": 55000,
    "urgency": 4,
    "dependencies": [],
    "frequency": "daily"
  },
  "aman-monthly-invoicing": {
    "category": "revenue",
    "business_impact": 9,
    "avg_tokens": 45000,
    "p95_tokens": 70000,
    "urgency": 5,
    "dependencies": ["chrome"],
    "frequency": "monthly"
  }
}
```

Add new task profiles as you discover recurring tasks. The orchestrator learns from actuals over time.

### `config/session-ledger.json`

Running log of token consumption per session, per day. Used for weekly/monthly tracking:

```json
{
  "2026-03-31": {
    "sessions": [
      {
        "session_id": "affectionate-practical-tesla",
        "started": "2026-03-31T09:00:00Z",
        "tasks_completed": 4,
        "tasks_deferred": 2,
        "estimated_tokens": 310000,
        "category_breakdown": {
          "revenue": 80000,
          "communication": 12000,
          "operations": 0,
          "development": 0,
          "monitoring": 4000
        }
      }
    ],
    "daily_total": 310000,
    "daily_budget": 480000,
    "utilization": 0.65
  }
}
```

---

## Quick Start (for the user)

Say any of these to invoke the orchestrator:
- "What should I focus on today?"
- "Orchestrate my tasks"
- "How's my token budget?"
- "Prioritize — I have a lot to do"
- "Am I running out of tokens?"

The orchestrator will scan your pending work, check your budget, and present a prioritized plan. It stays active throughout the session, tracking consumption and alerting you before any budget boundary is crossed.

---

## Platform Notes

**Cowork**: Full functionality. Uses TodoList widget for visual task tracking. Session hooks trigger automatic budget check on start.

**Claude Code**: Full functionality. Outputs to terminal. Can read `.claude/audit/` logs and scheduled task configs. Use `claude -p` for non-interactive budget checks.

**Scheduled Tasks**: The orchestrator doesn't run *as* a scheduled task — it runs at the start of interactive sessions and monitors scheduled tasks' budget impact.
