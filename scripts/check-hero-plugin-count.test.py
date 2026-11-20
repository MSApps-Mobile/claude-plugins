#!/usr/bin/env python3
"""
Trello rkdB5zOu - negative control for check-hero-plugin-count.py.

mismatch.html is the page as it stood (hero 29, 30 cards) and MUST red;
match.html (hero 30, 30 cards) and the real docs/index.html MUST pass.

Run: python3 scripts/check-hero-plugin-count.test.py
Exit 0 = every case behaved as declared, INCLUDING the one that must fail.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "hero-plugin-count")
SCRIPT = os.path.join(HERE, "check-hero-plugin-count.py")
PAGE = os.path.join(os.path.dirname(HERE), "docs", "index.html")

failures = []


def case(label, page, expect_rc):
    r = subprocess.run([sys.executable, SCRIPT, "--page", page], capture_output=True, text=True)
    ok = r.returncode == expect_rc
    print(("ok   " if ok else "FAIL ") + label + f" (rc={r.returncode}, want {expect_rc}): " + r.stdout.strip())
    if not ok:
        failures.append(label)


case("mismatch fixture (hero 29, 30 cards) must red", os.path.join(FIX, "mismatch.html"), 1)
case("matching fixture must pass", os.path.join(FIX, "match.html"), 0)
case("real docs/index.html must pass", PAGE, 0)

sys.exit(1 if failures else 0)
