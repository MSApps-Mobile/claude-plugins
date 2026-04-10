# Cowork-Mem Command Reference

## Commands

### `add <type> <content> [--tags TAG1,TAG2] [--context TEXT]`

Store an observation. Types: `decision`, `file_edit`, `tool_use`, `insight`, `error`, `note`, `summary`.

Returns: `{"status": "ok", "id": "obs_...", "session_id": "sess_..."}`

Content wrapped in `<private>` tags is stored but excluded from search.

### `search <query> [--limit N] [--type TYPE]`

Full-text search using SQLite FTS5. Supports:
- Single words: `search "postgresql"`
- Multiple words (implicit AND): `search "auth middleware"`
- Prefix matching: `search "auth*"` (matches auth, authentication, authorize...)
- Phrases: `search '"rate limit"'` (exact phrase in double quotes)
- Type filtering: `search "database" --type decision`

Returns compact results (content truncated to 300 chars). Use `get` for full text.

Falls back to LIKE-based search if the FTS query syntax is invalid.

### `timeline [--hours N] [--limit N]`

Chronological list of recent observations. Defaults to last 72 hours, 50 results.
Good for "what happened recently?" context without a specific search query.

### `session-start [--project NAME]`

Start a new session. Closes any open session. Returns:
- Recent context for this project (if project name matches prior sessions)
- Last session's summary

### `session-end [--summary TEXT]`

End the current session. The summary is also stored as a searchable observation.
Include: what was done, what's in progress, what's next.

Returns session stats (observation counts by type).

### `get <id1> [<id2> ...]`

Fetch full observation details by ID. Use after `search` to get complete content
for interesting results.

### `stats`

Memory statistics: total observations, sessions, breakdown by type, date range,
recent sessions, and database path.

### `compact [--before-days N]`

Compress observations older than N days (default 30) into daily summaries.
Merges days with more than 5 observations. Reduces database size while preserving
searchable history.

### `delete <id1> [<id2> ...]`

Permanently remove observations by ID.

### `export [--format json|md]`

Export all non-private observations and sessions. JSON format gives structured
data; Markdown gives human-readable output organized by session.

## Database Location

The database persists at `{workspace}/.cowork-mem/memory.db`. This is on the
user's actual machine, so it survives across Cowork sessions.

Override with `COWORK_MEM_DB` environment variable for testing.

## Schema

**observations**: id, session_id, type, content, context (JSON), tags (csv), created_at, is_private
**sessions**: id, project, started_at, ended_at, summary, stats (JSON)
**observations_fts**: FTS5 virtual table indexing content, tags, and context
