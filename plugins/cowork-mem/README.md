# cowork-mem

Persistent memory for Cowork sessions. Never lose context between sessions again.

> Inspired by [claude-mem](https://github.com/thedotmack/claude-mem) by [@thedotmack](https://github.com/thedotmack). Rebuilt natively for Cowork.

## What it does

cowork-mem gives Claude a persistent memory that survives across Cowork sessions. It stores decisions, file changes, insights, errors, and session summaries in a SQLite database on your machine — so when you come back tomorrow, Claude remembers what happened today.

## How it works

- **Session start**: Claude automatically checks what happened in previous sessions and gives you a brief recap
- **During work**: Claude saves important observations — architectural decisions, bugs encountered, insights learned
- **Session end**: Claude writes a summary so next time picks up right where you left off
- **Search**: Ask "what did we decide about X?" and Claude searches across all past sessions

## Features

- SQLite with FTS5 full-text search for fast retrieval
- 3-layer search: search → scan → fetch (keeps token usage low)
- Session management with project tracking
- Privacy controls (\`<private>\` tags exclude sensitive content from search)
- Memory compaction for long-running projects
- Export to JSON or Markdown

## Installation

### Cowork
Settings → Plugins → Marketplaces → Add \`MSApps-Mobile/claude-plugins\` → Install \`cowork-mem\`

### Claude Code
\`\`\`
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install cowork-mem@msapps-plugins
\`\`\`

## Usage

Just start working. The skill triggers automatically when you:
- Begin a new session on an ongoing project
- Reference past work ("what did we do last time?")
- Make decisions worth remembering
- Say "remember this", "save this", "recall"

You can also explicitly ask:
- "What do you remember about the auth system?"
- "Show me memory stats"
- "Export our project history"

## Storage

Memories are stored in \`~/.cowork-mem/memory.db\` (in your Cowork workspace folder). The database persists on your machine across sessions.

## Requirements

- Python 3 (included in Cowork sandbox)
- SQLite with FTS5 (included in Cowork sandbox)

## Credits

This plugin was inspired by [claude-mem](https://github.com/thedotmack/claude-mem) by [@thedotmack](https://github.com/thedotmack), which provides persistent memory for Claude Code using hooks, Bun, and MCP. cowork-mem adapts the core concept for Cowork's skill-based architecture.

## License

MIT
