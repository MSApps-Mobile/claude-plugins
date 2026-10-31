#!/usr/bin/env python3
"""
Trello Jmv8kJnp - negative control for check-no-manual-bump.py.

Builds a throwaway git repo (base commit on main, PR commit on a branch) and
runs the real script against it. Cases that MUST red are listed first.

Run: python3 scripts/check-no-manual-bump.test.py
"""

import json
import os
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


def scenario(label, expect_rc, pr, main_moves=None, match=None):
    """Base: alpha 1.0.3, beta 0.1.0 in plugin.json and marketplace.json."""
    with tempfile.TemporaryDirectory(prefix="nmb-") as d:
        run("git", "init", "-q", "-b", "main", cwd=d)
        plugin(d, "alpha", "1.0.3")
        plugin(d, "beta", "0.1.0")
        manifest(d, {"alpha": "1.0.3", "beta": "0.1.0"})
        run("git", "add", "-A", cwd=d)
        run("git", "commit", "-q", "-m", "base", cwd=d)
        run("git", "checkout", "-q", "-b", "pr", cwd=d)
        pr(d)
        run("git", "add", "-A", cwd=d)
        run("git", "commit", "-q", "--allow-empty", "-m", "pr", cwd=d)
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
         lambda d: (plugin(d, "alpha", "1.0.4"), manifest(d, {"alpha": "1.0.4", "beta": "0.1.0"})), match="marketplace.json")
scenario("only marketplace.json bumped", 1,
         lambda d: manifest(d, {"alpha": "1.0.3", "beta": "0.2.0"}), match="beta")
scenario("version lowered", 1, lambda d: plugin(d, "alpha", "1.0.2"), match="1.0.3 -> 1.0.2")

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

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
