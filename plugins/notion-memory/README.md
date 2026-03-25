# Notion Memory — Claude Plugin by MSApps

Give Claude long-term memory across sessions using your Notion workspace. Claude remembers your preferences, decisions, project context, and session history.

## What it does

- **Remembers** preferences, tools, communication style
- **Tracks** decisions with reasoning and dates
- **Archives** session summaries for seamless handoffs
- **Stores** quick facts and project context
- **Forgets** on command — you're always in control

## How it works

All memory lives in a "Claude Memory" page in your Notion workspace, organized into:

- **Profile** — who you are, how you work
- **Projects** — one page per active project
- **Decisions Log** — key decisions with reasoning
- **Session Archive** — past session summaries
- **Quick Facts** — short key-value facts

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-memory@msapps-plugins
```

**Cowork:** Search for "notion-memory" in Settings → Plugins, or install from the [MSApps marketplace](https://github.com/MSApps-Mobile/claude-plugins).

## Requirements

- **Notion connector** — connect via one of the following:
  - **Cowork**: Settings → Connectors → Notion
  - **Claude Code**: Add a Notion MCP server to your config (`.mcp.json` or settings)

## Usage

Just talk to Claude naturally:

- "Remember that I prefer dark mode"
- "What do you know about the BPure project?"
- "Save what we did today"
- "Forget my old email address"

Claude also saves context automatically when it detects preferences, decisions, or project info.

## License

MIT — Free and open source.

## Author

**MSApps** — [msapps.mobi](https://msapps.mobi) | [michal@msapps.mobi](mailto:michal@msapps.mobi)