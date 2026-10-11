#!/usr/bin/env python3
"""
Trello okOoGKTA, AC-3 - the negative control.

    "FAILS a PR where any marketplace.json version != plugin.json version -
     prove it RED with a deliberately mismatched fixture first, then green."

Run: python3 scripts/marketplace-versions.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "marketplace-versions")

_spec = importlib.util.spec_from_file_location("marketplace_versions", os.path.join(HERE, "marketplace-versions.py"))
mv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mv)

failures = []


def case(label, root, expect_bad, match=None):
    problems, drifted = mv.audit(root, min_entries=1)
    bad = bool(problems or drifted)
    text = " ".join(problems) + " " + " ".join(f"{n} {a} {b}" for n, a, b in drifted)
    if bad != expect_bad:
        failures.append(f"{label}: expected {'red' if expect_bad else 'green'}, got problems={problems} drifted={drifted}")
    elif match and match not in text:
        failures.append(f"{label}: output did not mention {match!r}: {text}")
    else:
        print(f"  ok  {label}")


print("negative controls - these MUST red:")
case("manifest lists 0.1.0, plugin.json ships 0.2.2", os.path.join(FIX, "drifted"), True, match="0.2.2")
case("a manifest entry whose plugin.json is missing", os.path.join(FIX, "unreadable-plugin-json"), True, match="beta")
problems, _ = mv.audit(os.path.join(FIX, "agrees"), min_entries=5)
if not problems:
    failures.append("min-entries floor: a 1-entry tree passed with min_entries=5")
else:
    print("  ok  the min-entries floor reds a broken walk")

print("known-positive - this MUST be green:")
case("manifest and plugin.json agree", os.path.join(FIX, "agrees"), False)

print("the real repo:")
real = os.path.dirname(HERE)
problems, drifted = mv.audit(real)
if problems or drifted:
    failures.append(f"repo manifest drifted from plugin.json: {problems} {drifted}")
else:
    print("  ok  this repo's marketplace.json agrees with every plugin.json")

print("bump-version.sh writes BOTH files in one run:")
tmp = tempfile.mkdtemp(prefix="mv-bump-")
try:
    work = os.path.join(tmp, "repo")
    shutil.copytree(os.path.join(FIX, "agrees"), work)
    shutil.copytree(HERE, os.path.join(work, "scripts"), ignore=shutil.ignore_patterns("fixtures", "__pycache__"))
    env = dict(os.environ, GIT_CEILING_DIRECTORIES=tmp)
    r = subprocess.run(["bash", "scripts/bump-version.sh", "alpha", "minor"], cwd=work, env=env, capture_output=True, text=True)
    pj = json.load(open(os.path.join(work, "plugins/alpha/.claude-plugin/plugin.json")))["version"]
    mj = json.load(open(os.path.join(work, ".claude-plugin/marketplace.json")))["plugins"][0]["version"]
    if r.returncode != 0 or pj != "1.1.0" or mj != "1.1.0":
        failures.append(f"bump-version.sh: rc={r.returncode} plugin.json={pj} marketplace.json={mj} err={r.stderr[-300:]}")
    else:
        print("  ok  alpha 1.0.0 -> 1.1.0 in plugin.json and marketplace.json")
    # --sync-all repairs a drifted tree and the check then passes
    work2 = os.path.join(tmp, "drift")
    shutil.copytree(os.path.join(FIX, "drifted"), work2)
    mv.sync_all(work2)
    p2, d2 = mv.audit(work2, min_entries=1)
    if p2 or d2:
        failures.append(f"--sync-all did not repair the drifted fixture: {p2} {d2}")
    else:
        print("  ok  --sync-all repairs the drifted fixture")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
