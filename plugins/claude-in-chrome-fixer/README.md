# Claude-in-Chrome Fixer

Automatically diagnoses and repairs broken [Claude in Chrome](https://claude.ai/download) MCP connections. Designed to run as a scheduled task and **self-improves** after each run by committing learnings back to this repository.

## What it does

When the Claude-in-Chrome extension loses its MCP connection (common after macOS user switches or Chrome restarts), this plugin:

1. Tests the current connection
2. Tries opening/focusing Chrome
3. Quits and relaunches Chrome if needed
4. Reports the outcome and asks the user if all else fails

At the end of every run, it reflects on what it learned and updates its own skill file, then pushes the improvement to GitHub.

## Skills

| Skill | Trigger |
|-------|---------|
| `fix-chrome-connection` | Scheduled task, or say "fix Chrome", "Chrome MCP is broken", "reconnect Chrome" |

## Setup as a Scheduled Task

This plugin is designed to run automatically. To set it up:

1. Install the plugin in Cowork
2. Ask Claude: *"Create a scheduled task that runs fix-chrome-connection every morning"*

## Requirements

- Claude in Chrome extension installed
- Desktop Commander MCP connected (for shell commands)
- Git configured in your terminal with push access to `MSApps-Mobile/claude-plugins`

## Self-improvement

After each run, the skill checks if it learned anything new and, if so:
- Updates `skills/fix-chrome-connection/SKILL.md` with the new knowledge
- Commits and pushes to `MSApps-Mobile/claude-plugins` on GitHub

This means the skill gets smarter over time automatically.
