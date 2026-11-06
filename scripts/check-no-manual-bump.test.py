#!/usr/bin/env python3
"""
Trello Jmv8kJnp - negative control for check-no-manual-bump.py.

Builds a throwaway git repo (base commit on main, PR commit on a branch) and
runs the real script against it. Cases that MUST red are listed first.

Run: python3 scripts/check-no-manual-bump.test.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "check-no-manual-bump.py")
failures = []


def run(*cmd, cwd):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
    r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    if r.returncode != 0 and cmd[0] == "git":
        raise RuntimeError(r.stderr)
    return r


def write(root, rel, data):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def plugin(root, name, version):
    write(root, f"plugins/{name}/.claude-plugin/plugin.json", {"name": name, "version": version})


def manifest(root, versions):
    write(root, ".claude-plugin/marketplace.json",
          {"plugins": [{"name": n, "source": f"./plugins/{n}", "version": v} for n, v in versions.items()]})


def scenario(label, expect_rc, pr, main_moves=None, match=None, msg="pr", base=None):
    """Base: alpha 1.0.3, beta 0.1.0 in plugin.json and marketplace.json."""
    with tempfile.TemporaryDirectory(prefix="nmb-") as d:
        run("git", "init", "-q", "-b", "main", cwd=d)
        plugin(d, "alpha", "1.0.3")
        plugin(d, "beta", "0.1.0")
        manifest(d, {"alpha": "1.0.3", "beta": "0.1.0"})
        if base:
            base(d)
        run("git", "add", "-A", cwd=d)
        run("git", "commit", "-q", "-m", "base", cwd=d)
        run("git", "checkout", "-q", "-b", "pr", cwd=d)
        pr(d)
        run("git", "add", "-A", cwd=d)
        run("git", "commit", "-q", "--allow-empty", "-m", msg, cwd=d)
        if main_moves:
            run("git", "checkout", "-q", "main", cwd=d)
            main_moves(d)
            run("git", "add", "-A", cwd=d)
            run("git", "commit", "-q", "-m", "release bot", cwd=d)
            run("git", "checkout", "-q", "pr", cwd=d)
        r = run("python3", SCRIPT, "--root", d, "--base", "main", "--head", "pr", cwd=d)
        out = r.stdout + r.stderr
        if r.returncode != expect_rc:
            failures.append(f"{label}: expected rc={expect_rc}, got {r.returncode}: {out.strip()}")
        elif match and match not in out:
            failures.append(f"{label}: output did not mention {match!r}: {out.strip()}")
        else:
            print(f"  ok  {label}")


print("negative controls - these MUST red:")
scenario("plugin.json 1.0.3 -> 1.0.4 (the #76 shape)", 1,
         lambda d: (plugin(d, "alpha", "1.0.4"), manifest(d, {"alpha": "1.0.3", "beta": "0.1.0"})), match="1.0.3 -> 1.0.4")
scenario("plugin.json and marketplace.json both bumped", 1,
         lambda d: (plugin(d, "alpha", "1.0.4"), manifest(d, {"alpha": "1.0.4", "beta": "0.1.0"})), match="alpha")
scenario("only marketplace.json bumped", 1,
         lambda d: manifest(d, {"alpha": "1.0.3", "beta": "0.2.0"}), match="beta")
scenario("version lowered", 1, lambda d: plugin(d, "alpha", "1.0.2"), match="1.0.3 -> 1.0.2")

BUMP_MINOR = lambda d: (plugin(d, "alpha", "1.1.0"), manifest(d, {"alpha": "1.1.0", "beta": "0.1.0"}))
scenario("minor bump with NO Release-Bump trailer", 1, BUMP_MINOR, match="Release-Bump")
scenario("trailer names another plugin", 1, BUMP_MINOR, msg="x\n\nRelease-Bump: beta 1.1.0")
scenario("trailer names another version", 1, BUMP_MINOR, msg="x\n\nRelease-Bump: alpha 1.2.0")
scenario("trailer on a PATCH bump (the release workflow owns patches)", 1,
         lambda d: (plugin(d, "alpha", "1.0.4"), manifest(d, {"alpha": "1.0.4", "beta": "0.1.0"})),
         msg="x\n\nRelease-Bump: alpha 1.0.4")
scenario("trailer on a downgrade", 1, lambda d: (plugin(d, "alpha", "0.9.0"), manifest(d, {"alpha": "0.9.0", "beta": "0.1.0"})),
         msg="x\n\nRelease-Bump: alpha 0.9.0")
scenario("manifest changed to something other than plugin.json", 1,
         lambda d: manifest(d, {"alpha": "1.0.9", "beta": "0.1.0"}), match="alpha")

print("known-positives - these MUST be green:")
scenario("PR touches no version", 0, lambda d: write(d, "plugins/alpha/notes.json", {"a": 1}))
scenario("PR edits plugin.json but not its version", 0,
         lambda d: write(d, "plugins/alpha/.claude-plugin/plugin.json", {"name": "alpha", "version": "1.0.3", "description": "new"}))
scenario("brand-new plugin at 0.1.0 is not a bump", 0,
         lambda d: (plugin(d, "gamma", "0.1.0"), manifest(d, {"alpha": "1.0.3", "beta": "0.1.0", "gamma": "0.1.0"})))
scenario("deleted plugin is not a bump", 0,
         lambda d: (os.remove(os.path.join(d, "plugins/beta/.claude-plugin/plugin.json")), manifest(d, {"alpha": "1.0.3"})))
scenario("release bot bumped main after the PR branched", 0,
         lambda d: write(d, "plugins/alpha/notes.json", {"a": 1}),
         main_moves=lambda d: (plugin(d, "alpha", "1.0.4"), manifest(d, {"alpha": "1.0.4", "beta": "0.1.0"})))

scenario("minor bump WITH a Release-Bump trailer (documented override)", 0, BUMP_MINOR,
         msg="release: alpha 1.1.0\n\nRelease-Bump: alpha 1.1.0")
scenario("major bump WITH a Release-Bump trailer", 0,
         lambda d: (plugin(d, "alpha", "2.0.0"), manifest(d, {"alpha": "2.0.0", "beta": "0.1.0"})),
         msg="release: alpha 2.0.0\n\nRelease-Bump: alpha 2.0.0")
# The --sync-all drift repair: main's manifest drifted (0.0.1), plugin.json is 1.0.3 and unchanged.
scenario("manifest re-synced to the unchanged plugin.json version (drift repair)", 0,
         lambda d: manifest(d, {"alpha": "1.0.3", "beta": "0.1.0"}),
         base=lambda d: manifest(d, {"alpha": "0.0.1", "beta": "0.1.0"}))

# ---- the card's AC: unchanged 1.0.3 -> release patch bump -> 1.0.4 in both files, marketplace-versions passes
print("release path (bump-version.sh on an unchanged 1.0.3):")
with tempfile.TemporaryDirectory(prefix="nmb-bump-") as d:
    os.makedirs(os.path.join(d, "scripts"))
    for f in ("bump-version.sh", "marketplace-versions.py"):
        shutil.copy(os.path.join(HERE, f), os.path.join(d, "scripts", f))
    run("git", "init", "-q", "-b", "main", cwd=d)
    plugin(d, "alpha", "1.0.3")
    manifest(d, {"alpha": "1.0.3"})
    r = run("bash", "scripts/bump-version.sh", "alpha", "patch", cwd=d)
    pj = json.load(open(os.path.join(d, "plugins/alpha/.claude-plugin/plugin.json")))["version"]
    mj = json.load(open(os.path.join(d, ".claude-plugin/marketplace.json")))["plugins"][0]["version"]
    chk = run("python3", "scripts/marketplace-versions.py", "--root", d, "--min-entries", "1", cwd=d)
    if r.returncode == 0 and pj == mj == "1.0.4" and chk.returncode == 0:
        print("  ok  bump-version.sh alpha patch: 1.0.3 -> 1.0.4 in plugin.json and marketplace.json; marketplace-versions passes")
    else:
        failures.append(f"bump-version: rc={r.returncode} plugin.json={pj} marketplace={mj} check rc={chk.returncode} "
                        f"{r.stderr.strip()} {chk.stdout.strip()} {chk.stderr.strip()}")

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
