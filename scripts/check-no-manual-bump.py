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

Not a violation:
  - a brand-new plugin (no base version to differ from), or a deleted plugin or
    manifest entry;
  - a marketplace.json entry changed to EQUAL the head's plugin.json version
    (the `marketplace-versions.py --sync-all` drift repair);
  - the auditable MINOR/MAJOR override: a commit in the PR carries the trailer
    `Release-Bump: <plugin> <new version>` AND the plugin.json change is a
    minor or major step (x.y'.0 with y' > y, or x'.0.0 with x' > x) to exactly that version. The
    trailer is in the git history, so every such release is reviewable. Note
    release.yml still patch-bumps on merge, so the release ships as x.(y+1).1.

Comparing against the merge base, not the tip of main, keeps the release bot's
own `chore(release)` commits on main from reading as a change the PR made.

    check-no-manual-bump.py [--root .] [--base origin/main] [--head HEAD]

Exit 0 = no unapproved version change, 1 = at least one, 2 = could not read git or a manifest.
"""

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys

PLUGIN_JSON = re.compile(r"^plugins/([^/]+)/\.claude-plugin/plugin\.json$")
MANIFEST = ".claude-plugin/marketplace.json"
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
TRAILER = re.compile(r"^Release-Bump:\s*(\S+)\s+(\S+)\s*$", re.M)

# One mapping from a manifest entry to its plugin directory: marketplace-versions.py.
_spec = importlib.util.spec_from_file_location(
    "marketplace_versions", os.path.join(os.path.dirname(os.path.abspath(__file__)), "marketplace-versions.py"))
_mv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mv)
source_dir = _mv.source_dir


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
        name = source_dir(entry) if isinstance(entry, dict) else None
        if name:
            out[name] = entry.get("version")
    return out


def changed(base, head):
    """[(name, base version, head version)] for names present on both sides."""
    return sorted((n, base[n], head[n]) for n in base.keys() & head.keys() if base[n] != head[n])


def is_minor_or_major_step(old, new):
    o, n = SEMVER.match(str(old)), SEMVER.match(str(new))
    if not (o and n):
        return False
    om, on, _ = map(int, o.groups())
    nm, nn, np_ = map(int, n.groups())
    return np_ == 0 and ((nm == om and nn > on) or (nm > om and nn == 0))


def overrides(root, merge_base, head_rev):
    """{(plugin, version)} named by Release-Bump trailers in merge_base..head."""
    msgs = git(root, "log", "--format=%B", f"{merge_base}..{head_rev}")
    return set(TRAILER.findall(msgs))


def audit(root, base_rev, head_rev):
    merge_base = git(root, "merge-base", base_rev, head_rev).strip()
    approved = overrides(root, merge_base, head_rev)
    hits = []
    head_plugins = plugin_versions(root, head_rev)
    for name, old, new in changed(plugin_versions(root, merge_base), head_plugins):
        if (name, new) in approved and is_minor_or_major_step(old, new):
            continue
        hits.append(("plugin.json", name, old, new))
    for name, old, new in changed(manifest_versions(root, merge_base), manifest_versions(root, head_rev)):
        if new == head_plugins.get(name):
            continue  # entry now equals the head's plugin.json: a re-sync (or the approved bump), not a bump
        hits.append(("marketplace.json", name, old, new))
    return merge_base, hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--head", default="HEAD")
    a = ap.parse_args()
    try:
        merge_base, hits = audit(a.root, a.base, a.head)
    except (RuntimeError, ValueError, AttributeError, TypeError) as e:
        print(f"::error::{e}")
        return 2
    if not hits:
        print(f"OK: no plugin version differs from the merge base {merge_base[:8]}")
        return 0
    for label, name, old, new in hits:
        print(f"::error::{name}: {label} version {old} -> {new}. PRs never change a version; "
              "release.yml bumps it on merge. Revert the version change; for a MINOR/MAJOR release "
              "add a 'Release-Bump: <plugin> <version>' trailer to a commit (see CONTRIBUTING.md).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
