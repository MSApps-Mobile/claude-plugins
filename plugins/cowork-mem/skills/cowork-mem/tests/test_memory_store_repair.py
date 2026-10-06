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


def corrupt_fts(path):
    """Desync the FTS5 index from the base table, as an interrupted write did in the
    incident: rows are committed to `observations` but never reach the inverted index,
    and some index entries are orphaned (rows deleted without the FTS 'delete' command)."""
    c = sqlite3.connect(str(path))
    c.executescript("DROP TRIGGER observations_ai; DROP TRIGGER observations_ad;")
    for i in range(20):
        c.execute(
            "INSERT INTO observations (id,type,content,tags,created_at) VALUES (?,?,?,?,?)",
            (f"obs_x{i:03d}", "note", f"unindexed synthetic {i} widget", "t", "2026-01-02T00:00:00Z"),
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


if __name__ == "__main__":
    unittest.main()
