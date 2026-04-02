# Connectors

## Required

- **SOSA Governor** — Provides budget configuration (`budgets.json`), audit logs, and impact classifications. The Orchestrator reads these to track token consumption and enforce budget limits.

## Optional

- **Scheduled Tasks MCP** (`mcp__scheduled-tasks__*`) — Lists pending and completed scheduled tasks for inclusion in the priority queue.
- **Token Efficiency Audit** — Provides optimization pattern recommendations when tasks consistently exceed their token estimates.
- **Notion** — For persisting orchestration reports and task history across sessions.
