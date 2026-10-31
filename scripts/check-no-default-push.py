#!/usr/bin/env python3
"""
Trello TJ93ychx - no shipped plugin may instruct an autonomous push by default.

Two plugins shipped instructions that pushed transcript-derived content to the
public repo on every run ("Git Push Rule - ALWAYS Push Changes",
"Self-Reflection Step"). That contradicts a "no telemetry" statement and trips
the directory review. This lint fails a plugin whose shipped .md / .sh files
tell the agent to push, unless the push sits inside a fenced block that names a
default-off userConfig option.

What counts as an instruction to push (per line; B and C ignore case):
  A. lowercase `git push` in COMMAND position: at the start of a line (after an optional
     `$`, list marker or backtick) or after && || ; |, optionally with -C/-c
     options. Prose that merely names the verb ("git push succeeds from the VM",
     "`git add`, `git commit`, `git push`") is not command position.
  B. `push origin` anywhere on the line.
  C. `update https://github.com/` anywhere on the line (the scheduled-task
     prompt form: "2. update https://github.com/<org>/<repo>/...").

Opt-out: a hit INSIDE a fenced code block is accepted when that same block names
`userConfig` and states a default-off value (`default: false`, `default off`,
`default-off`, `defaults to false|off`). A hit outside any fence is never accepted.

Allow-list (ALLOWLIST below): each entry carries a reason and is either a dated
TODO tied to open PRs, or a permanent entry for text that is not an instruction.
An allow-list entry that no longer matches anything prints a ::warning (not a
failure) so removing it is prompted without ordering the PRs' merges.

Run:  python3 scripts/check-no-default-push.py [--root .] [--no-allowlist]
Exit 0 = clean, 1 = an offending instruction was found, 2 = usage error.
"""

import argparse
import os
import re
import sys

SCAN_SUFFIXES = (".md", ".sh")
SKIP_DIRS = {"node_modules", ".git"}

# Each entry: plugin (required), path (relative to the plugin; omitted = whole
# plugin), contains (substring of the hit line; omitted = any hit), kind, reason.
ALLOWLIST = [
    {
        "plugin": "token-efficiency-audit",
        "kind": "TODO",
        "date": "2026-10-31",
        "reason": (
            "CLAUDE.md 'Git Push Rule - ALWAYS Push Changes' is removed by "
            "MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged "
            "on 2026-10-31. Delete this entry when #76 merges."
        ),
    },
    {
        "plugin": "fix-chrome-connection",
        "kind": "TODO",
        "date": "2026-10-31",
        "reason": (
            "Self-Reflection Step push and the 'update https://github.com/...' "
            "scheduled prompts are removed by MSApps-Mobile/claude-plugins#77 "
            "(card vRdQIur9), open and unmerged on 2026-10-31. Delete this entry "
            "when #77 merges."
        ),
    },
    {
        "plugin": "notion-memory",
        "path": "skills/notion-knowledge-capture/examples/how-to-guide.md",
        "contains": "git push origin v1.2.3",
        "kind": "permanent",
        "reason": (
            "Sample document text shown to the user as an example how-to guide "
            "(a release tag push), not an instruction the plugin gives the agent."
        ),
    },
]

SEGMENT_SPLIT = re.compile(r"&&|\|\||;|\|")
LEAD = re.compile(r"^[\s>]*(?:[-*+]\s+|\d+[.)]\s+)?(?:\$\s*)?`*\s*")
GIT_PUSH_CMD = re.compile(r"^git\s+(?:-[Cc]\s+\S+\s+)*push\b")  # case-sensitive: "Git push requires..." is prose
PUSH_ORIGIN = re.compile(r"\bpush\s+origin\b", re.I)
UPDATE_GH_URL = re.compile(r"\bupdate\s+https://github\.com/", re.I)
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
OPTIN_NAMES = re.compile(r"userConfig", re.I)
OPTIN_DEFAULT_OFF = re.compile(
    r"default\s*[:=]?\s*(?:false|off)\b|default-off|defaults?\s+to\s+(?:false|off)\b", re.I
)


def line_hit(line):
    """Return the rule letter ('A','B','C') this line trips, or None."""
    if UPDATE_GH_URL.search(line):
        return "C"
    if PUSH_ORIGIN.search(line):
        return "B"
    for seg in SEGMENT_SPLIT.split(line):
        if GIT_PUSH_CMD.match(LEAD.sub("", seg, count=1)):
            return "A"
    return None


