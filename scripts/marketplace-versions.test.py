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
    # Card SNQ5Siev: a version that is not plain x.y.z is refused BEFORE bash
    # arithmetic evaluates it (a part like 'BASH_VERSINFO[$(cmd)]' runs cmd, even under set -u).
    work3 = os.path.join(tmp, "badver")
    shutil.copytree(os.path.join(FIX, "agrees"), work3)
    shutil.copytree(HERE, os.path.join(work3, "scripts"), ignore=shutil.ignore_patterns("fixtures", "__pycache__"))
    pj3 = os.path.join(work3, "plugins/alpha/.claude-plugin/plugin.json")
    d3 = json.load(open(pj3))
    d3["version"] = "1.0.BASH_VERSINFO[$(touch PWNED)]"
    json.dump(d3, open(pj3, "w"))
    r3 = subprocess.run(["bash", "scripts/bump-version.sh", "alpha", "patch"], cwd=work3, env=env, capture_output=True, text=True)
    after = json.load(open(pj3))["version"]
    if r3.returncode == 0 or os.path.exists(os.path.join(work3, "PWNED")) or after != d3["version"]:
        failures.append(f"bump-version.sh accepted a non-x.y.z version: rc={r3.returncode} version={after!r} pwned={os.path.exists(os.path.join(work3, 'PWNED'))}")
    else:
        print("  ok  non-x.y.z version refused, nothing executed, plugin.json untouched")

    # Card tIL3cCkK: the plugin name (a folder name from merged repo content)
    # and the plugin.json path built from it were pasted into inline Python
    # source, so a crafted folder name ran code in release.yml's bump step.
    # Each payload below must leave no PWNED file, and bump-version.sh must
    # either refuse (non-zero, plugin.json untouched) or bump normally.
    payloads = [
        # the card's literal example
        "a'];import os;os.system('touch PWNED');#",
        # breaks out of the single-quoted open('...') in the version read
        "a'+str(__import__('os').system('touch PWNED'))+'",
        # breaks out of the double-quoted path = \"...\" in the bump heredoc
        'a"+str(__import__("os").system("touch PWNED"))+"',
    ]

    def evil_tree(label, plugin):
        """A copy of the agrees fixture whose only plugin lives in folder `plugin`."""
        work = os.path.join(tmp, label)
        shutil.copytree(os.path.join(FIX, "agrees"), work)
        shutil.copytree(HERE, os.path.join(work, "scripts"), ignore=shutil.ignore_patterns("fixtures", "__pycache__"))
        os.rename(os.path.join(work, "plugins", "alpha"), os.path.join(work, "plugins", plugin))
        return work

    def no_injection(label, work, plugin, run_dir=None):
        pjson = os.path.join(work, "plugins", plugin, ".claude-plugin", "plugin.json")
        before = json.load(open(pjson))["version"]
        r = subprocess.run(["bash", "scripts/bump-version.sh", plugin, "patch"], cwd=work, env=env, capture_output=True, text=True)
        after = json.load(open(pjson))["version"]
        pwned = [p for p in (os.path.join(work, "PWNED"), os.path.join(work, "scripts", "PWNED")) if os.path.exists(p)]
        refused = r.returncode != 0 and after == before
        bumped = r.returncode == 0 and before == "1.0.0" and after == "1.0.1"
        if pwned or not (refused or bumped):
            failures.append(f"{label}: rc={r.returncode} version {before}->{after} pwned={pwned} err={r.stderr[-300:]!r}")
        else:
            print(f"  ok  {label}: {'refused' if refused else 'bumped normally'}, nothing executed")

    for i, plugin in enumerate(payloads):
        no_injection(f"crafted plugin name #{i + 1}", evil_tree(f"evil-name-{i}", plugin), plugin)

    # The plugin.json path also carries the checkout path (REPO_ROOT), which a
    # name allow-list does not cover: a quote in the checkout directory must
    # not reach Python source either. The plugin name here is a valid one, so
    # this must bump normally.
    for i, payload in enumerate(payloads[1:]):
        root = os.path.join(tmp, f"evil-root-{i}", payload)
        os.makedirs(os.path.dirname(root))
        shutil.copytree(os.path.join(FIX, "agrees"), root)
        shutil.copytree(HERE, os.path.join(root, "scripts"), ignore=shutil.ignore_patterns("fixtures", "__pycache__"))
        no_injection(f"crafted checkout path #{i + 1}", root, "alpha")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
