#!/usr/bin/env python3
"""
DOES .claude-plugin/marketplace.json ADVERTISE THE VERSIONS THE PLUGINS SHIP?

Trello okOoGKTA. Measured 2026-10-07 on main @229cae3: 17 of 33 marketplace
entries carried a `version` that differs from the plugin's own plugin.json
(cowork-mem listed 0.1.0 and shipped 0.2.2). release.yml bumps plugin.json on
every release and nothing ever touched the manifest, so each release widened
the gap. plugin.json wins at install time, which is why updates still worked;
the public listing and any tool that reads marketplace.json for update
detection saw wrong versions.

Modes (single source of truth: scripts/bump-version.sh calls --set, so there
is no second bumper):

    marketplace-versions.py [--root .]                 check: exit 1 on any drift
    marketplace-versions.py --sync-all [--root .]      one-time resync, plugin.json wins
    marketplace-versions.py --set NAME VERSION         write VERSION into NAME's entry

Entries are keyed by the directory their `source` points at, the same key
check-marketplace-coverage.py uses. The file is rewritten with indent=2,
ensure_ascii=False and a trailing newline, which round-trips the committed
manifest byte for byte.
"""

import argparse
import json
import os
import sys

# A check that visits nothing is indistinguishable from a check that finds
# nothing wrong. The manifest lists 33 plugins; far fewer means the walk broke.
MIN_ENTRIES = 20


def manifest_path(root):
    return os.path.join(root, ".claude-plugin", "marketplace.json")


def load_manifest(root):
    with open(manifest_path(root), encoding="utf-8") as fh:
        return json.load(fh)


def write_manifest(root, data):
    with open(manifest_path(root), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def plugin_version(root, source):
    path = os.path.join(root, source, ".claude-plugin", "plugin.json")
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)["version"]


def source_dir(entry):
    src = entry.get("source")
    return os.path.basename(src.rstrip("/")) if isinstance(src, str) else None


def audit(root, min_entries=MIN_ENTRIES):
    """Returns (problems, drifted). Each drifted item is (name, listed, shipped)."""
    try:
        data = load_manifest(root)
    except Exception as exc:  # missing or unparseable: a problem, never a traceback
        return ([f"cannot read {manifest_path(root)}: {exc}"], [])
    problems, drifted, checked = [], [], 0
    for entry in data.get("plugins", []):
        if not isinstance(entry, dict) or not entry.get("name"):
            continue
        name, src = entry["name"], entry.get("source")
        if not isinstance(src, str):
            continue  # object sources have no local plugin.json; the coverage check reports them
        try:
            shipped = plugin_version(root, src)
        except Exception as exc:
            problems.append(f"{name}: cannot read plugin.json at {src}: {exc}")
            continue
        checked += 1
        if entry.get("version") != shipped:
            drifted.append((name, entry.get("version"), shipped))
    if checked < min_entries:
        problems.append(
            f"only {checked} manifest entries could be compared (expected at least {min_entries}) "
            "- the walk is broken, not the tree"
        )
    return problems, drifted


def sync_all(root):
    data = load_manifest(root)
    changed = 0
    for entry in data.get("plugins", []):
        src = entry.get("source") if isinstance(entry, dict) else None
        if not isinstance(src, str):
            continue
        shipped = plugin_version(root, src)
        if entry.get("version") != shipped:
            entry["version"] = shipped
            changed += 1
    if changed:
        write_manifest(root, data)
    return changed


def set_version(root, plugin_dir, version):
    """Returns True when an entry was written, False when the plugin is not published."""
    data = load_manifest(root)
    hit = False
    for entry in data.get("plugins", []):
        if isinstance(entry, dict) and source_dir(entry) == plugin_dir:
            entry["version"] = version
            hit = True
    if hit:
        write_manifest(root, data)
    return hit


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=".")
    ap.add_argument("--sync-all", action="store_true")
    ap.add_argument("--set", nargs=2, metavar=("PLUGIN_DIR", "VERSION"))
    ap.add_argument("--min-entries", type=int, default=MIN_ENTRIES)
    args = ap.parse_args(argv)

    if args.set:
        plugin_dir, version = args.set
        if set_version(args.root, plugin_dir, version):
            print(f"✓ marketplace.json: {plugin_dir} → {version}")
        else:
            print(f"::notice::{plugin_dir} has no marketplace.json entry; nothing to sync")
        return 0
    if args.sync_all:
        print(f"✓ resynced {sync_all(args.root)} marketplace entries to their plugin.json versions")
        return 0

    problems, drifted = audit(args.root, args.min_entries)
    for name, listed, shipped in drifted:
        print(f"::error file=.claude-plugin/marketplace.json::{name} lists {listed!r} but plugin.json ships {shipped!r}")
    for p in problems:
        print(f"::error file=.claude-plugin/marketplace.json::{p}")
    if problems or drifted:
        print("Fix: python3 scripts/marketplace-versions.py --sync-all")
        return 1
    print("✓ every marketplace.json version equals its plugin.json version")
    return 0


if __name__ == "__main__":
    sys.exit(main())
