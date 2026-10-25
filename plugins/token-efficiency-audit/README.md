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

## What it runs and connects to

Everything below is derived from the files in this plugin. Nothing here is hidden behind an install step.

**Bundled code:** none. The plugin ships only Markdown and JSON (`skills/*/SKILL.md`, `skills/token-efficiency-audit/references/optimization-patterns.md`, `CLAUDE.md`, `CONNECTORS.md`, `.claude-plugin/plugin.json`, `.claude-plugin/config.json`). It has no scripts, no hooks, no `.mcp.json`, no install or post-install commands, and no bundled binaries or dependencies.

**Tool calls the instructions make (via connectors already in your session):**

| Tool / connector | Used for | Network? |
|---|---|---|
| `list_scheduled_tasks` (Scheduled Tasks MCP) | List scheduled tasks to audit frequency and overlap | Local to Claude |
| `list_sessions`, `read_transcript` (session-info MCP) | Read recent session transcripts to find token waste | Local to Claude |
| Desktop Commander (optional) | Read skill files on the Mac if the VM mount is read-only | Local filesystem |
| Notion connector (required) | Save audit reports and externalized data to your Notion workspace | Yes, Notion via your connector |
| `present_files` | Hand back the report and `.skill` replacement packages | No |

**Shell commands:** the only shell commands in the plugin are in `CLAUDE.md` (the scheduled-run self-update step): `git clone https://github.com/MSApps-Mobile/claude-plugins.git`, `cp`, `git add`, `git commit`, `git push origin main`. This is the only direct network call the plugin makes, and it goes only to `github.com/MSApps-Mobile/claude-plugins`. It runs only in the owner's own scheduled audit task and only if that run learned something new. It needs your GitHub auth and is skipped if you do not use it.

**Network destinations:** `github.com/MSApps-Mobile/claude-plugins` (the push above) and Notion (through your connector). The plugin makes no other fetches and sends no data to MSApps or any third-party server, and it has no telemetry.

**Reads and writes:** it reads skill files, scheduled-task metadata and session transcripts. It never reads credentials or `.mcp.json`. It does not modify or delete skills, tasks or plugins without your approval. It writes the audit report (`token-audit-YYYY-MM-DD.md`) and a Notion page.

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
