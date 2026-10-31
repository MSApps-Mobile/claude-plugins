#!/usr/bin/env python3
"""
Trello TJ93ychx - the negative control for check-no-default-push.py.

A lint that has only ever seen passing input proves nothing, so every fixture
declares whether it MUST red. token-efficiency-audit/CLAUDE.md as on main
(2026-10-31) is the real must-red; the same file at PR #76's head is the real
must-green; github-cli-health-check's docs (which talk about git push without
instructing one) are the negative control for false positives.

Run: python3 scripts/check-no-default-push.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "default-push")
SCRIPT = os.path.join(HERE, "check-no-default-push.py")
ROOT = os.path.dirname(HERE)

_spec = importlib.util.spec_from_file_location("check_no_default_push", SCRIPT)
lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lint)

failures = []


def case(label, fixture, expect_bad, match=None):
    root = os.path.join(FIX, fixture)
    problems, _, _ = lint.audit(root, [])
    text = " ".join(problems)
    rc = subprocess.run([sys.executable, SCRIPT, "--root", root, "--no-allowlist"],
                        capture_output=True, text=True).returncode
    if bool(problems) != expect_bad or rc != (1 if expect_bad else 0):
        failures.append(f"{label}: expected {'red' if expect_bad else 'green'}, got rc={rc} problems={problems}")
    elif match and match not in text:
        failures.append(f"{label}: output did not mention {match!r}: {text}")
    else:
        print(f"  ok  {label}")


print("negative controls - these MUST red:")
case("token-efficiency-audit CLAUDE.md as on main", "bad-token-efficiency-audit-main", True,
     match="plugins/token-efficiency-audit/CLAUDE.md:169")
case("git push in a shell script", "bad-shell-push", True, match="sync.sh:3")
case("scheduled prompt 'update https://github.com/...'", "bad-update-github-url", True, match="rule C")
case("fenced push whose block names userConfig but not default-off", "bad-optin-not-default-off", True,
     match="CLAUDE.md:5")

print("known-positives - these MUST be green:")
case("token-efficiency-audit CLAUDE.md after PR #76", "good-token-efficiency-audit-after-76", False)
case("github-cli-health-check docs (talk about git push, do not instruct it)",
     "good-github-cli-health-check-docs", False)
case("push inside a block naming a default-off userConfig option", "good-optin-default-off", False)

print("allow-list:")
# The real allow-list must silence exactly the plugin it names, and no other one.
for fixture, plugin_hit in (("bad-token-efficiency-audit-main", True), ("bad-shell-push", False)):
    problems, suppressed, _ = lint.audit(os.path.join(FIX, fixture))
    ok = (not problems and bool(suppressed)) if plugin_hit else (bool(problems) and not suppressed)
    if ok:
        print(f"  ok  default allow-list on {fixture}: {'suppressed' if plugin_hit else 'still red'}")
    else:
        failures.append(f"allow-list on {fixture}: problems={problems} suppressed={suppressed}")

# A permanent entry is scoped to its file AND its text: the same text elsewhere reds.
entry = [e for e in lint.ALLOWLIST if e["plugin"] == "notion-memory"]
if not entry or not (entry[0].get("path") and entry[0].get("contains")):
    failures.append("notion-memory allow-list entry must name a path and the exact text")
else:
    p, s, _ = lint.audit(os.path.join(FIX, "bad-shell-push"), entry)
    if p and not s:
        print("  ok  a scoped permanent entry does not silence another plugin")
    else:
        failures.append(f"scoped entry leaked: {p} {s}")

# Every TODO entry must carry a date and name the PR(s) it waits on.
for e in lint.ALLOWLIST:
    if e["kind"] == "TODO" and not (e.get("date") and "#" in e["reason"]):
        failures.append(f"TODO entry for {e['plugin']} needs a date and a PR reference")

print("the real repo (default allow-list; main must be green):")
r = subprocess.run([sys.executable, SCRIPT, "--root", ROOT], capture_output=True, text=True)
if r.returncode != 0:
    failures.append(f"real repo: rc={r.returncode}\n{r.stdout}{r.stderr}")
else:
    print("  ok  plugins/ is clean")

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
