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
import shutil
import sqlite3
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
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

FTS_DDL = """CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
    content,
    tags,
    context,
    content=observations,
    content_rowid=rowid
)"""

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
{FTS_DDL}

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
""".replace("{FTS_DDL}", FTS_DDL.strip() + ";")

# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

# Filesystem types where SQLite's journal/locking is unreliable (Cowork's
# workspace mount is FUSE/network backed).
_FUSE_FSTYPES = ("fuse", "9p", "virtiofs", "vboxsf", "nfs", "cifs", "smb")
INTEGRITY_RECHECK_SECONDS = 24 * 3600


def _is_fuse_path(path: Path) -> bool:
    """True when `path` lives on the Cowork FUSE/network workspace mount.

    Reads /proc/mounts (Linux/Cowork VM) and picks the longest mount point
    that prefixes the DB path. Non-Linux hosts (macOS) have no /proc/mounts
    and are treated as regular filesystems.
    """
    if os.environ.get("COWORK_MEM_FORCE_FUSE") == "1":
        return True
    try:
        target = str(Path(path).resolve())
        best_len, best_type = -1, ""
        with open("/proc/mounts", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                parts = line.split()
                if len(parts) < 3:
                    continue
                mnt = parts[1].replace("\\040", " ")
                if (target == mnt or target.startswith(mnt.rstrip("/") + "/")) and len(mnt) > best_len:
                    best_len, best_type = len(mnt), parts[2]
        return best_type.startswith(_FUSE_FSTYPES)
    except OSError:
        return False


class MemoryDBError(Exception):
    """Raised when the DB is damaged and could not be repaired."""


class DBBusy(Exception):
    """The DB is locked / hit a transient I/O error. NOT corruption: never repaired."""


KEEP_PRE_REPAIR_COPIES = 3
REPAIR_BACKOFF_SECONDS = 3600
_CORRUPT_MARKERS = ("malformed", "corrupt", "not a database", "encrypted")
_CORRUPT_CODES = (11, 26)  # SQLITE_CORRUPT, SQLITE_NOTADB


def _busy_timeout() -> float:
    try:
        return float(os.environ.get("COWORK_MEM_BUSY_TIMEOUT", "10"))
    except ValueError:
        return 10.0


def _is_corruption(exc: BaseException) -> bool:
    """The ONLY classifier that may authorise a repair.

    Lock/busy and disk-I/O errors (SQLITE_BUSY/LOCKED/IOERR) are never
    corruption: a concurrent writer must not make a healthy DB look damaged.
    """
    if not isinstance(exc, sqlite3.DatabaseError):
        return False
    msg = str(exc).lower()
    if "locked" in msg or "busy" in msg or "disk i/o" in msg:
        return False
    code = getattr(exc, "sqlite_errorcode", None)
    if code is not None and (code & 0xFF) in _CORRUPT_CODES:
        return True
    return any(s in msg for s in _CORRUPT_MARKERS)


def _marker_path() -> Path:
    return Path(str(DB_PATH) + ".integrity-ok")


def _fail_marker_path() -> Path:
    return Path(str(DB_PATH) + ".repair-failed")


def _configure(conn: sqlite3.Connection, fuse: bool, tolerant: bool = False) -> None:
    """Pragma set shared by _open_conn, the integrity check and repair.

    tolerant=True swallows corruption-class errors so a damaged file can still
    be inspected/repaired; lock/IO errors always propagate.
    """
    try:
        conn.execute(f"PRAGMA busy_timeout={int(_busy_timeout() * 1000)}")
        mode = None
        if not fuse:
            # Durable on-disk rollback journal: an interrupted write is rolled
            # back on next open instead of leaving the DB inconsistent.
            try:
                mode = conn.execute("PRAGMA journal_mode=TRUNCATE").fetchone()[0].lower()
            except sqlite3.OperationalError as e:
                if _is_corruption(e):
                    raise
                mode = None
        if mode != "truncate":
            # WARNING: Cowork's workspace mount (FUSE/network FS) cannot do WAL or
            # DELETE journals. MEMORY is only used there (or if a durable journal
            # is refused): single-user, single-process, commit after every write.
            conn.execute("PRAGMA journal_mode=MEMORY")
            conn.execute("PRAGMA locking_mode=EXCLUSIVE")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA foreign_keys=ON")
    except sqlite3.DatabaseError as e:
        if not (tolerant and _is_corruption(e)):
            raise


def _connect(fuse: bool, tolerant: bool = False, autocommit: bool = False) -> sqlite3.Connection:
    conn = sqlite3.connect(
        str(DB_PATH), timeout=_busy_timeout(), isolation_level=None if autocommit else ""
    )
    try:
        _configure(conn, fuse, tolerant)
    except BaseException:
        conn.close()
        raise
    return conn


def _integrity_problems(conn: sqlite3.Connection) -> list:
    """Return a list of problems (empty = healthy).

    Only corruption-class findings are returned as problems. Lock/IO errors
    are re-raised so callers can back off instead of "repairing" a healthy DB.
    """
    problems = []
    try:
        for (msg,) in conn.execute("PRAGMA quick_check").fetchall():
            if msg != "ok":
                problems.append(msg)
    except sqlite3.DatabaseError as e:
        if not _is_corruption(e):
            raise
        problems.append(str(e))
    try:
        conn.execute("INSERT INTO observations_fts(observations_fts, rank) VALUES('integrity-check', 1)")
    except sqlite3.DatabaseError as e:
        if "no such table" in str(e).lower():
            pass  # SCHEMA (re)creates it on open; not corruption
        elif not _is_corruption(e):
            raise
        else:
            problems.append(f"fts5 integrity-check: {e}")
    return problems


def _prune_pre_repair_copies(keep: int = KEEP_PRE_REPAIR_COPIES) -> None:
    copies = sorted(
        p for p in Path(DB_PATH).parent.glob(Path(DB_PATH).name + ".pre-repair-*")
        if p.suffix not in ("-journal", "-wal", "-shm") and not p.name.endswith(("-journal", "-wal", "-shm"))
    )
    for old in copies[:-keep] if keep > 0 else copies:
        for suffix in ("", "-journal", "-wal", "-shm"):
            try:
                Path(str(old) + suffix).unlink()
            except OSError:
                pass


def backup_db(reason: str = "pre-repair") -> Path:
    """Copy the DB (and sidecars) aside. Call with the write lock held (repair_db does)."""
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    dest = Path(f"{DB_PATH}.{reason}-{stamp}")
    shutil.copy2(DB_PATH, dest)
    for suffix in ("-journal", "-wal", "-shm"):
        side = Path(str(DB_PATH) + suffix)
        if side.exists():
            shutil.copy2(side, Path(str(dest) + suffix))
    _prune_pre_repair_copies()
    return dest


def _end_txn(conn: sqlite3.Connection, verb: str) -> None:
    try:
        conn.execute(verb)
    except sqlite3.Error:
        pass  # no transaction open (e.g. unparseable file)


def repair_db() -> dict:
    """Prove corruption under a held write lock, then back up, rebuild, re-check.

    * Lock/IO errors raise DBBusy and never touch the index.
    * A healthy DB is left alone (returns repaired=False).
    * DROP TABLE observations_fts only runs after corruption was confirmed AND
      FTS 'rebuild' itself failed with a corruption-class error.
    Raises MemoryDBError if the DB is still damaged afterwards.
    """
    if not Path(DB_PATH).exists():
        raise MemoryDBError(f"no database at {DB_PATH}")
    fuse = _is_fuse_path(DB_PATH)
    try:
        conn = _connect(fuse, tolerant=True, autocommit=True)
    except sqlite3.DatabaseError as e:
        if _is_corruption(e):
            raise
        raise DBBusy(str(e)) from e
    try:
        try:
            conn.execute("BEGIN IMMEDIATE")  # waits busy_timeout, holds through rebuild
        except sqlite3.DatabaseError as e:
            # A file SQLite cannot even parse has no lock to take: go on to the
            # (read-only) proof and let the rebuild report it as unrepairable.
            if not _is_corruption(e):
                raise DBBusy(str(e)) from e
        try:
            try:
                problems = _integrity_problems(conn)
            except sqlite3.OperationalError as e:
                raise DBBusy(str(e)) from e
            if not problems:
                _end_txn(conn, "ROLLBACK")
                return {"repaired": False, "reason": "no corruption found"}
            backup = backup_db()
            before = None
            try:
                before = conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
            except sqlite3.DatabaseError:
                pass
            try:
                conn.execute("INSERT INTO observations_fts(observations_fts) VALUES('rebuild')")
            except sqlite3.DatabaseError as e:
                if not _is_corruption(e) and "no such table" not in str(e).lower():
                    raise
                # Confirmed corruption and FTS shadow tables unusable: recreate from base table.
                conn.execute("DROP TABLE IF EXISTS observations_fts")
                conn.execute(FTS_DDL)
                conn.execute("INSERT INTO observations_fts(observations_fts) VALUES('rebuild')")
            conn.execute("REINDEX")
            remaining = _integrity_problems(conn)
            if remaining:
                _end_txn(conn, "ROLLBACK")
                raise MemoryDBError(
                    f"repair failed, still damaged: {'; '.join(remaining)} (backup: {backup})"
                )
            after = conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0]
            conn.execute("COMMIT")
        except sqlite3.DatabaseError as e:
            _end_txn(conn, "ROLLBACK")
            if _is_corruption(e):
                raise MemoryDBError(f"unrepairable: {e}") from e
            raise DBBusy(str(e)) from e
        except BaseException:
            _end_txn(conn, "ROLLBACK")
            raise
    finally:
        conn.close()
    for p in (_marker_path(),):
        try:
            p.touch()
        except OSError:
            pass
    return {"repaired": True, "backup": str(backup), "rows_before": before, "rows_after": after,
            "problems": problems}


def _auto_repair(trigger: str):
    """Repair + warn + back-off. Called ONLY from run_with_db(), never with a connection open.

    Honours a back-off marker so an unrepairable DB is not re-copied on every
    hook call. Returns the repair info, or None when nothing was repaired.
    """
    fail = _fail_marker_path()
    try:
        if time.time() - fail.stat().st_mtime < REPAIR_BACKOFF_SECONDS:
            raise MemoryDBError(
                f"database is damaged and the last repair failed; auto-repair suppressed "
                f"for {REPAIR_BACKOFF_SECONDS}s (see {fail}); trigger: {trigger}"
            )
    except OSError:
        pass
    try:
        info = repair_db()
    except DBBusy as e:
        print(json.dumps({"status": "warning", "message": f"repair skipped, database busy: {e}"}),
              file=sys.stderr)
        return None
    except MemoryDBError as e:
        try:
            fail.write_text(f"{datetime.now(timezone.utc).isoformat()} {e}\n")
        except OSError:
            pass
        raise
    try:
        fail.unlink()
    except OSError:
        pass
    if info.get("repaired"):
        print(json.dumps({"status": "warning", "message": f"database was damaged and auto-repaired ({trigger})",
                          **info}), file=sys.stderr)
        return info
    return None


def _scheduled_integrity_problems() -> list:
    """Cheap-by-default check, at most once per INTEGRITY_RECHECK_SECONDS.

    Returns the corruption problems found (empty = healthy, skipped or busy).
    Never repairs: the check connection is closed before this returns, so the
    single repair site in run_with_db() never races a lock held by it.
    """
    marker = _marker_path()
    try:
        if time.time() - marker.stat().st_mtime < INTEGRITY_RECHECK_SECONDS:
            return []
    except OSError:
        pass  # no marker yet -> check
    if not Path(DB_PATH).exists():
        return []
    try:
        conn = _connect(_is_fuse_path(DB_PATH), tolerant=True)
        try:
            problems = _integrity_problems(conn)
        finally:
            conn.close()
    except sqlite3.DatabaseError as e:
        if not _is_corruption(e):
            return []  # locked / transient I/O (busy_timeout already waited): check next time
        problems = [str(e)]
    if not problems:
        try:
            marker.touch()
        except OSError:
            pass
    return problems


def _open_conn(fuse: bool) -> sqlite3.Connection:
    conn = _connect(fuse)
    conn.row_factory = sqlite3.Row
    try:
        conn.executescript(SCHEMA)
    except BaseException:
        conn.close()
        raise
    return conn


# Connections currently held by run_with_db(). Repair must never run while one is
# open: on FUSE (journal MEMORY + locking_mode EXCLUSIVE) an open connection keeps
# the file lock, so repair's BEGIN IMMEDIATE would wait out busy_timeout and fail.
_open_sessions = 0


def run_with_db(op=None):
    """THE single check -> repair -> retry site. Every caller goes through here.

    1. Scheduled integrity check (its connection is closed before any repair).
    2. Open a connection and run ``op(db)``; the connection is ALWAYS closed
       (finally) before control leaves this frame, success or failure.
    3. On a corruption-class error (at open or mid-command): repair once with no
       connection of ours open, then retry once. Lock/IO errors are never
       repaired and propagate unchanged.

    ``op=None`` returns an open connection for library callers (get_db); the
    caller owns closing it and must do so before any later run_with_db call.
    """
    global _open_sessions
    fuse = _is_fuse_path(DB_PATH)
    problems = _scheduled_integrity_problems()
    trigger = f"integrity check: {'; '.join(problems)}" if problems else None
    for attempt in range(2):
        if trigger:
            if _open_sessions:
                raise RuntimeError("repair requested while a cowork-mem connection is still open")
            _auto_repair(trigger)
        try:
            db = _open_conn(fuse)  # closes itself if SCHEMA fails
            if op is None:
                return db
            _open_sessions += 1
            try:
                return op(db)
            finally:
                _open_sessions -= 1
                db.close()
        except sqlite3.DatabaseError as e:
            if attempt or not _is_corruption(e):
                raise
            trigger = f"command: {e}"


def get_db() -> sqlite3.Connection:
    """Open, checked (and if needed repaired) connection. Caller must close it."""
    return run_with_db()


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_add(db, args):
    """Add an observation to memory."""
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

    print(json.dumps({"status": "ok", "id": obs_id, "session_id": session_id}))


def cmd_search(db, args):
    """Search memories using FTS5 full-text search."""
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

    print(json.dumps({"status": "ok", "count": len(results), "results": results}, indent=2))


def cmd_timeline(db, args):
    """Get recent observations in chronological order."""
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
    print(json.dumps({"status": "ok", "count": len(results), "since": since, "results": results}, indent=2))


def cmd_session_start(db, args):
    """Start a new memory session."""
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


def cmd_session_end(db, args):
    """End the current session with an optional summary."""
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
    print(json.dumps({"status": "ok", "session_id": session_id, "stats": stats}))


def cmd_get(db, args):
    """Fetch full details for specific observation IDs."""
    placeholders = ",".join("?" for _ in args.ids)
    rows = db.execute(
        f"SELECT * FROM observations WHERE id IN ({placeholders})",
        args.ids,
    ).fetchall()

    results = [dict(r) for r in rows]
    print(json.dumps({"status": "ok", "results": results}, indent=2))


def cmd_stats(db, args):
    """Show memory statistics."""

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


def cmd_compact(db, args):
    """Compress old observations to save space.

    Merges observations older than N days into daily summaries,
    keeping the originals' key information but reducing row count.
    """
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
    print(json.dumps({"status": "ok", "compacted_observations": compacted, "days_processed": len(rows)}))


def cmd_delete(db, args):
    """Delete specific observations by ID."""
    placeholders = ",".join("?" for _ in args.ids)
    db.execute(f"DELETE FROM observations WHERE id IN ({placeholders})", args.ids)
    db.commit()
    print(json.dumps({"status": "ok", "deleted": args.ids}))


def cmd_export(db, args):
    """Export all memories."""
    fmt = args.format or "json"

    observations = db.execute(
        "SELECT * FROM observations WHERE is_private = 0 ORDER BY created_at"
    ).fetchall()
    sessions = db.execute("SELECT * FROM sessions ORDER BY started_at").fetchall()

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
        run_with_db(lambda db: commands[args.command](db, args))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
