# Token Efficiency Audit

SOSA Level 3 plugin that audits and optimizes token usage across skills, scheduled tasks, plugins, and MCP connectors. Enforces the Orchestrated pillar's efficiency requirements (O6).

## What it scans for

- Bloated skill descriptions inflating system prompts
- Inline data tables better stored externally
- Duplicate skills/plugins
- Unused MCP connectors consuming tokens
- Overly frequent scheduled tasks
- Duplicated rules across skills

## Prerequisites

- Notion connector (for audit reports and external data storage)
- Scheduled Tasks MCP (default in Cowork)

## Usage

Initiate audits through natural language commands like "Run a token audit" or "Optimize my tokens."

The plugin operates in three phases:

1. **Plan** — Analyzes systems, calculates token costs, identifies waste patterns
2. **Act** — Presents findings, obtains approval, implements changes
3. **Verify** — Confirms modifications, reports savings metrics, archives to Notion

## Integration

Functions as a SOSA infrastructure plugin working with the `sosa-compliance-checker`, generating structured O6 compliance scores (PASS/PARTIAL/FAIL).

## Support

- Email: michal@msapps.mobi
- GitHub Issues: https://github.com/MSApps-Mobile/claude-plugins/issues
