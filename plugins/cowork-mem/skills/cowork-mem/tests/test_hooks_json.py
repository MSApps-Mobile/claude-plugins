"""Tests for the PostToolUse hook command in hooks/hooks.json (card gFeFnGRA).

The hook used to run ~/.claude/skills/cowork-mem/... (a path outside the plugin
that only exists where someone made a symlink) and swallowed every error, so on
a fresh install capture was dead with no signal. These run the real command
through sh with a throwaway HOME, so no symlink and no real memory DB is used.

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

PLUGIN_ROOT = Path(__file__).resolve().parents[3]  # plugins/cowork-mem
HOOKS = PLUGIN_ROOT / "hooks" / "hooks.json"
SKILLS_PATH = re.compile(r"~/\.claude/skills|\$HOME/\.claude/skills")

EDIT_EVENT = {
    "tool_name": "Edit",
    "tool_input": {"file_path": "/tmp/gFeFnGRA-probe.txt", "old_string": "a", "new_string": "b"},
    "tool_response": {"content": "The file /tmp/gFeFnGRA-probe.txt has been updated."},
}


def hook_command():
    d = json.loads(HOOKS.read_text(encoding="utf-8"))
    [entry] = d["hooks"]["PostToolUse"]
    [hook] = entry["hooks"]
    return hook["command"]


def run_hook(home, plugin_root, event=EDIT_EVENT):
    env = {"HOME": str(home), "PATH": os.environ["PATH"], "CLAUDE_PLUGIN_ROOT": str(plugin_root)}
    return subprocess.run(
        ["sh", "-c", hook_command()], input=json.dumps(event),
        capture_output=True, text=True, env=env, timeout=90,
    )


class HookPath(unittest.TestCase):
    def test_known_positive_the_old_command_matches(self):
        old = ("COWORK_MEM_DB=~/.claude/.cowork-mem/memory.db python3 "
               "~/.claude/skills/cowork-mem/scripts/post_tool_capture.py 2>/dev/null || true")
        self.assertRegex(old, SKILLS_PATH)

    def test_command_runs_from_the_plugin_root(self):
        cmd = hook_command()
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/skills/cowork-mem/scripts/post_tool_capture.py", cmd)
        self.assertNotRegex(cmd, SKILLS_PATH)

    def test_no_skills_path_anywhere_in_the_plugin(self):
        hits = []
        for p in PLUGIN_ROOT.rglob("*"):
            if p.is_file() and p.suffix in {".json", ".md", ".py", ".sh"} and p.name != Path(__file__).name:
                if "~/.claude/skills" in p.read_text(encoding="utf-8", errors="replace"):
                    hits.append(str(p.relative_to(PLUGIN_ROOT)))
        self.assertEqual(hits, [])


class HookBehaviour(unittest.TestCase):
    def test_broken_script_path_exits_0_and_logs_one_line(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, Path(home) / "no-such-plugin")
            self.assertEqual(r.returncode, 0, r.stderr)
            log = Path(home) / ".claude" / ".cowork-mem" / "capture-errors.log"
            lines = log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines), 1, lines)
            self.assertIn("post_tool_capture.py exited", lines[0])

    def test_fresh_home_without_symlink_captures_one_edit(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertFalse((Path(home) / ".claude" / "skills").exists())
            r = run_hook(home, PLUGIN_ROOT)
            self.assertEqual(r.returncode, 0, r.stderr)
            db = Path(home) / ".claude" / ".cowork-mem" / "memory.db"
            self.assertTrue(db.exists(), "the hook created the DB under the throwaway HOME")
            con = sqlite3.connect(db)
            try:
                rows = con.execute("SELECT type, content FROM observations").fetchall()
            finally:
                con.close()
            self.assertEqual(len(rows), 1, rows)
            self.assertEqual(rows[0][0], "file_edit")
            self.assertIn("gFeFnGRA-probe.txt", rows[0][1])
            log = Path(home) / ".claude" / ".cowork-mem" / "capture-errors.log"
            self.assertFalse(log.exists() and log.read_text().strip(), "no error logged on success")


if __name__ == "__main__":
    unittest.main()
