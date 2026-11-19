"""Run: python3 -m unittest discover -s plugins/directory-manager/skills/directory-stats/tests"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import parse_usage  # noqa: E402

USAGE = "Installs\n1,234 all time\nInstallers\n900\nActive accounts\n120\nOver 28 days · 40 over 7\nUses\n5,000\n"


def run(items):
    d = tempfile.mkdtemp()
    src = os.path.join(d, "captured.json")
    with open(src, "w") as f:
        json.dump(items, f)
    out = os.path.join(d, "out")
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        rc = parse_usage.main([src, out])
    return rc, out


class ParseUsage(unittest.TestCase):
    def test_parses_live_plugin_numbers(self):
        rc, out = run([{"id": "1", "name": "a", "status": "Published", "overview": "", "usage": USAGE}])
        self.assertEqual(rc, 0)
        with open(os.path.join(out, "plugins.json")) as f:
            row = json.load(f)[0]
        self.assertEqual((row["installs_all_time"], row["installers"], row["uses_30d"]), (1234, 900, 5000))

    def test_published_plugin_with_no_numbers_exits_3(self):
        self.assertEqual(run([{"id": "1", "name": "a", "status": "Published", "usage": "changed layout"}])[0], 3)

    def test_non_live_plugin_with_empty_text_is_fine(self):
        self.assertEqual(run([{"id": "2", "name": "b", "status": "Needs changes"}])[0], 0)

    def test_bad_input_exits_2(self):
        self.assertEqual(run(["x", 3])[0], 2)
        self.assertEqual(run({"name": "a"})[0], 2)


if __name__ == "__main__":
    unittest.main()
