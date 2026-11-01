#!/usr/bin/env python3
"""
Card NDw31FqM - every plugin must be discoverable after install.

A plugin whose skills are not reachable as a slash command shows nothing when
the user types "/". This check fails when a plugin directory has:
  - no commands/*.md,
  - a command with no `description` or no `argument-hint` in its frontmatter,
  - a README without a `## Usage` section that lists every command in the
    documented form:   /<plugin-name>:<command> <argument-hint>
                       # Examples:
                       /<plugin-name>:<command> ...

Run:  python3 scripts/check-plugin-commands.py --root .
Exit 0 = every plugin passes; 1 = problems (printed one per line).
"""
import argparse
import json
import os
import re
import sys


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    out = {}
    if not m:
        return out
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep and re.match(r"^[A-Za-z][\w-]*$", k.strip()):
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def usage_section(readme):
    m = re.search(r"^## Usage[^\n]*\n(.*?)(?=^## |\Z)", readme, re.S | re.M)
    return m.group(1) if m else None


def audit_plugin(plugin_dir):
    problems = []
    pdir = os.path.basename(plugin_dir.rstrip("/"))
    try:
        name = json.load(open(os.path.join(plugin_dir, ".claude-plugin", "plugin.json")))["name"]
    except Exception:
        name = pdir
    cdir = os.path.join(plugin_dir, "commands")
    cmds = sorted(f[:-3] for f in os.listdir(cdir) if f.endswith(".md")) if os.path.isdir(cdir) else []
    if not cmds:
        problems.append(f"{pdir}: no commands/*.md - add at least one slash command")
    for c in cmds:
        fm = frontmatter(open(os.path.join(cdir, c + ".md")).read())
        if not fm.get("description"):
            problems.append(f"{pdir}: commands/{c}.md has no frontmatter `description`")
        if not fm.get("argument-hint"):
            problems.append(f"{pdir}: commands/{c}.md has no frontmatter `argument-hint`")
    rpath = os.path.join(plugin_dir, "README.md")
    if not os.path.isfile(rpath):
        problems.append(f"{pdir}: no README.md (needs a `## Usage` block)")
        return problems
    sec = usage_section(open(rpath).read())
    if sec is None:
        problems.append(f"{pdir}: README.md has no `## Usage` section")
        return problems
    if "# Examples:" not in sec:
        problems.append(f"{pdir}: README `## Usage` has no `# Examples:` line")
    for c in cmds:
        if not re.search(r"^/" + re.escape(name) + ":" + re.escape(c) + r"(\s|$)", sec, re.M):
            problems.append(f"{pdir}: README `## Usage` does not show /{name}:{c}")
    return problems


def audit(root):
    pdir = os.path.join(root, "plugins")
    problems, n = [], 0
    for d in sorted(os.listdir(pdir)):
        full = os.path.join(pdir, d)
        if os.path.isdir(full):
            n += 1
            problems += audit_plugin(full)
    return problems, n


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    a = ap.parse_args()
    probs, n = audit(a.root)
    for p in probs:
        print(f"::error::{p}")
    print(f"checked {n} plugins, {len(probs)} problem(s)")
    sys.exit(1 if probs else 0)
