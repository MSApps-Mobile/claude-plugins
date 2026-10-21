"""Tests for the UTC timestamp helper (card YAp0c1za). Synthetic rows only.

Run: python3 -m unittest discover -s plugins/cowork-mem/skills/cowork-mem/tests
Strict: python3.13 -W error::DeprecationWarning -m unittest discover -s ...
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
STORE = SCRIPTS / "memory_store.py"
STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$")


def load(db_path):
    os.environ["COWORK_MEM_DB"] = str(db_path)
    spec = importlib.util.spec_from_file_location("memory_store_utc", STORE)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


class UtcNowShape(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.m = load(Path(self.tmp.name) / "memory.db")

    def tearDown(self):
        self.tmp.cleanup()

    def test_helper_is_naive_utc(self):
        self.assertIsNone(self.m._utc_now().tzinfo)

    def test_iso_keeps_the_stored_shape(self):
        stamp = self.m._utc_now_iso()
        self.assertRegex(stamp, STAMP)
        self.assertNotIn("+00:00", stamp)

    def test_old_and_new_rows_order_as_strings(self):
        # An old row written by the previous code, and a row written now.
        old = "2026-01-01T00:00:00Z"
        new = self.m._utc_now_iso()
        self.assertLess(old, new)
        self.assertEqual(sorted([new, old]), [old, new])

    def test_no_deprecated_call_left_in_the_source(self):
        self.assertEqual(STORE.read_text(encoding="utf-8").count("utcnow"), 0)


class CommandPathsUnderWerror(unittest.TestCase):
    """cmd_add, session start/end, timeline, compact and export run with
    DeprecationWarning turned into an error."""

    def run_cli(self, db, *argv):
        env = dict(os.environ, COWORK_MEM_DB=str(db))
        return subprocess.run(
            [sys.executable, "-W", "error::DeprecationWarning", str(STORE), *argv],
            capture_output=True, text=True, env=env, timeout=60,
        )

    def test_add_and_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "memory.db"
            for argv in (
                ("session-start",),
                ("add", "note", "synthetic observation for YAp0c1za"),
                ("timeline",),
                ("compact",),
                ("session-end",),
            ):
                r = self.run_cli(db, *argv)
                self.assertEqual(r.returncode, 0, f"{argv}: {r.stderr}")
            r = self.run_cli(db, "export", "--format", "json")
            self.assertEqual(r.returncode, 0, r.stderr)
            out = json.loads(r.stdout)
            self.assertRegex(out["exported_at"], STAMP)
            stamps = [o["created_at"] for o in out["observations"]]
            self.assertTrue(stamps, "the added observation is exported")
            for s in stamps:
                self.assertRegex(s, STAMP)
            r = self.run_cli(db, "export", "--format", "md")
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertNotIn("+00:00", r.stdout)


if __name__ == "__main__":
    unittest.main()
