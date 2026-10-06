"""Tests for cowork-mem DB hardening (card dId4lcGa). Synthetic rows only.

Run: python3 -m unittest discover -s plugins/cowork-mem/skills/cowork-mem/tests
"""
import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"


def load(db_path):
    os.environ["COWORK_MEM_DB"] = str(db_path)
    spec = importlib.util.spec_from_file_location("memory_store_t", SCRIPTS / "memory_store.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def seed(m, n=200):
    db = m.get_db()
    for i in range(n):
        db.execute(
            "INSERT INTO observations (id,type,content,tags,created_at) VALUES (?,?,?,?,?)",
            (f"obs_{i:04d}", "note", f"synthetic row {i} alpha{i % 7} widget", "t", "2026-01-01T00:00:00Z"),
        )
    db.commit()
    db.close()


def corrupt_fts(path, tag=None):
    """Desync the FTS5 index from the base table, as an interrupted write did in the
    incident: rows are committed to `observations` but never reach the inverted index,
    and some index entries are orphaned (rows deleted without the FTS 'delete' command)."""
    c = sqlite3.connect(str(path))
    c.executescript("DROP TRIGGER observations_ai; DROP TRIGGER observations_ad;")
    for i in range(20):
        c.execute(
            "INSERT INTO observations (id,type,content,tags,created_at) VALUES (?,?,?,?,?)",
            (f"obs_x{tag or ''}{i:03d}", "note", f"unindexed synthetic {i} widget", "t", "2026-01-02T00:00:00Z"),
        )
    c.execute("DELETE FROM observations WHERE id IN ('obs_0001','obs_0002','obs_0003')")
    c.commit()
    c.close()
    # Triggers are recreated by the next get_db() via SCHEMA (IF NOT EXISTS).


class RepairTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "memory.db"
        self.m = load(self.db)

    def tearDown(self):
        self.tmp.cleanup()

    def rows(self):
        c = sqlite3.connect(str(self.db))
        r = c.execute("SELECT id, content FROM observations ORDER BY id").fetchall()
        c.close()
        return r

    def marker_clear(self):
        p = self.m._marker_path()
        if p.exists():
            p.unlink()

    def test_autorepair_zero_row_loss(self):
        seed(self.m)
        corrupt_fts(self.db)
        before = self.rows()
        self.assertEqual(217, len(before))
        c = sqlite3.connect(str(self.db))
        self.assertTrue(self.m._integrity_problems(c), "fixture must actually be corrupt")
        c.close()
        self.marker_clear()
        self.m.get_db().close()
        self.assertEqual(before, self.rows())
        c = sqlite3.connect(str(self.db))
        self.assertEqual([], self.m._integrity_problems(c))
        hits = c.execute(
            "SELECT COUNT(*) FROM observations_fts WHERE observations_fts MATCH 'widget'"
        ).fetchone()[0]
        c.close()
        self.assertEqual(217, hits)
        self.assertTrue(list(self.db.parent.glob("memory.db.pre-repair-*")), "pre-repair copy missing")

    def test_cli_search_repairs_and_succeeds(self):
        seed(self.m)
        corrupt_fts(self.db)
        before = self.rows()
        self.marker_clear()
        env = dict(os.environ, COWORK_MEM_DB=str(self.db))
        r = subprocess.run([sys.executable, str(SCRIPTS / "memory_store.py"), "search", "widget"],
                           capture_output=True, text=True, env=env)
        self.assertEqual(0, r.returncode, r.stderr)
        self.assertEqual("ok", json.loads(r.stdout)["status"])
        self.assertEqual(before, self.rows())

    def test_healthy_db_uses_marker_and_skips_check(self):
        seed(self.m, 5)
        self.m.get_db().close()
        self.assertTrue(self.m._marker_path().exists())
        calls = []
        orig = self.m._integrity_problems
        self.m._integrity_problems = lambda c: calls.append(1) or orig(c)
        self.m.get_db().close()
        self.assertEqual([], calls)

    def test_durable_journal_and_synchronous_normal(self):
        db = self.m.get_db()
        self.assertEqual("truncate", db.execute("PRAGMA journal_mode").fetchone()[0])
        self.assertEqual(1, db.execute("PRAGMA synchronous").fetchone()[0])  # NORMAL
        db.close()

    def test_fuse_falls_back_to_memory_journal(self):
        os.environ["COWORK_MEM_FORCE_FUSE"] = "1"
        try:
            db = self.m.get_db()
            self.assertEqual("memory", db.execute("PRAGMA journal_mode").fetchone()[0])
            self.assertEqual(1, db.execute("PRAGMA synchronous").fetchone()[0])
            db.close()
        finally:
            del os.environ["COWORK_MEM_FORCE_FUSE"]

    def test_unrepairable_write_failure_is_loud(self):
        self.db.write_bytes(b"this is not a sqlite database" * 100)
        env = dict(os.environ, COWORK_MEM_DB=str(self.db))
        r = subprocess.run([sys.executable, str(SCRIPTS / "memory_store.py"), "add", "note", "x"],
                           capture_output=True, text=True, env=env)
        self.assertNotEqual(0, r.returncode)
        self.assertIn('"status": "error"', r.stderr)

    def test_hook_logs_failed_write(self):
        spec = importlib.util.spec_from_file_location("ptc", SCRIPTS / "post_tool_capture.py")
        ptc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ptc)
        self.db.write_bytes(b"garbage" * 500)
        os.environ["COWORK_MEM_DB"] = str(self.db)
        ptc.save_observation("note", "hello")
        log = self.db.parent / "capture-errors.log"
        self.assertTrue(log.exists())
        self.assertIn("WRITE FAILED", log.read_text())