def blocks(text):
    """Yield (line_no, line, fence_text_or_None) for each line; fence_text is the
    whole fenced block the line sits in (None when outside any fence)."""
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        if not m:
            out.append((i + 1, lines[i], None))
            i += 1
            continue
        marker = m.group(1)
        j = i + 1
        while j < len(lines):
            c = FENCE.match(lines[j])
            if c and c.group(1)[0] == marker[0] and len(c.group(1)) >= len(marker) \
                    and lines[j].strip() == c.group(1):
                break
            j += 1
        body = "\n".join(lines[i + 1:j])
        for k in range(i + 1, min(j, len(lines))):
            out.append((k + 1, lines[k], body))
        i = j + 1
    return out


def optin_ok(fence_text):
    return fence_text is not None and bool(OPTIN_NAMES.search(fence_text)) \
        and bool(OPTIN_DEFAULT_OFF.search(fence_text))


def scan_file(path):
    """Return [(line_no, rule, line)] for every un-opted-in hit in one file."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    hits = []
    for no, line, fence in blocks(text):
        rule = line_hit(line)
        if rule and not optin_ok(fence):
            hits.append((no, rule, line.strip()))
    return hits


def plugin_files(root):
    base = os.path.join(root, "plugins")
    if not os.path.isdir(base):
        return
    for plugin in sorted(os.listdir(base)):
        pdir = os.path.join(base, plugin)
        if not os.path.isdir(pdir):
            continue
        for dirpath, dirnames, filenames in os.walk(pdir):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
            for name in sorted(filenames):
                if name.endswith(SCAN_SUFFIXES):
                    full = os.path.join(dirpath, name)
                    yield plugin, os.path.relpath(full, pdir).replace(os.sep, "/"), full


def allowed(entry, plugin, rel, line):
    return (
        entry["plugin"] == plugin
        and entry.get("path", rel) == rel
        and entry.get("contains", line) in line
    )


def audit(root, allowlist=None):
    """Return (problems, suppressed, stale). problems: strings that fail the run;
    suppressed: (entry, rel_file, line_no) hits an allow-list entry covered;
    stale: allow-list entries that matched nothing."""
    allowlist = ALLOWLIST if allowlist is None else allowlist
    used = set()
    problems, suppressed = [], []
    for plugin, rel, full in plugin_files(root):
        for no, rule, line in scan_file(full):
            entry = next((e for e in allowlist if allowed(e, plugin, rel, line)), None)
            if entry is not None:
                used.add(id(entry))
                suppressed.append((entry, f"plugins/{plugin}/{rel}", no))
                continue
            problems.append(
                f"plugins/{plugin}/{rel}:{no}: rule {rule}: shipped instruction pushes by "
                f"default: {line[:120]!r}. Make it opt-in (a userConfig option, default off, "
                "named in the same fenced block) or remove it."
            )
    stale = [e for e in allowlist if id(e) not in used]
    return problems, suppressed, stale


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--no-allowlist", action="store_true",
                    help="ignore ALLOWLIST (used by the negative-control tests)")
    args = ap.parse_args(argv)
    if not os.path.isdir(os.path.join(args.root, "plugins")):
        print(f"::error::no plugins/ directory under {args.root!r}", file=sys.stderr)
        return 2

    problems, suppressed, stale = audit(args.root, [] if args.no_allowlist else None)

    seen = set()
    for entry, rel, no in suppressed:
        if id(entry) in seen:
            continue
        seen.add(id(entry))
        n = sum(1 for e, *_ in suppressed if e is entry)
        print(f"::notice::allow-listed ({entry['kind']} {entry.get('date', '')}) "
              f"{entry['plugin']}: {n} hit(s) - {entry['reason']}")
    for entry in stale:
        print(f"::warning::allow-list entry for {entry['plugin']} matched nothing - "
              "delete it from scripts/check-no-default-push.py")
    for p in problems:
        print(f"::error::{p}")
    if problems:
        print(f"{len(problems)} default-push instruction(s) found")
        return 1
    print("OK: no shipped plugin instructs a push by default")
    return 0


if __name__ == "__main__":
    sys.exit(main())
