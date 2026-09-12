#!/usr/bin/env python3
"""
DOES plugins/ AGREE WITH THE MANIFEST USERS ACTUALLY INSTALL FROM?

Trello 1zBkhSZm. Measured 2026-09-04 and RE-MEASURED 2026-09-12 on `main`:
33 directories under plugins/, 30 entries in .claude-plugin/marketplace.json,
and the board anchor said 29. Three numbers, three sources, one live defect.

    In the repo, absent from the manifest:
      opsagent-shopify        <- THE REPO'S MOST RECENT RELEASE, tag
                                 opsagent-shopify-v0.3.7, published 2026-08-26.
                                 The newest thing we shipped is the one nobody
                                 can install.
      agents-md-optimizer     <- a live, in-fleet plugin
      'msapps-public plugins' <- a directory name WITH A SPACE IN IT; almost
                                 certainly a stray path, not a plugin

WHY NOTHING CAUGHT IT. release.yml, sosa-lint.yml and validate-pr.yml all exist
and all pass. Not one of them compares the directory set to the manifest set, so
a released plugin sat unpublished for over a week with no red signal anywhere:
the success signal and the failure signal were the same green build.

WHAT THIS SCRIPT RULES ON — and what it deliberately does NOT.
It rules on AGREEMENT, never on DISPOSITION. Whether opsagent-shopify should be
published is a judgement call the card assigns to /opsagents-cto, and publishing
to a public marketplace is an outward-facing act. So every directory must be
either IN the manifest or in PENDING_DISPOSITION below WITH A WRITTEN REASON —
and the moment a decision is made, the entry moves or the exclusion is deleted.
An undecided directory is a failure state that is visible, not a silent gap.

Usage:
    python3 scripts/check-marketplace-coverage.py [--root .]

Exit 0 = the sets agree modulo the recorded exclusions. Exit 1 = they do not.
"""

import argparse
import json
import os
import sys

# ── The exclusion list: every directory NOT in the manifest, with the reason ──
#
# This list may only SHRINK. Each entry is an open decision, not a permanent
# carve-out, and the script reds if an entry names a directory that no longer
# exists — a stale exclusion reads as "we know about this one" long after the
# code changed, which is the same rot the manifest itself suffered.
PENDING_DISPOSITION = {
    "opsagent-shopify": (
        "RELEASED BUT UNPUBLISHED — tag opsagent-shopify-v0.3.7 (2026-08-26) points at "
        "content no user can install. Trello 1zBkhSZm AC-2 resolves this FIRST. The fix is "
        "either to publish it or to un-tag / mark it pre-release; leaving a released tag "
        "pointing at unpublished content is the one option the card rules out."
    ),
    "agents-md-optimizer": (
        "live, in-fleet plugin, absent from the manifest. Disposition (publish vs keep "
        "internal) is Trello 1zBkhSZm AC-1 and belongs to /opsagents-cto."
    ),
    "msapps-public plugins": (
        "directory name CONTAINS A SPACE — almost certainly a stray or mis-created path "
        "rather than a plugin. Trello 1zBkhSZm AC-1 says confirm and DELETE rather than "
        "publish. Kept listed so the deletion is a decision somebody makes, not a thing "
        "that quietly persists."
    ),
}

# A scan that finds nothing is indistinguishable from a scan that finds no
# problems. This repo ships 30+ plugins; if we ever see fewer than this many
# directories the walk is broken, not the tree.
MIN_PLUGIN_DIRS = 20


def plugin_dirs(root):
    """Every direct child directory of plugins/."""
    base = os.path.join(root, "plugins")
    if not os.path.isdir(base):
        return None
    return sorted(n for n in os.listdir(base) if os.path.isdir(os.path.join(base, n)))


def manifest_names(root):
    """Every plugin NAME the marketplace manifest publishes."""
    path = os.path.join(root, ".claude-plugin", "marketplace.json")
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    out = []
    for entry in data.get("plugins", []):
        if isinstance(entry, dict) and entry.get("name"):
            out.append(entry["name"])
    return sorted(out)


def manifest_sources(root):
    """Map published name -> the directory its `source` points at."""
    path = os.path.join(root, ".claude-plugin", "marketplace.json")
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    out = {}
    for entry in data.get("plugins", []):
        if isinstance(entry, dict) and entry.get("name") and entry.get("source"):
            out[entry["name"]] = os.path.basename(str(entry["source"]).rstrip("/"))
    return out


def audit(root, exclusions=None, min_dirs=MIN_PLUGIN_DIRS):
    """Returns (problems, summary). Pure apart from the two reads above."""
    exclusions = PENDING_DISPOSITION if exclusions is None else exclusions
    problems = []

    dirs = plugin_dirs(root)
    if dirs is None:
        return ([f"no plugins/ directory under {root!r} — the walk found nothing to check"], {})

    if len(dirs) < min_dirs:
        problems.append(
            f"VACUITY: only {len(dirs)} plugin directories found, expected at least {min_dirs}. "
            f"A walk that measured nothing must not report 'the manifest agrees'."
        )

    names = manifest_names(root)
    sources = manifest_sources(root)
    published_dirs = set(sources.values())

    # 1. a directory that is neither published nor consciously excluded
    for d in dirs:
        if d in published_dirs or d in names:
            continue
        if d in exclusions:
            continue
        problems.append(
            f"plugins/{d}/ is in the repo but NOT in .claude-plugin/marketplace.json, and not "
            f"listed in PENDING_DISPOSITION.\n"
            f"    Publish it, or record the reason it stays unpublished. An undecided plugin is "
            f"what let a RELEASED tag point at uninstallable content for over a week."
        )

    # 2. a manifest entry whose directory does not exist — publishing a path that isn't there
    for name, src in sources.items():
        if src not in dirs:
            problems.append(
                f"marketplace.json publishes {name!r} from plugins/{src}/, which does not exist. "
                f"Users installing it get nothing."
            )

    # 3. a stale exclusion — permission for a directory that is gone
    for d in exclusions:
        if d not in dirs:
            problems.append(
                f"PENDING_DISPOSITION lists {d!r}, but plugins/{d}/ no longer exists — "
                f"remove the stale entry rather than leaving a decision recorded for nothing."
            )
        elif not str(exclusions[d]).strip():
            problems.append(f"PENDING_DISPOSITION[{d!r}] has no reason written — an exclusion without a reason is a silent carve-out.")

    summary = {
        "plugin_dirs": len(dirs),
        "manifest_entries": len(names),
        "pending_disposition": len([d for d in exclusions if d in dirs]),
    }
    return problems, summary


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=".", help="repo root to check (default: .)")
    args = ap.parse_args()

    problems, summary = audit(args.root)

    if summary:
        print(
            f"plugins/ directories: {summary['plugin_dirs']} · "
            f"manifest entries: {summary['manifest_entries']} · "
            f"pending disposition: {summary['pending_disposition']}"
        )

    if problems:
        for p in problems:
            print(f"::error::{p}")
        print(f"\n✗ marketplace coverage: {len(problems)} problem(s)")
        return 1

    print("✓ marketplace coverage: plugins/ and the manifest agree, modulo the recorded exclusions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
