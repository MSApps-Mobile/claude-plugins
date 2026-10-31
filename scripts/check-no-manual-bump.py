#!/usr/bin/env python3
"""
DOES THIS PR LEAVE EVERY PLUGIN VERSION EXACTLY AS THE BASE HAS IT?

Trello Jmv8kJnp. release.yml patch-bumps a plugin on every merge to main
(bump-version.sh reads the CURRENT version from plugin.json). A PR that also
bumped the version by hand therefore stacked a second bump on top: PR #76
advertised 1.0.4 and would have shipped 1.0.5; #77 (0.1.32) would ship 0.1.33.

The rule (CONTRIBUTING.md, "Versions are bumped by the release workflow"):
PRs never change a version, the release workflow owns it. This check fails a
PR whose `version` in any plugins/*/.claude-plugin/plugin.json, or in any
.claude-plugin/marketplace.json entry, differs from the PR's merge base with
main.

Not a violation: a brand-new plugin (no base version to differ from) and a
deleted plugin or manifest entry. Comparing against the merge base, not the tip
of main, keeps the release bot's own `chore(release)` commits on main from
reading as a change the PR made.

    check-no-manual-bump.py [--root .] [--base origin/main] [--head HEAD]

Exit 0 = no version changed, 1 = at least one did, 2 = could not read git.
"""

import argparse
import json
import re
import subprocess
import sys

PLUGIN_JSON = re.compile(r"^plugins/([^/]+)/\.claude-plugin/plugin\.json$")
MANIFEST = ".claude-plugin/marketplace.json"


def git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def show(root, rev, path):
    """File content at rev, or None when the path does not exist there."""
    r = subprocess.run(["git", "-C", root, "show", f"{rev}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def plugin_versions(root, rev):
    """{plugin dir: version} from every plugin.json at rev."""
    out = {}
    for path in git(root, "ls-tree", "-r", "--name-only", rev, "--", "plugins").splitlines():
        m = PLUGIN_JSON.match(path)
        if not m:
            continue
        try:
            out[m.group(1)] = json.loads(show(root, rev, path)).get("version")
        except (ValueError, TypeError):
            out[m.group(1)] = "<unreadable plugin.json>"
    return out


def manifest_versions(root, rev):
    """{source dir: version} from marketplace.json at rev."""
    text = show(root, rev, MANIFEST)
    if text is None:
        return {}
    out = {}
    for entry in json.loads(text).get("plugins", []):
        src = entry.get("source")
        if isinstance(src, str):
            out[src.rstrip("/").split("/")[-1]] = entry.get("version")
    return out


def changed(base, head):
    """[(name, base version, head version)] for names present on both sides."""
    return sorted((n, base[n], head[n]) for n in base.keys() & head.keys() if base[n] != head[n])


def audit(root, base_rev, head_rev):
    merge_base = git(root, "merge-base", base_rev, head_rev).strip()
    hits = []
    for label, loader in (("plugin.json", plugin_versions), ("marketplace.json", manifest_versions)):
        for name, old, new in changed(loader(root, merge_base), loader(root, head_rev)):
            hits.append((label, name, old, new))
    return merge_base, hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--head", default="HEAD")
    a = ap.parse_args()
    try:
        merge_base, hits = audit(a.root, a.base, a.head)
    except RuntimeError as e:
        print(f"::error::{e}")
        return 2
    if not hits:
        print(f"OK: no plugin version differs from the merge base {merge_base[:8]}")
        return 0
    for label, name, old, new in hits:
        print(f"::error::{name}: {label} version {old} -> {new}. PRs never change a version; "
              "release.yml bumps it on merge. Revert the version change (see CONTRIBUTING.md).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
