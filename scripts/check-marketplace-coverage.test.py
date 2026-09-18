#!/usr/bin/env python3
"""
Trello 1zBkhSZm, AC-3 — the negative control.

    "Pair it with a negative control — add a fixture that omits one entry and
     prove the check reds — or it is a guard that has only ever seen passing
     input."

Run: python3 scripts/check-marketplace-coverage.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import os
import sys

# The script's filename carries hyphens, so it cannot be imported by name.
# Load it by path instead — explicit, and it keeps the production script a
# plain executable rather than bending its name to suit its test.
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "marketplace_coverage",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "check-marketplace-coverage.py"),
)
mc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mc)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
FIX = os.path.join(HERE, "fixtures", "marketplace-coverage")

failures = []


def case(label, root, exclusions, expect_problems, match=None, min_dirs=1):
    problems, _ = mc.audit(root, exclusions=exclusions, min_dirs=min_dirs)
    got = len(problems) > 0
    if got != expect_problems:
        failures.append(
            f"{label}: expected {'problems' if expect_problems else 'no problems'}, "
            f"got {len(problems)}: {problems}"
        )
        return
    if match and not any(match in p for p in problems):
        failures.append(f"{label}: problems did not mention {match!r} — got {problems}")
        return
    print(f"  ok  {label}")


print("negative controls — these MUST red:")
case(
    "a plugin dir absent from the manifest and not excluded",
    os.path.join(FIX, "missing-entry"),
    {},
    True,
    match="plugins/beta/",
)
case(
    "a manifest entry whose directory does not exist",
    os.path.join(FIX, "dangling-source"),
    {},
    True,
    match="does not exist",
)
case(
    "an exclusion naming a directory that is gone (stale permission)",
    os.path.join(FIX, "agrees"),
    {"vanished": "some reason"},
    True,
    match="no longer exists",
)
case(
    "an exclusion with an EMPTY reason — a silent carve-out",
    os.path.join(FIX, "missing-entry"),
    {"beta": "    "},
    True,
    match="no reason written",
)
case(
    "the VACUITY floor — a walk that found almost nothing must not pass",
    os.path.join(FIX, "agrees"),
    {},
    True,
    match="VACUITY",
    min_dirs=20,
)

print("known-positives — these MUST pass, or the guard is just always-red:")
case("a fixture where the sets agree", os.path.join(FIX, "agrees"), {}, False)
case(
    "the same defect, once the exclusion is RECORDED with a reason",
    os.path.join(FIX, "missing-entry"),
    {"beta": "held pending a disposition, per the card"},
    False,
)

print("the live repo — must pass at its recorded exclusions:")
problems, summary = mc.audit(REPO)
if problems:
    failures.append(f"live repo: {problems}")
else:
    print(
        f"  ok  live repo — {summary['plugin_dirs']} dirs · "
        f"{summary['manifest_entries']} manifest entries · "
        f"{summary['pending_disposition']} pending disposition"
    )

# Card 1zBkhSZm AC-2: opsagent-shopify must be PUBLISHED (in the manifest),
# not lingering in PENDING_DISPOSITION. The assertion below fails loud if the
# exclusion quietly returns.
if "opsagent-shopify" in mc.PENDING_DISPOSITION:
    failures.append(
        "opsagent-shopify is still in PENDING_DISPOSITION — AC-2 requires it published "
        "(in marketplace.json) and removed from the exclusion list"
    )
else:
    names = mc.manifest_names(REPO)
    dirs = mc.plugin_dirs(REPO) or []
    if "opsagent-shopify" not in names:
        failures.append("opsagent-shopify missing from marketplace.json after publish disposition")
    elif "opsagent-shopify" not in dirs:
        failures.append("opsagent-shopify is in the manifest but plugins/opsagent-shopify/ is gone")
    else:
        print("  ok  opsagent-shopify PUBLISHED (card 1zBkhSZm AC-2)")

if "agents-md-optimizer" in mc.PENDING_DISPOSITION:
    failures.append("agents-md-optimizer still pending — should be published")
elif "agents-md-optimizer" not in (mc.manifest_names(REPO)):
    failures.append("agents-md-optimizer missing from marketplace.json after publish disposition")
else:
    print("  ok  agents-md-optimizer PUBLISHED (card 1zBkhSZm AC-1)")

if "msapps-public plugins" not in mc.PENDING_DISPOSITION:
    failures.append(
        "msapps-public plugins missing from PENDING_DISPOSITION — physical delete deferred; "
        "exclusion with DELETE reason must remain until workflow-scope fix lands"
    )
elif "msapps-public plugins" not in (mc.plugin_dirs(REPO) or []):
    failures.append("msapps-public plugins dir gone but exclusion remains — remove stale PENDING entry")
else:
    print("  ok  msapps-public plugins EXCLUDE/DELETE recorded (physical delete deferred, card 1zBkhSZm)")

if failures:
    print("\n✗ FAILURES:")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print("\n✓ all cases behaved as declared, including every red branch")
