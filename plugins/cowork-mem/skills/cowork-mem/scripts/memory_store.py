#!/usr/bin/env python3
"""
cowork-mem: Persistent memory engine for Cowork sessions.

Mirrors claude-mem's 3-layer architecture:
  1. Observations â individual facts, decisions, file edits, tool usage
  2. Sessions â summaries of complete work sessions
  3. Search â FTS5 full-text search with recency weighting

Storage: SQLite with FTS5, stored in the user's workspace folder so it
persists across Cowork sessions.

Usage:
  python memory_store.py add <type> <content> [--tags tag1,tag2] [--context ...]
  python memory_store.py search <query> [--limit N] [--type TYPE]
  python memory_store.py timeline [--hours N] [--limit N]
  python memory_store.py session-start [--project NAME]
  python memory_store.py session-end [--summary TEXT]
  python memory_store.py get <id1> [<id2> ...]
  python memory_store.py stats
  python memory_store.py compact [--before-days N]
  python memory_store.py delete <id1> [<id2> ...]
  python memory_store.py export [--format json|md]
"""

import argparse
import json
import os
import sqlite3
import sys
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path

# ---------------------------------------------------------------------------
# Database location â lives in the user's workspace folder so it persists
# ---------------------------------------------------------------------------

def _find_db_path() -> Path:
    """Find or create the memory database path.

    Priority:
    1. COWORK_MEM_DB env var (for testing)
    2. Workspace folder (persists on user's machine)
    3. Fallback to session working directory
    """
    if env_path := os.environ.get("COWORK_MEM_DB"):
        return Path(env_path)

    # Look for the workspace mount (persists on user's machine).
    # Cowork uses "mnt/outputs" as the default persistent folder;
    # older/custom setups may use "mnt/Claude" or a user-selected folder.
    candidates = []
    session_id = os.environ.get("SESSION_ID", "")

    # Walk up from cwd to find a mnt directory with a known subfolder
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        for subfolder in ("outputs", "Claude"):
            mount = parent / "mnt" / subfolder
            if mount.exists() and mount.is_dir():
                candidates.insert(0, mount / ".cowork-mem")
                break

    # Also try the /sessions/<id>/mnt/ path directly
    if session_id:
        for subfolder in ("outputs", "Claude"):
            candidates.append(
                Path("/sessions") / session_id / "mnt" / subfolder / ".cowork-mem"
            )

    for candidate in candidates:
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            return candidate / "memory.db"
        except OSError:
            continue

    # Last resort: current directory
    fallback = Path.cwd() / ".cowork-mem"
    fallback.mkdir(parents=True, exist_ok=True)
    return fallback / "memory.db"


DB_PATH = _find_db_path()

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

SCHEMA = """
CREATE TABLE IF NOT EXISTS observations (
    id          TEXT PRIMARY KEY,
    session_id  TEXT,
    type        TEXT NOT NULL,       -- decision, file_edit, tool_use, insight, error, note, summary
    content     TEXT NOT NULL,
    context     TEXT,                -- JSON: file paths, tool names, related IDs
    tags        TEXT,                -- comma-separated
    created_at  TEXT NOT NULL,       -- ISO 8601
    is_private  INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sessions (
    id          TEXT PRIMARY KEY,
    project     TEXT,
    started_at  TEXT NOT NULL,
    ended_at    TEXT,
    summary     TEXT,
    stats       TEXT                 -- JSON: token counts, tools used, files touched
);

-- Full-text search index
CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
    content,
    tags,
    context,
    content=observations,
    content_rowid=rowid
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS observations_ai AFTER INSERT ON observations BEGIN
    INSERT INTO observations_fts(rowid, content, tags, context)
    VALUES (new.rowid, new.content, new.tags, new.context);
END;

CREATE TRIGGER IF NOT EXISTS observations_ad AFTER DELETE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, content, tags, context)
    VALUES ('delete', old.rowid, old.content, old.tags, old.context);
END;

CREATE TRIGGER IF NOT EXISTS observations_au AFTER UPDATE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, content, tags, context)
    VALUES ('delete', old.rowid, old.content, old.tags, old.context);
    INSERT INTO observations_fts(rowid, content, tags, context)
    VALUES (new.rowid, new.content, new.tags, new.context);
END;

-- Index for timeline queries
CREATE INDEX IF NOT EXISTS idx_obs_created ON observations(created_at);
CREATE INDEX IF NOT EXISTS idx_obs_session ON observations(session_id);
CREATE INDEX IF NOT EXISTS idx_obs_type ON observations(type);
"""

# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    # Use MEMORY journal mode — WAL and DELETE fail on Cowork's workspace
    # mount (FUSE/network FS). MEMORY is safe here: single-user, single-
    # process, and we commit after every write.
    conn.execute("PRAGMA journal_mode=MEMORY")
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("PRAGMA locking_mode=EXCLUSIVE")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA)
    return conn


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_add(args):
    """Add an observation to memory."""
    db = get_db()
    obs_id = f"obs_{uuid.uuid4().hex[:12]}"
    now = datetime.utcnow().isoformat() + "Z"

    # Find current session
    session_id = None
    row = db.execute(
        "SELECT id FROM sessions WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1"
    ).fetchone()
    if row:
        session_id = row["id"]

    # Check for <private> tags
    is_private = 1 if "<private>" in (args.content or "") else 0
    content = args.content.replace("<private>", "").replace("</private>", "").strip()

    context_json = json.dumps({"raw": args.context}) if args.context else None
    tags = ",".join(t.strip() for t in args.tags.split(",")) if args.tags else None

    db.execute(
        """INSERT INTO observations (id, session_id, type, content, context, tags, created_at, is_private)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (obs_id, session_id, args.type, content, context_json, tags, now, is_private),
    )
    db.commit()
    db.close()

    print(json.dumps({"status": "ok", "id": obs_id, "session_id": session_id}))


def cmd_search(args):
    """Search memories using FTS5 full-text search."""
    db = get_db()
    limit = args.limit or 20

    # Build FTS query â simple word matching with prefix support
    query_terms = args.query.strip()

    sql = """
        SELECT o.id, o.type, o.content, o.tags, o.context, o.created_at, o.session_id,
               rank
        FROM observations_fts fts
        JOIN observations o ON o.rowid = fts.rowid
        WHERE observations_fts MATCH ?
          AND o.is_private = 0
    """
    params = [query_terms]

    if args.type:
        sql += " AND o.type = ?"
        params.append(args.type)

    # Order by relevance (rank) with recency boost
    sql += """
        ORDER BY (rank * -1.0) + (julianday(o.created_at) - julianday('now', '-30 days')) * 0.1
        LIMIT ?
    """
    params.append(limit)

    try:
        rows = db.execute(sql, params).fetchall()
    except sqlite3.OperationalError:
        # If FTS query syntax fails, fall back to LIKE search
        sql = """
            SELECT id, type, content, tags, context, created_at, session_id, 0 as rank
            FROM observations
            WHERE content LIKE ? AND is_private = 0
        """
        params = [f"%{query_terms}%"]
        if args.type:
            sql += " AND type = ?"
            params.append(args.type)
        sql += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        rows = db.execute(sql, params).fetchall()

    results = []
    for r in rows:
        results.append({
            "id": r["id"],
            "type": r["type"],
            "content": r["content"][:300],  # Truncate for compact results
            "tags": r["tags"],
            "created_at": r["created_at"],
            "session_id": r["session_id"],
        })

    db.close()
    print(json.dumps({"status": "ok", "count": len(results), "results": results}, indent=2))


def cmd_timeline(args):
    """Get recent observations in chronological order."""
    db = get_db()
    hours = args.hours or 72
    limit = args.limit or 50
    since = (datetime.utcnow() - timedelta(hours=hours)).isoformat() + "Z"

    rows = db.execute(
        """SELECT id, type, content, tags, created_at, session_id
           FROM observations
           WHERE created_at > ? AND is_private = 0
           ORDER BY created_at DESC
           LIMIT ?""",
        (since, limit),
    ).fetchall()

    results = [dict(r) for r in rows]
    db.close()
    print(json.dumps({"status": "ok", "count": len(results), "since": since, "results": results}, indent=2))


def cmd_session_start(args):
    """Start a new memory session."""
    db = get_db()
    session_id = f"sess_{uuid.uuid4().hex[:12]}"
    now = datetime.utcnow().isoformat() + "Z"

    # Close any open sessions
    db.execute("UPDATE sessions SET ended_at = ? WHERE ended_at IS NULL", (now,))

    db.execute(
        "INSERT INTO sessions (id, project, started_at) VALUES (?, ?, ?)",
        (session_id, args.project, now),
    )
    db.commit()

    # Get recent context for this project
    context = []
    if args.project:
        rows = db.execute(
            """SELECT content, type, created_at FROM observations
               WHERE session_id IN (
                   SELECT id FROM sessions WHERE project = ? AND id != ?
               )
               AND is_private = 0
               ORDER BY created_at DESC LIMIT 10""",
            (args.project, session_id),
        ).fetchall()
        context = [dict(r) for r in rows]

    # Also get the last session summary
    last_summary = db.execute(
        """SELECT summary, project, ended_at FROM sessions
           WHERE ended_at IS NOT NULL AND summary IS NOT NULL
           ORDER BY ended_at DESC LIMIT 1"""
    ).fetchone()

    db.close()

    result = {
        "status": "ok",
        "session_id": session_id,
        "project": args.project,
        "recent_context": context,
    }
    if last_summary:
        result["last_session"] = {
            "summary": last_summary["summary"],
            "project": last_summary["project"],
            "ended_at": last_summary["ended_at"],
        }

    print(json.dumps(result, indent=2))


def cmd_session_end(args):
    """End the current session with an optional summary."""
    db = get_db()
    now = datetime.utcnow().isoformat() + "Z"

    row = db.execute(
        "SELECT id FROM sessions WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1"
    ).fetchone()

    if not row:
        print(json.dumps({"status": "error", "message": "No active session"}))
        return

    session_id = row["id"]

    # Gather session stats
    stats = {}
    obs_rows = db.execute(
        "SELECT type, COUNT(*) as cnt FROM observations WHERE session_id = ? GROUP BY type",
        (session_id,),
    ).fetchall()
    stats["observation_counts"] = {r["type"]: r["cnt"] for r in obs_rows}
    stats["total_observations"] = sum(r["cnt"] for r in obs_rows)

    db.execute(
        "UPDATE sessions SET ended_at = ?, summary = ?, stats = ? WHERE id = ?",
        (now, args.summary, json.dumps(stats), session_id),
    )

    # Also store the summary as an observation for searchability
    if args.summary:
        obs_id = f"obs_{uuid.uuid4().hex[:12]}"
        db.execute(
            """INSERT INTO observations (id, session_id, type, content, created_at)
               VALUES (?, ?, 'summary', ?, ?)""",
            (obs_id, session_id, args.summary, now),
        )

    db.commit()
    db.close()
    print(json.dumps({"status": "ok", "session_id": session_id, "stats": stats}))


def cmd_get(args):
    """Fetch full details for specific observation IDs."""
    db = get_db()
    placeholders = ",".join("?" for _ in args.ids)
    rows = db.execute(
        f"SELECT * FROM observations WHERE id IN ({placeholders})",
        args.ids,
    ).fetchall()

    results = [dict(r) for r in rows]
    db.close()
    print(json.dumps({"status": "ok", "results": results}, indent=2))


def cmd_stats(args):
    """Show memory statistics."""
    db = get_db()

    total_obs = db.execute("SELECT COUNT(*) as c FROM observations").fetchone()["c"]
    total_sessions = db.execute("SELECT COUNT(*) as c FROM sessions").fetchone()["c"]
    by_type = db.execute(
        "SELECT type, COUNT(*) as c FROM observations GROUP BY type ORDER BY c DESC"
    ).fetchall()

    oldest = db.execute("SELECT MIN(created_at) as m FROM observations").fetchone()["m"]
    newest = db.execute("SELECT MAX(created_at) as m FROM observations").fetchone()["m"]

    recent_sessions = db.execute(
        """SELECT id, project, started_at, ended_at, summary
           FROM sessions ORDER BY started_at DESC LIMIT 5"""
    ).fetchall()

    db.close()
    print(json.dumps({
        "status": "ok",
        "db_path": str(DB_PATH),
        "total_observations": total_obs,
        "total_sessions": total_sessions,
        "by_type": {r["type"]: r["c"] for r in by_type},
        "oldest": oldest,
        "newest": newest,
        "recent_sessions": [dict(r) for r in recent_sessions],
    }, indent=2))


def cmd_compact(args):
    """Compress old observations to save space.

    Merges observations older than N days into daily summaries,
    keeping the originals' key information but reducing row count.
    """
    db = get_db()
    days = args.before_days or 30
    cutoff = (datetime.utcnow() - timedelta(days=days)).isoformat() + "Z"

    # Group old observations by date
    rows = db.execute(
        """SELECT DATE(created_at) as day, GROUP_CONCAT(content, ' | ') as combined,
                  COUNT(*) as cnt
           FROM observations
           WHERE created_at < ? AND type != 'summary'
           GROUP BY DATE(created_at)
           HAVING cnt > 5""",
        (cutoff,),
    ).fetchall()

    compacted = 0
    for r in rows:
        day = r["day"]
        combined = r["combined"]
        cnt = r["cnt"]

        # Create a compacted summary
        obs_id = f"obs_{uuid.uuid4().hex[:12]}"
        db.execute(
            """INSERT INTO observations (id, type, content, tags, created_at)
               VALUES (?, 'summary', ?, 'compacted', ?)""",
            (obs_id, f"[Compacted {cnt} observations] {combined[:2000]}", f"{day}T23:59:59Z"),
        )

        # Remove originals
        db.execute(
            "DELETE FROM observations WHERE DATE(created_at) = ? AND type != 'summary' AND created_at < ?",
            (day, cutoff),
        )
        compacted += cnt

    db.commit()
    db.close()
    print(json.dumps({"status": "ok", "compacted_observations": compacted, "days_processed": len(rows)}))


def cmd_delete(args):
    """Delete specific observations by ID."""
    db = get_db()
    placeholders = ",".join("?" for _ in args.ids)
    db.execute(f"DELETE FROM observations WHERE id IN ({placeholders})", args.ids)
    db.commit()
    db.close()
    print(json.dumps({"status": "ok", "deleted": args.ids}))


def cmd_export(args):
    """Export all memories."""
    db = get_db()
    fmt = args.format or "json"

    observations = db.execute(
        "SELECT * FROM observations WHERE is_private = 0 ORDER BY created_at"
    ).fetchall()
    sessions = db.execute("SELECT * FROM sessions ORDER BY started_at").fetchall()
    db.close()

    if fmt == "json":
        print(json.dumps({
            "exported_at": datetime.utcnow().isoformat() + "Z",
            "observations": [dict(r) for r in observations],
            "sessions": [dict(r) for r in sessions],
        }, indent=2))
    else:
        # Markdown export
        print("# Cowork Memory Export\n")
        print(f"*Exported: {datetime.utcnow().isoformat()}Z*\n")
        for s in sessions:
            print(f"## Session: {s['project'] or 'unnamed'} ({s['started_at'][:10]})")
            if s["summary"]:
                print(f"\n{s['summary']}\n")
            sess_obs = [o for o in observations if o["session_id"] == s["id"]]
            for o in sess_obs:
                print(f"- **[{o['type']}]** {o['content'][:200]}")
            print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="cowork-mem: persistent memory for Cowork")
    sub = parser.add_subparsers(dest="command", required=True)

    # add
    p = sub.add_parser("add", help="Add an observation")
    p.add_argument("type", choices=["decision", "file_edit", "tool_use", "insight", "error", "note", "summary"])
    p.add_argument("content", help="The observation text")
    p.add_argument("--tags", default=None, help="Comma-separated tags")
    p.add_argument("--context", default=None, help="Additional context (JSON string or free text)")

    # search
    p = sub.add_parser("search", help="Search memories")
    p.add_argument("query", help="Search query (natural language)")
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--type", default=None, help="Filter by observation type")

    # timeline
    p = sub.add_parser("timeline", help="Recent observations")
    p.add_argument("--hours", type=int, default=72)
    p.add_argument("--limit", type=int, default=50)

    # session-start
    p = sub.add_parser("session-start", help="Start a session")
    p.add_argument("--project", default=None, help="Project name")

    # session-end
    p = sub.add_parser("session-end", help="End current session")
    p.add_argument("--summary", default=None, help="Session summary")

    # get
    p = sub.add_parser("get", help="Fetch observations by ID")
    p.add_argument("ids", nargs="+", help="Observation IDs")

    # stats
    sub.add_parser("stats", help="Show memory statistics")

    # compact
    p = sub.add_parser("compact", help="Compress old observations")
    p.add_argument("--before-days", type=int, default=30)

    # delete
    p = sub.add_parser("delete", help="Delete observations")
    p.add_argument("ids", nargs="+", help="Observation IDs to delete")

    # export
    p = sub.add_parser("export", help="Export all memories")
    p.add_argument("--format", choices=["json", "md"], default="json")

    args = parser.parse_args()

    commands = {
        "add": cmd_add,
        "search": cmd_search,
        "timeline": cmd_timeline,
        "session-start": cmd_session_start,
        "session-end": cmd_session_end,
        "get": cmd_get,
        "stats": cmd_stats,
        "compact": cmd_compact,
        "delete": cmd_delete,
        "export": cmd_export,
    }

    try:
        commands[args.command](args)
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
