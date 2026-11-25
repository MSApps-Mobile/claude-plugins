#!/usr/bin/env python3
"""
Trello IMjjDwAS AC-3 - the known-positive and the negative controls for
check-catalogue-matches-marketplace.py, run against committed fixtures.

Run: python3 scripts/check-catalogue-matches-marketplace.test.py
Exit 0 = every case behaved as declared, including the ones that must fail.
"""

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
FIX = os.path.join(HERE, "fixtures", "catalogue-matches-marketplace")

_spec = importlib.util.spec_from_file_location(
    "catalogue_check", os.path.join(HERE, "check-catalogue-matches-marketplace.py")
)
cc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cc)

failures = []


def run(root):
    with open(os.path.join(root, cc.PAGE), encoding="utf-8") as fh:
        html = fh.read()
    problems, _ = cc.audit(html, root, cc.load_hidden(os.path.join(root, cc.HIDDEN)))
    return problems


def case(label, root, expect_fail, match=None):
    problems = run(root)
    if bool(problems) != expect_fail:
        failures.append(f"{label}: expected {'problems' if expect_fail else 'none'}, got {problems}")
        return
    if match and not any(match in p for p in problems):
        failures.append(f"{label}: problems did not mention {match!r}: {problems}")
        return
    print(f"  ok  {label}")


print("known-positive - this MUST pass:")
case("page, marketplace and allow-list agree", os.path.join(FIX, "agrees"), False)
print("negative controls - these MUST fail:")
case("marketplace plugin with no card, not allow-listed", os.path.join(FIX, "missing-card"), True, "'c'")
case("card for a plugin missing from marketplace.json", os.path.join(FIX, "card-not-in-marketplace"), True, "'ghost'")
case("allow-list names a plugin no longer in the marketplace", os.path.join(FIX, "stale-allow-list"), True, "'gone'")
case("allow-listed plugin that also has a card", os.path.join(FIX, "hidden-but-shown"), True, "has a card")
case("allow-list entry with no reason", os.path.join(FIX, "empty-reason"), True, "no reason")

print("the real repo:")
case("this repo's page and marketplace", REPO, False)

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
