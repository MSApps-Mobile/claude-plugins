# SOSA Orchestrator

**Token-aware task prioritization and budget management for Claude sessions.**

Part of the [SOSA™ governance suite](../../docs/SOSA.md) by MSApps.

## What It Does

The Orchestrator is the resource-aware brain that sits above individual tasks and decides what runs, what waits, and what stops — based on real-time token budget tracking and business priority scoring.

- **Tracks token budgets** across Cowork sessions, Claude Code, and scheduled tasks
- **Ranks tasks** by a Priority Score: `(Impact × Urgency × Dependencies) / Token Cost`
- **Monitors consumption** in real time and warns before budget boundaries are crossed
- **Pauses tasks** that exceed estimates — always explains why and asks before stopping
- **Reports** session summaries with completed/deferred/stopped breakdowns

## How It Works

```
┌─────────────────────────────────────────────┐
│              SOSA Orchestrator               │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Budget   │  │ Task     │  │ Pause/     │ │
│  │ Tracker  │  │ Ranker   │  │ Resume     │ │
│  └────┬─────┘  └────┬─────┘  └─────┬──────┘ │
│       │              │              │        │
│  ┌────▼──────────────▼──────────────▼────┐   │
│  │         Priority × Cost Matrix        │   │
│  └───────────────────────────────────────┘   │
└──────────────┬──────────────┬────────────────┘
               │              │
    ┌──────────▼──┐    ┌──────▼───────┐
    │SOSA Governor│    │Token Efficiency│
    │(tool gates) │    │Audit (patterns)│
    └─────────────┘    └──────────────┘
```

## Install

```bash
/plugin install sosa-orchestrator@msapps-plugins
```

**Requires:** `sosa-governor` plugin (for budget config and audit logs)

## Usage

Say any of these:
- "Orchestrate my tasks"
- "Prioritize — I have a lot to do today"
- "How's my token budget?"
- "What should I focus on?"
- "Am I running out of tokens?"
- "Budget check"

## SOSA Compliance

| Pillar | Implementation |
|--------|---------------|
| Supervised | Always pauses and asks before stopping any task |
| Orchestrated | Priority×Cost matrix with cascading budgets |
| Secured | Read-only audit access, all decisions logged |
| Agents | Role: session resource manager |

**SOSA Level:** 3 (Full)

## Configuration

- `config/task-profiles.json` — Pre-configured token estimates for known tasks
- `config/session-ledger.json` — Historical consumption log
- Reads `config/budgets.json` from SOSA Governor for budget limits

## License

MIT — © 2026 MSApps Research
