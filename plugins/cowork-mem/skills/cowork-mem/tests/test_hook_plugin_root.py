"""Tests for the cowork-mem PostToolUse hook wiring (card gFeFnGRA). Synthetic data only.

The hook must run the script from the INSTALLED plugin (CLAUDE_PLUGIN_ROOT), never from a
hand-made ~/.claude/skills symlink, and a failure must leave one line in capture-errors.log.

Run: python3 -m unittest discover -s plugins/cowork-mem/skills/cowork-mem/tests
"""
import json
import os
import re
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[3]
HOOKS = PLUGIN / "hooks" / "hooks.json"
SYMLINK_PATH = re.compile(r"~/\.claude/skills|\$HOME/\.claude/skills|\.claude/skills/cowork-mem")


def hook_command():
    d = json.loads(HOOKS.read_text(encoding="utf-8"))
    return d["hooks"]["PostToolUse"][0]["hooks"][0]["command"]


def run_hook(home, plugin_root, payload):
    """Run the hook exactly as the harness does: textual ${CLAUDE_PLUGIN_ROOT} substitution
    in the command string AND the env var exported, through a shell, payload on stdin."""
    cmd = hook_command().replace("${CLAUDE_PLUGIN_ROOT}", str(plugin_root))
    env = {"PATH": os.environ["PATH"], "HOME": str(home), "CLAUDE_PLUGIN_ROOT": str(plugin_root)}
    return subprocess.run(["sh", "-c", cmd], input=json.dumps(payload), env=env,
                          capture_output=True, text=True, timeout=60)


EDIT = {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/synthetic.txt", "old_string": "a", "new_string": "b"},
        "tool_response": "ok"}


class HookPluginRoot(unittest.TestCase):
    def test_no_skills_symlink_path_anywhere_in_plugin(self):
        # known positive first: the matcher must catch the shipped-before string
        self.assertTrue(SYMLINK_PATH.search("python3 ~/.claude/skills/cowork-mem/scripts/x.py"))
        hits = []
        for p in PLUGIN.rglob("*"):
            if p.is_file() and "tests" not in p.parts and p.suffix in {".json", ".md", ".py", ".sh", ""}:
                for n, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                    if "~/.claude/skills" in line or "$HOME/.claude/skills" in line:
                        hits.append(f"{p.relative_to(PLUGIN)}:{n}")
        self.assertEqual(hits, [], hits)

    def test_hook_uses_plugin_root(self):
        self.assertIn("${CLAUDE_PLUGIN_ROOT}", hook_command())

    def test_fresh_home_without_symlink_captures_one_row(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertFalse((Path(home) / ".claude" / "skills").exists())
            r = run_hook(home, PLUGIN, EDIT)
            self.assertEqual(r.returncode, 0, r.stderr)
            db = Path(home) / ".claude" / ".cowork-mem" / "memory.db"
            self.assertTrue(db.exists(), "hook did not create the DB under the fresh HOME")
            con = sqlite3.connect(db)
            try:
                n = con.execute("select count(*) from observations").fetchone()[0]
            finally:
                con.close()
            self.assertEqual(n, 1)
            self.assertFalse((Path(home) / ".claude" / ".cowork-mem" / "capture-errors.log").exists())

    def test_broken_plugin_root_is_non_blocking_and_logs_one_line(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, Path(home) / "no-such-plugin", EDIT)
            self.assertEqual(r.returncode, 0, "hook must stay non-blocking")
            log = Path(home) / ".claude" / ".cowork-mem" / "capture-errors.log"
            self.assertTrue(log.exists(), "a missing script must leave a log line")
            lines = [l for l in log.read_text().splitlines() if l.strip()]
            self.assertEqual(len(lines), 1, lines)
            self.assertIn("HOOK FAILED", lines[0])
            self.assertIn("post_tool_capture.py", lines[0])


if __name__ == "__main__":
    unittest.main()
