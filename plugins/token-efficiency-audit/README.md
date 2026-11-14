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

**Shell commands:** none. The instructions in `CLAUDE.md` contain no shell, `git clone`, `git commit` or `git push` steps. The plugin does not publish anything to GitHub and does not edit its own files.

**Network destinations:** Notion, through your own connector, and nothing else. The plugin makes no direct network calls, fetches nothing, sends no data to MSApps or any third-party server, and has no telemetry. Report content (task names, token counts, findings) goes only to your workspace and your Notion workspace.

**Reads and writes:** it reads skill files, scheduled-task metadata and session transcripts. It never reads credentials or `.mcp.json`. It never modifies or deletes skills, tasks or plugins on its own, and never edits its own plugin files: learnings from a run appear as "Suggested plugin updates" in the report and the Notion page for you to apply by hand. It writes the audit report (`token-audit-YYYY-MM-DD.md`) and a Notion page.

**Declared capabilities:** `.claude-plugin/plugin.json` and `.claude-plugin/config.json` list `read_skills`, `read_scheduled_tasks`, `modify_scheduled_tasks`, `notion_read_write` and `present_files`.

| Capability | What the instructions do with it |
|---|---|
| `modify_scheduled_tasks` | Declared so the audit can offer to change a task schedule. The instructions never change a scheduled task autonomously: changes to task frequency, disabling or deleting a task are listed as recommendations and applied only after you approve them. |

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
