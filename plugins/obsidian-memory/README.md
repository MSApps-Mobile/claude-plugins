# Obsidian Memory — Claude Plugin by MSApps

Give Claude long-term memory across sessions using your local Obsidian vault. Claude remembers your preferences, decisions, project context, and session history — all stored as plain Markdown files you own.

## What it does

- **Remembers** preferences, tools, communication style
- **Tracks** decisions with reasoning and dates
- **Archives** session summaries for seamless handoffs
- **Stores** quick facts and project context
- **Forgets** on command — you're always in control

## How it works

Memory is stored as Markdown files in your Obsidian vault, organized into folders:

- **Preferences/** — who you are, how you work
- **Projects/** — one file per active project
- **People/** — key contacts and collaborators
- **Daily/** — daily notes with session summaries
- **Claude Memory/** — decisions log, quick facts, session archive

Unlike the Notion-based memory plugin, this works entirely on the local filesystem — no external API or connector required.

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install obsidian-memory@msapps-plugins
```

**Cowork:**
1. Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`
2. Search "obsidian-memory" → Install

## Requirements

- An **Obsidian vault** accessible on the local filesystem
- Claude Code or Cowork with filesystem access to the vault directory

## Configuration

The plugin auto-detects common Obsidian vault locations. If your vault is in a non-standard location, set the path in the skill configuration.

## Usage

Just talk to Claude naturally:

- "Remember that I prefer dark mode"
- "What do you know about the BPure project?"
- "Save what we did today"
- "Forget my old email address"

Claude also saves context automatically when it detects preferences, decisions, or project info.

## Advantages over Notion Memory

| Feature | Obsidian Memory | Notion Memory |
|---------|----------------|---------------|
| Requires external API | No | Yes (Notion MCP) |
| Data location | Local files | Cloud (Notion) |
| Works offline | Yes | No |
| File format | Plain Markdown | Notion blocks |
| User can edit directly | Yes (any text editor) | Yes (Notion app) |
| Supports wiki-links | Yes | No |
| Backlinks & graph view | Yes (via Obsidian) | No |

## License

MIT — Free and open source.

## Author

**MSApps** — [msapps.mobi](https://msapps.mobi) | [michal@msapps.mobi](mailto:michal@msapps.mobi)