class LockAndBackoffTests(unittest.TestCase):
    """Reviewer findings 1, 2, 4, 5 (PR #42): BUSY is never corruption."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "memory.db"
        os.environ["COWORK_MEM_BUSY_TIMEOUT"] = "0.2"
        self.m = load(self.db)
        self.repairs = []
        orig = self.m.repair_db
        self.m.repair_db = lambda: self.repairs.append(1) or orig()

    def tearDown(self):
        os.environ.pop("COWORK_MEM_BUSY_TIMEOUT", None)
        os.environ.pop("COWORK_MEM_FORCE_FUSE", None)
        self.tmp.cleanup()

    rows = RepairTests.rows

    def clear_marker(self):
        if self.m._marker_path().exists():
            self.m._marker_path().unlink()

    def backups(self):
        return [p for p in self.db.parent.glob("memory.db.pre-repair-*") if not p.name.endswith(("-journal", "-wal", "-shm"))]

    def fts_hits(self):
        c = sqlite3.connect(str(self.db))
        n = c.execute("SELECT COUNT(*) FROM observations_fts WHERE observations_fts MATCH 'widget'").fetchone()[0]
        c.close()
        return n

    def lock(self):
        holder = sqlite3.connect(str(self.db), isolation_level=None)
        holder.execute("BEGIN EXCLUSIVE")
        return holder

    def test_classifier(self):
        E = sqlite3
        self.assertFalse(self.m._is_corruption(E.OperationalError("database is locked")))
        self.assertFalse(self.m._is_corruption(E.OperationalError("database table is locked")))
        self.assertFalse(self.m._is_corruption(E.OperationalError("disk I/O error")))
        self.assertTrue(self.m._is_corruption(E.DatabaseError("database disk image is malformed")))
        self.assertTrue(self.m._is_corruption(E.DatabaseError("file is not a database")))
        self.assertFalse(self.m._is_corruption(ValueError("malformed")))

    def test_locked_healthy_db_is_never_repaired(self):
        seed(self.m)
        holder = self.lock()
        try:
            with self.assertRaises(sqlite3.OperationalError) as cm:
                self.m.get_db()
            self.assertIn("locked", str(cm.exception))
            self.assertEqual([], self.repairs, "repair must not run on a locked DB")
            with self.assertRaises(self.m.DBBusy):
                self.m.repair_db()
            c = sqlite3.connect(str(self.db), timeout=0.1)
            with self.assertRaises(sqlite3.OperationalError):
                self.m._integrity_problems(c)  # re-raises, not "problems"
            c.close()
        finally:
            holder.execute("ROLLBACK")
            holder.close()
        self.assertEqual([], self.backups())
        self.assertEqual(200, self.fts_hits())  # index intact, nothing dropped
        c = sqlite3.connect(str(self.db))
        self.assertEqual([], self.m._integrity_problems(c))
        c.close()

    def test_cli_on_locked_db_errors_without_repair(self):
        seed(self.m)
        holder = self.lock()
        try:
            env = dict(os.environ, COWORK_MEM_DB=str(self.db))
            r = subprocess.run([sys.executable, str(SCRIPTS / "memory_store.py"), "search", "widget"],
                               capture_output=True, text=True, env=env)
        finally:
            holder.execute("ROLLBACK")
            holder.close()
        self.assertEqual(1, r.returncode)
        self.assertIn("locked", r.stderr)
        self.assertNotIn("auto-repaired", r.stderr)
        self.assertEqual([], self.backups())
        self.assertEqual(200, self.fts_hits())

    def test_repair_db_on_healthy_db_is_noop(self):
        seed(self.m)
        info = self.m.repair_db()
        self.assertFalse(info["repaired"])
        self.assertEqual([], self.backups())
        self.assertEqual(200, self.fts_hits())

    def test_fuse_forced_repair_uses_shared_pragma_helper(self):
        os.environ["COWORK_MEM_FORCE_FUSE"] = "1"
        seed(self.m)
        corrupt_fts(self.db)
        before = self.rows()
        self.clear_marker()
        seen = []
        orig = self.m._configure
        self.m._configure = lambda conn, fuse, tolerant=False: seen.append((fuse, tolerant)) or orig(conn, fuse, tolerant)
        self.m.get_db().close()
        self.assertIn((True, True), seen)  # check + repair connections got fuse=True
        self.assertTrue(all(f for f, _ in seen))
        self.assertEqual(before, self.rows())
        self.assertEqual(217, self.fts_hits())
        self.assertEqual(1, len(self.backups()))

    def test_unrepairable_backs_off_without_more_copies(self):
        self.db.write_bytes(b"this is not a sqlite database" * 100)
        for _ in range(3):
            with self.assertRaises(Exception):
                self.m.get_db()
        self.assertEqual(1, len(self.backups()), "back-off must stop repeated full copies")
        self.assertTrue(self.m._fail_marker_path().exists())

    def test_pre_repair_copies_are_capped(self):
        seed(self.m, 20)
        for _ in range(self.m.KEEP_PRE_REPAIR_COPIES + 3):
            corrupt_fts(self.db, tag=str(_))
            self.clear_marker()
            self.m.get_db().close()
        self.assertLessEqual(len(self.backups()), self.m.KEEP_PRE_REPAIR_COPIES)

    def test_backup_runs_under_held_write_lock(self):
        seed(self.m)
        corrupt_fts(self.db)
        outcome = []
        orig = self.m.backup_db

        def spy(*a, **k):
            c = sqlite3.connect(str(self.db), timeout=0.1)
            try:
                c.execute("BEGIN IMMEDIATE")
                outcome.append("writer-got-lock")
            except sqlite3.OperationalError:
                outcome.append("locked")
            finally:
                c.close()
            return orig(*a, **k)

        self.m.backup_db = spy
        self.clear_marker()
        self.m.get_db().close()
        self.assertEqual(["locked"], outcome)


if __name__ == "__main__":
    unittest.main()
