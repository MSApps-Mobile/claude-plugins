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

import contextlib
import importlib.util
import io
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


def lines_of(problems):
    return sorted(int(p.split(":")[1]) for p in problems)


print("negative controls - these MUST red:")
case("token-efficiency-audit CLAUDE.md as on main", "bad-token-efficiency-audit-main", True,
     match="plugins/token-efficiency-audit/CLAUDE.md:169")
case("main-era token-efficiency-audit with the command line removed (still says ALWAYS Push / MUST push)",
     "bad-token-efficiency-audit-main-no-command", True, match="rule D")
case("git push in a shell script", "bad-shell-push", True, match="sync.sh:3")
case("scheduled prompt 'update https://github.com/...'", "bad-update-github-url", True, match="rule C")
case("fenced push whose block names userConfig but not default-off", "bad-optin-not-default-off", True,
     match="CLAUDE.md:6")
case("fenced push whose block states default: false but names no userConfig", "bad-optin-no-userconfig", True,
     match="CLAUDE.md:6")

p, _, _ = lint.audit(os.path.join(FIX, "bad-sh-forms"), [])
if lines_of(p) == [2, 3, 4, 5, 6]:
    print("  ok  every .sh form reds (then/subshell/$()/VAR=x/command)")
else:
    failures.append(f".sh forms: expected lines 2-6 red, got {lines_of(p)}")
p, _, _ = lint.audit(os.path.join(FIX, "bad-md-forms"), [])
if lines_of(p) == [2, 3, 4, 5, 6, 7, 8, 9]:
    print("  ok  every .md wording form reds (ALWAYS push, MUST push, commit and push, Step N, checkbox, label, update-the-repo URL)")
else:
    failures.append(f".md forms: expected lines 2-9 red, got {lines_of(p)}")

print("known-positives - these MUST be green:")
case("token-efficiency-audit CLAUDE.md after PR #76", "good-token-efficiency-audit-after-76", False)
case("github-cli-health-check docs (talk about git push, do not instruct it)",
     "good-github-cli-health-check-docs", False)
case("push inside a block naming a default-off userConfig option", "good-optin-default-off", False)
case("plugin tests/ push to a throwaway bare repo (from claude-plugins#80)",
     "good-test-pushes-to-local-bare", False)

print("allow-list (synthetic lists: the live one is not pinned here):")


def entry(**kw):
    e = {"plugin": "demo", "path": "CLAUDE.md", "line": "git push origin v1.2.3",
         "kind": "permanent", "reason": "sample text"}
    e.update(kw)
    return e


SC = os.path.join(FIX, "scoped-allowlist")
p, sup, stale = lint.audit(SC, [entry()])
# CLAUDE.md:4 allowed; CLAUDE.md:6 (chained push) and OTHER.md:2 (same text, other file) still red.
if lines_of(p) == [2, 6] and len(sup) == 1 and not stale \
        and sum("OTHER.md" in x for x in p) == 1 and sum("CLAUDE.md:6" in x for x in p) == 1:
    print("  ok  entry covers one file + one exact line: same text elsewhere and a chained push still red")
else:
    failures.append(f"scope: problems={p} suppressed={len(sup)} stale={stale}")

p, sup, stale = lint.audit(SC, [entry(path="OTHER.md")])
if any("CLAUDE.md:4" in x for x in p) and len(sup) == 1:
    print("  ok  an entry for another path does not silence this file")
else:
    failures.append(f"path scope: {p} {sup}")

p, sup, stale = lint.audit(SC, [entry(line="git push origin v9")])
if len(p) == 3 and not sup and len(stale) == 1:
    print("  ok  an entry whose text is not there silences nothing and is reported stale")
else:
    failures.append(f"line scope: {p} {sup} {stale}")

# A stale entry FAILS the run (not a warning), whether TODO or permanent.
saved = lint.ALLOWLIST
try:
    for kind_kw in ({}, {"kind": "TODO", "date": "2026-11-06", "reason": "removed by #76"}):
        # isolate staleness with a clean tree
        clean = os.path.join(FIX, "good-optin-default-off")
        lint.ALLOWLIST = [entry(plugin="gone", **kind_kw)]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = lint.main(["--root", clean])
        if rc == 1 and "stale allow-list entry" in out.getvalue():
            print(f"  ok  a stale {kind_kw.get('kind', 'permanent')} entry fails the run")
        else:
            failures.append(f"stale {kind_kw.get('kind', 'permanent')} entry: rc={rc} {out.getvalue()}")
    # malformed entries fail too
    lint.ALLOWLIST = [{"plugin": "demo", "kind": "TODO"}]
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        rc = lint.main(["--root", os.path.join(FIX, "good-optin-default-off")])
    if rc == 1 and "malformed" in out.getvalue():
        print("  ok  a malformed entry (no path/line/date) fails the run")
    else:
        failures.append(f"malformed entry: rc={rc} {out.getvalue()}")
finally:
    lint.ALLOWLIST = saved

for e in lint.ALLOWLIST:
    errs = lint.entry_errors(e)
    if errs:
        failures.append(f"live allow-list entry {e.get('plugin')}/{e.get('path')}: {errs}")

print("the real repo (live allow-list; main must be green):")
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
