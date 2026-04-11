# cowork-mem

**Stop wasting tokens re-explaining your project every session.**

cowork-mem gives Claude persistent memory across Cowork sessions. Instead of burning thousands of tokens re-establishing context every time you start a new chat, Claude remembers what happened — decisions made, bugs fixed, architecture chosen, files changed — and picks up right where you left off.

> Inspired by [claude-mem](https://github.com/thedotmack/claude-mem) by [@thedotmack](https://github.com/thedotmack). Rebuilt natively for Cowork.

## The Problem

Every new Cowork session starts from zero. Claude doesn't know what you built yesterday, what you decided last week, or what broke an hour ago. So you spend the first 5-10 minutes (and hundreds of tokens) catching Claude up. Multiply that across dozens of sessions and you're wasting serious context window on repeat information.

## The Fix

cowork-mem stores observations, decisions, and session summaries in a local SQLite database. When you start a new session, Claude pulls only what's relevant — using a 3-layer retrieval pattern that minimizes token usage:

1. **Search** — FTS5 full-text search finds matching memories (returns IDs + snippets, not full content)
2. **Scan** — Quick scan of results to identify what's actually relevant
3. **Fetch** — Only retrieve the full text of memories that matter
This means Claude loads context in tens of tokens instead of thousands. Your context window stays free for actual work.

## Features

- **Token-efficient recall** — 3-layer search → scan → fetch keeps context lean
- **Automatic session tracking** — Claude saves what matters as you work, recaps when you return
- **SQLite + FTS5** — Fast full-text search across all past sessions, stored locally on your machine
- **Project-aware** — Memories are tagged by project so context stays relevant
- **Privacy controls** — `<private>` tags exclude sensitive content from search
- **Memory compaction** — Consolidates old memories to keep the database lean
- **Export** — Dump your project history to JSON or Markdown anytime

## Installation

### Cowork
Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install `cowork-mem`

### Claude Code
```
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install cowork-mem@msapps-plugins
```
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

Memories are stored in `~/.cowork-mem/memory.db` (in your Cowork workspace folder). The database persists on your machine across sessions.

## Requirements

- Python 3 (included in Cowork sandbox)
- SQLite with FTS5 (included in Cowork sandbox)

## Credits

This plugin was inspired by [claude-mem](https://github.com/thedotmack/claude-mem) by [@thedotmack](https://github.com/thedotmack), which provides persistent memory for Claude Code using hooks, Bun, and MCP. cowork-mem adapts the core concept for Cowork's skill-based architecture.

## License

MIT