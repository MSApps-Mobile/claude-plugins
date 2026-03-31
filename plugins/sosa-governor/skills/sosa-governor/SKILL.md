---
name: sosa-governor
description: >
  SOSA Governor for on-demand governance audits, compliance checks, and reporting.
  Use this skill when the user says "run SOSA audit", "check compliance", "show
  trust scores", "SOSA report", "governance status", "audit my agents", "token
  budget report", "which tools are high impact", "reset trust for", "show audit
  log", "SOSA dashboard", or any reference to agent governance, compliance
  levels, or security auditing. Also trigger on "what did my agents do today",
  "how many tokens did I use", or "are there any security issues".
metadata:
  version: "0.1.0"
  sosa_level: "3"
---

# SOSA Governor — On-Demand Audit & Reporting

This skill provides manual governance operations. The hooks handle real-time
classification and gating automatically; this skill handles reporting,
configuration, and manual overrides.

## Audit Report

When the user asks for a SOSA audit or governance report:

1. Read the audit log at `${CLAUDE_PLUGIN_ROOT}/audit/` for today's date (YYYY-MM-DD.jsonl)
2. Parse each line as JSON — fields: timestamp, session_id, tool, impact_level, reason, decision
3. Summarize:
   - Total tool calls today
   - Breakdown by impact level (low / medium / high)
   - Denied actions (high-impact that were blocked)
   - Most active tools
   - Sessions with the most activity
4. Present as a clear table

## Trust Score Management

When the user asks about trust scores or wants to reset trust:

1. Read `${CLAUDE_PLUGIN_ROOT}/config/trust-state.json`
2. The `tools` object maps tool names to trust scores (0.0 = no trust, 1.0+ = auto-approved)
3. Display current trust scores for all tools that have scores
4. To reset a tool's trust: update the JSON, setting the tool's score back to 0

Trust formula:
- Each successful approval: +0.1
- Each incident: -0.5
- Threshold for auto-approval: 1.0 (requires ~10 successful approvals)

## Impact Registry

When the user asks which tools are classified at what level:

1. Read `${CLAUDE_PLUGIN_ROOT}/config/impact-registry.json`
2. Display the three tiers (high, medium, low) with tools and reasons
3. The user can request reclassification — edit the registry JSON accordingly
4. Default level for unregistered MCP tools: medium

## Token Budget Status

When the user asks about token budgets:

1. Read `${CLAUDE_PLUGIN_ROOT}/config/budgets.json`
2. Show the budget hierarchy: monthly → weekly → daily → per-category
3. Compare against today's audit log to estimate actual usage
4. Flag categories approaching their daily limit (>80%)

## Compliance Check

When the user asks to check SOSA compliance:

Evaluate the current setup against SOSA levels:

**Level 1 — Basic:**
- [ ] Impact registry exists and has entries
- [ ] No hardcoded secrets in skill files
- [ ] Pinned dependencies

**Level 2 — Standard:**
- [ ] Level 1 + audit logging active (check for today's audit file)
- [ ] Token budget config exists
- [ ] Trust gradient configured

**Level 3 — Full:**
- [ ] Level 2 + PreToolUse hooks active (high-impact gating)
- [ ] Plan → Act → Verify → Optimize loop documented
- [ ] Trust gradient with persistence
- [ ] Cross-session audit capability

Report which level is currently achieved and what's missing for the next level.

## Security Scan

When the user asks for a security check:

1. Use Grep to scan all SKILL.md files for patterns matching API keys, tokens, passwords:
   - Patterns: `sk-`, `api_key`, `token.*=.*[A-Za-z0-9]{20}`, `password`, `secret`
2. Check if any MCP configs have hardcoded credentials (vs environment variables)
3. Review recent audit logs for unusual patterns:
   - Same tool denied then immediately approved (potential social engineering)
   - Burst of high-impact actions in short timeframe
   - Tools called from sessions that don't normally use them
4. Report findings with severity ratings

## Modifying the Registry

When the user wants to change an impact classification:

1. Read the current registry
2. Move the tool entry between the high/medium/low arrays
3. Write the updated registry back
4. Confirm the change and note that it takes effect immediately (next tool call)
