# SOSA™ — Supervised Orchestrated Secured Agents

**A Methodology for Production-Grade Autonomous AI Operations**

By [Michal Shatz](mailto:michal@msapps.mobi), MSApps Research, March 2026

---

## Overview

SOSA™ (Supervised Orchestrated Secured Agents) is a four-pillar methodology that reconciles agent autonomy with organizational accountability. It provides a formal structure for deploying multi-agent systems that operate continuously, adapt to heterogeneous toolchains, and maintain verifiable compliance with security and governance policies.

All MSApps plugins are built to be **SOSA-compliant**, meaning they implement the four pillars at the plugin level.

> **Read the full whitepaper:** [sosa-whitepaper.pdf](sosa-whitepaper.pdf)

---

## The Four Pillars

### 1. Supervised

Every agent operates under a defined supervision policy. Supervision is graduated: routine, low-impact tasks execute autonomously, while high-stakes actions require explicit human approval.

**How MSApps plugins implement this:**
- Each plugin declares its **impact level** (low / medium / high) in plugin metadata
- Low-impact plugins (read-only, local cleanup) operate fully autonomously
- Medium-impact plugins (sending messages, modifying data) include confirmation checkpoints
- High-impact plugins (financial operations, bulk outreach) require human approval before execution
- The **trust gradient** means plugins that consistently succeed earn expanded autonomy over time

### 2. Orchestrated

Agents coordinate through structured registries and a DAG (directed acyclic graph) execution model, not ad-hoc message passing.

**How MSApps plugins implement this:**
- Plugins declare their **dependencies** (which MCP servers, connectors, or other plugins they require)
- Plugins use the **Plan → Act → Verify** execution loop
- Context is shared through structured outputs (JSON, structured reports), not free-text handoffs
- Scheduled tasks declare temporal dependencies and execution order
- Plugin outputs feed into downstream workflows through well-defined interfaces

### 3. Secured

Security is not a perimeter — it is a property of every layer. Each agent runs with scoped credentials, zero-trust boundaries, and audit trails.

**How MSApps plugins implement this:**
- Credentials are **never hardcoded** in skill files — they live in local config files or environment variables
- Each plugin declares its **capability set** (which tools and APIs it can access)
- External data is scanned for **prompt injection** before processing (see [SECURITY.md](../SECURITY.md))
- MCP server package versions are **pinned** to prevent supply chain attacks
- All plugin actions are logged in daily summary reports
- Plugins follow the **principle of least privilege** — they only access what they need

### 4. Agents

SOSA agents are goal-directed autonomous entities defined as a tuple **A = (R, T, M, P)**:
- **R** — Role specification (domain boundaries, success criteria, escalation triggers)
- **T** — Tool manifest (authorized APIs, databases, communication channels)
- **M** — Memory and context store (persistence across execution cycles)
- **P** — Planning policy (how actions are selected given state and objectives)

**How MSApps plugins implement this:**
- Each plugin's `SKILL.md` defines the **role specification** (what the plugin does, when it triggers, what it should never do)
- The `.mcp.json` and connector requirements define the **tool manifest**
- Plugins that need memory use structured stores (Notion, Google Calendar, local config files)
- Planning is governed by the skill instructions, which define step-by-step workflows with explicit preconditions and postconditions

---

## The Execution Model: Plan → Act → Verify

Every SOSA-compliant plugin follows a three-phase execution loop:

1. **Plan** — Decompose the objective into a sequence of tool calls, subject to the capability set constraints. Filter out actions that would violate domain boundaries.

2. **Act** — Execute each planned step against real external systems, with every interaction logged. Actions that exceed the impact threshold are paused and escalated.

3. **Verify** — Evaluate the outcome against declared success criteria. Produce a structured evaluation record that feeds into the trust gradient.

---

## SOSA Compliance Levels

| Level | Requirements | Example Plugins |
|-------|-------------|-----------------|
| **Level 1 — Basic** | Role spec in SKILL.md, pinned dependencies, no hardcoded secrets | rtl-chat-fixer, vm-disk-cleanup, mac-disk-cleaner |
| **Level 2 — Standard** | Level 1 + prompt injection scanning, audit logging, declared capability set | google-drive-upload, youtube-transcriber, session-backup |
| **Level 3 — Full** | Level 2 + human approval gates for high-impact actions, structured Plan→Act→Verify loop, trust gradient | whatsapp-mcp, apollo, apify-scraper, linkedin-scraper |

---

## Reference Implementation

[OpsAgent](https://opsagent.ai) by MSApps is the first commercial implementation of the SOSA framework, operating in production across 18+ department types since early 2025.

---

© 2026 MSApps Research. All rights reserved.
