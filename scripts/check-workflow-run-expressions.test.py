#!/usr/bin/env python3
"""
Trello IcsmluvI - the negative control for check-workflow-run-expressions.py.

A guard that has only ever seen passing input proves nothing, so each fixture
below declares whether it MUST red, and every real workflow must be green.

Run: python3 scripts/check-workflow-run-expressions.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "workflow-run-expressions")
SCRIPT = os.path.join(HERE, "check-workflow-run-expressions.py")
ROOT = os.path.dirname(HERE)

_spec = importlib.util.spec_from_file_location("check_workflow_run_expressions", SCRIPT)
wr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wr)

failures = []


def case(label, path, expect_bad, match=None):
    problems = wr.audit(path)
    text = " ".join(problems)
    rc = subprocess.run([sys.executable, SCRIPT, path], capture_output=True, text=True).returncode
    if bool(problems) != expect_bad or rc != (1 if expect_bad else 0):
        failures.append(f"{label}: expected {'red' if expect_bad else 'green'}, got rc={rc} problems={problems}")
    elif match and match not in text:
        failures.append(f"{label}: output did not mention {match!r}: {text}")
    else:
        print(f"  ok  {label}")


print("negative controls - these MUST red:")
case("matrix entry assigned in a block run:", os.path.join(FIX, "bad-block.yml"), True, match="matrix.plugin")
case("matrix entry inside a Python heredoc", os.path.join(FIX, "bad-heredoc.yml"), True, match="plugin.json")
case("matrix entry in an inline run:", os.path.join(FIX, "bad-inline.yml"), True, match="package-plugin.sh")
case("PR title in a folded run:", os.path.join(FIX, "bad-event-title.yml"), True, match="pull_request.title")

print("known-positive - this MUST be green (expressions in name/if/strategy/env/with only):")
case("env-routed values", os.path.join(FIX, "good.yml"), False)

print("the real repo:")
case("validate-pr.yml", os.path.join(ROOT, ".github", "workflows", "validate-pr.yml"), False)
case("release.yml", os.path.join(ROOT, ".github", "workflows", "release.yml"), False)
case("sosa-lint.yml", os.path.join(ROOT, ".github", "workflows", "sosa-lint.yml"), False)

# Card SNQ5Siev: the no-argument run (what CI calls) must cover every workflow
# in the repo, so a new or forgotten workflow cannot sit outside the guard.
on_disk = sorted(
    os.path.join(".github", "workflows", f)
    for f in os.listdir(os.path.join(ROOT, ".github", "workflows"))
    if f.endswith((".yml", ".yaml"))
)
if sorted(os.path.normpath(p) for p in wr.DEFAULT_WORKFLOWS) != on_disk:
    failures.append(f"DEFAULT_WORKFLOWS {wr.DEFAULT_WORKFLOWS} != workflows on disk {on_disk}")
else:
    print("  ok  DEFAULT_WORKFLOWS covers every workflow on disk")

if failures:
    print("\nFAILED:")
    for f in failures:
        print(f"  {f}")
    sys.exit(1)
print("\nall cases behaved as declared")
