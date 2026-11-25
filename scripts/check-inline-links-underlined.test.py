#!/usr/bin/env python3
"""
Trello I6sF6fRf - negative control for check-inline-links-underlined.py.

colour-only.html (inline text-decoration:none, the shape of the real defect) and
class-rule-none.html (the same defect set by a class rule) MUST red;
underlined.html (underlined text links, a link-only row, a card title link) and
the real docs/index.html MUST pass.

Run: python3 scripts/check-inline-links-underlined.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "inline-links-underlined")
SCRIPT = os.path.join(HERE, "check-inline-links-underlined.py")
PAGE = os.path.join(os.path.dirname(HERE), "docs", "index.html")

failures = []


def case(label, page, expect_rc):
    r = subprocess.run([sys.executable, SCRIPT, "--page", page], capture_output=True, text=True)
    ok = r.returncode == expect_rc
    print(("ok   " if ok else "FAIL ") + label + f" (rc={r.returncode}, want {expect_rc}): " + r.stdout.strip())
    if not ok:
        failures.append(label)


case("inline text-decoration:none in a sentence must red", os.path.join(FIX, "colour-only.html"), 1)
case("class rule text-decoration:none in a sentence must red", os.path.join(FIX, "class-rule-none.html"), 1)
case("underlined text links, link-only row and card title must pass", os.path.join(FIX, "underlined.html"), 0)
case("real docs/index.html must pass", PAGE, 0)

sys.exit(1 if failures else 0)
