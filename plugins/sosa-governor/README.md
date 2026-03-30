# SOSA Governor

**Supervised, Orchestrated, Secured, Agents — Governance for Claude Code**

A plugin that implements the SOSA methodology as a real-time governance layer for Claude Code sessions. Every MCP tool call is classified by impact level, high-impact actions are gated with approval requirements, and all actions are audit-logged.

## How It Works

### Automatic (Hooks)

The plugin installs three hooks that run automatically:

- **SessionStart** — Displays SOSA governance status and today's audit summary
- **PreToolUse** — Classifies every MCP tool call as low/medium/high impact. High-impact actions (sending WhatsApp messages, posting tweets, sending emails, deleting data) are **blocked** until the user explicitly approves
- **PostToolUse** — Logs completed actions and updates the trust gradient for high-impact tools

### On-Demand (Skill)

Say any of these to trigger the governance skill:

- "Run SOSA audit" — Full audit report of today's tool calls
- "Show trust scores" — See which tools have earned autonomy
- "Check compliance" — Evaluate against SOSA Level 1/2/3
- "Security scan" — Check for hardcoded secrets and suspicious patterns
- "Token budget report" — Review budget allocation and usage
- "Reclassify [tool] as [level]" — Change a tool's impact level

## Impact Levels

| Level | Action | Examples |
|-------|--------|----------|
| **Low** | Auto-approved | Read Notion, search Gmail, list WhatsApp chats |
| **Medium** | Logged | Create Monday item, update Notion page, create calendar event |
| **High** | Blocked until approved | Send WhatsApp message, send email, post tweet, delete data |

## Trust Gradient

High-impact tools start with a trust score of 0. Each time a user approves a blocked action, the tool's trust score increases by 0.1. After 10 successful approvals (score reaches 1.0), the tool is auto-approved — it has earned autonomy.

Trust can be reset manually via the skill ("reset trust for [tool]").

An incident (flagged by the user) reduces trust by 0.5.

## Configuration

All config lives in `config/`:

- `impact-registry.json` — Tool-to-impact-level mapping
- `trust-state.json` — Current trust scores per tool
- `budgets.json` — Token budget hierarchy (monthly → weekly → daily → per-agent)

## Audit Logs

Daily JSONL files in `audit/` (e.g., `audit/2026-03-31.jsonl`). Each line:

```json
{
  "timestamp": "2026-03-31T14:22:00Z",
  "session_id": "abc123",
  "tool": "mcp__whatsapp__send_message",
  "impact_level": "high",
  "reason": "External communication to real people",
  "decision": "denied"
}
```

## SOSA Methodology

Full spec: https://github.com/MSApps-Mobile/claude-plugins/blob/main/docs/SOSA.md

## License

MIT — MSApps Research, 2026
