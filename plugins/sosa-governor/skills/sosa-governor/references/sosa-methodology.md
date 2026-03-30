# SOSA Methodology Reference

SOSA (Supervised, Orchestrated, Secured, Agents) is a four-pillar methodology
for production-grade autonomous AI operations, developed by MSApps Research.

## The Four Pillars

### Supervised
Every agent operates under a graduated supervision policy. Routine, low-impact
tasks execute autonomously while high-stakes actions require explicit human
approval. Trust is earned through a gradient — successful approvals expand
autonomy over time.

### Orchestrated
Orchestration demands efficiency. Every token consumed by a bloated skill
description, a redundant MCP connector, or a duplicate plugin is a token
unavailable for actual work. Token budgets cascade from monthly to per-session.
Tasks are prioritized by urgency, business impact, and efficiency score.

### Secured
Security is a property of every layer. Each agent runs with scoped credentials,
zero-trust boundaries, and audit trails. No hardcoded secrets. Prompt injection
scanning on external data. Pinned MCP versions.

### Agents
Each agent is formally defined as A = (Role, Tools, Memory, Planning):
- Role: boundaries, success criteria, escalation triggers
- Tools: declared MCP tool manifest
- Memory: session transcript + cross-session persistence
- Planning: action selection policy, impact level, token budget

## Compliance Levels

| Level | Requirements |
|-------|-------------|
| Level 1 — Basic | Role spec, pinned dependencies, no hardcoded secrets |
| Level 2 — Standard | Level 1 + injection scanning, audit logging, token efficiency |
| Level 3 — Full | Level 2 + approval gates, Plan-Act-Verify, trust gradient |

## Execution Model: Plan → Act → Verify → Optimize

1. Plan: Decompose objectives, assess resource costs, allocate token budget
2. Act: Execute with logging, escalate high-impact actions
3. Verify: Evaluate outcomes against success criteria, measure efficiency
4. Optimize: Feed findings back — reduce budgets for efficient agents, rewrite
   prompts for wasteful ones, log failure patterns to prevent recurrence

Full spec: https://github.com/MSApps-Mobile/claude-plugins/blob/main/docs/SOSA.md
