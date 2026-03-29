# Token Efficiency Audit

**SOSA Level 3** — Audit and optimize token usage across your entire Claude setup.

Enforces the **Orchestrated pillar's efficiency requirements** (O6) from the [SOSA™ methodology](../../docs/SOSA.md).

## What It Does

Scans your skills, scheduled tasks, plugins, and MCP connectors to find token waste. Applies fixes automatically (with your approval) and reports savings.

Common findings:
- Bloated skill descriptions inflating every session's system prompt
- Inline data tables that should live in Notion
- Duplicate skills/plugins loading twice
- Unused MCP connectors burning thousands of tokens per session
- Scheduled tasks running more often than needed
- Rules duplicated across multiple skills

## Installation

### Claude Code
```
/plugin install token-efficiency-audit@msapps-plugins
```

### Cowork
Settings → Plugins → Search "token efficiency" → Install

## Requirements

- **Notion connector** — for storing audit reports and externalized data
- **Scheduled Tasks MCP** — available by default in Cowork

## Usage

Just say:
- "Run a token audit"
- "Optimize my tokens"
- "Audit my skills for efficiency"
- "What's eating my context window?"
- "Clean up my setup"

The plugin runs a three-phase **Plan → Act → Verify** cycle:
1. **Plan** — Scans everything, calculates token costs, identifies waste patterns (O6a–O6e)
2. **Act** — Presents findings, gets your approval, applies fixes
3. **Verify** — Confirms changes, reports before/after savings, saves to Notion

## SOSA Integration

This plugin is a **SOSA infrastructure plugin**. It works alongside the [`sosa-compliance-checker`](../sosa-compliance-checker):

- The `sosa-compliance-checker` calls this plugin during its **Orchestrated pillar** assessment (O6 checks)
- This plugin produces a structured O6 compliance score (PASS / PARTIAL / FAIL)
- Together they ensure the system is both compliant and efficient

See the [SOSA™ documentation](../../docs/SOSA.md) for the full framework.

## Support

- Email: michal@msapps.mobi
- Issues: [GitHub Issues](https://github.com/MSApps-Mobile/claude-plugins/issues)