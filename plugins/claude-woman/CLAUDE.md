# claude-woman

Persistent memory plugin for Cowork. Stores observations (decisions, file edits, insights, errors) in a SQLite database with FTS5 full-text search.

Inspired by and based on [claude-mem](https://github.com/thedotmack/claude-mem) by [@thedotmack](https://github.com/thedotmack).

## Setup

No setup required. The memory database is created automatically on first use at `{workspace}/.cowork-mem/memory.db`.

## Architecture

- **Storage**: SQLite with FTS5 full-text search, WAL mode
- **Script**: `skills/cowork-mem/scripts/memory_store.py` — single Python CLI for all operations
- **Commands**: add, search, timeline, session-start, session-end, get, stats, compact, delete, export

## How the skill works

The skill instructs Claude to:
1. Run `session-start` at the beginning of every session to recall prior context
2. Save important observations during work using `add`
3. Search past memories when making decisions or answering questions about history
4. Run `session-end` with a summary when wrapping up

All data persists in the user's workspace folder across Cowork sessions.
