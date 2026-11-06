#!/usr/bin/env python3
"""
Trello TJ93ychx - no shipped plugin may instruct an autonomous push by default.

Two plugins shipped instructions that pushed transcript-derived content to the
public repo on every run ("Git Push Rule - ALWAYS Push Changes",
"Self-Reflection Step"). That contradicts a "no telemetry" statement and trips
the directory review. This lint fails a plugin whose shipped .md / .sh files
tell the agent to push, unless the push sits inside a fenced block that names a
default-off userConfig option.

What counts as an instruction to push (per line):
  A. `git push` in COMMAND position (case-sensitive): at the start of a line after
     an optional list marker, checkbox, "Step N:" / "Label:" prefix, `$`,
     backtick, `(`, `$(`, `then`, `command`, `VAR=x`; or after && || ; |, with
     optional -C/-c options. In a .sh file ANY non-comment `git ... push` counts
     (a script has no prose to protect). Prose that merely names the verb
     ("git push succeeds from the VM", "`git add`, `git commit`, `git push`")
     is not command position in a .md file.
  B. `push origin` anywhere on the line.
  C. `update ... https://github.com/` anywhere on the line (the scheduled-task
     prompt form: "2. update https://github.com/<org>/<repo>/...").
  D. .md only: "always push" / "must push", "commit and push", "push ... to
     github|main|master", and "run `git push`", and a `git push` next to
     after|every|always.

Not scanned: a plugin's tests/ directory and *.test.sh files. The repo's CI runs
plugins/<name>/tests/*.test.sh (card TNCrQi31); those push to throwaway bare
repos the test creates, so they are test code, not an instruction a plugin gives
the agent (fixture good-test-pushes-to-local-bare, from claude-plugins#80).

Opt-out: a hit INSIDE a fenced code block is accepted when that same block names
`userConfig` and states a default-off value (`default: false`, `default off`,
`default-off`, `defaults to false|off`). A hit outside any fence is never accepted.

Allow-list (ALLOWLIST below): every entry names plugin + path + the exact
(whitespace-stripped) line, a reason, and is either a dated TODO tied to open PRs
or a permanent entry for text that is not an instruction. An entry that matches
nothing FAILS the run, so it cannot outlive its reason: the PR that removes the
text deletes the entry in the same change.

Run:  python3 scripts/check-no-default-push.py [--root .] [--no-allowlist]
Exit 0 = clean, 1 = an offending instruction or a stale allow-list entry,
2 = usage error.
"""

import argparse
import datetime
import os
import re
import sys

SCAN_SUFFIXES = (".md", ".sh")
SKIP_DIRS = {"node_modules", ".git", "tests"}
SKIP_FILE_SUFFIXES = (".test.sh",)

# Each entry: plugin, path (relative to the plugin), line (the exact stripped
# line), kind ("TODO" + date + a PR reference, or "permanent"), reason.
ENTRY_KEYS = ("plugin", "path", "line", "kind", "reason")
ALLOWLIST = [
    {
        "plugin": 'fix-chrome-connection',
        "path": 'CLAUDE.md',
        "line": 'git pull --rebase origin main && git push origin main',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#77 (card vRdQIur9), open and unmerged on 2026-11-06. #77 deletes this entry in the same change.',
    },
    {
        "plugin": 'fix-chrome-connection',
        "path": 'scheduled/fix-chrome-connection/CLAUDE.md',
        "line": '2. update https://github.com/MSApps-Mobile/claude-plugins/tree/main/plugins/fix-chrome-connection',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#77 (card vRdQIur9), open and unmerged on 2026-11-06. #77 deletes this entry in the same change.',
    },
    {
        "plugin": 'fix-chrome-connection',
        "path": 'skills/chrome-health-check/CLAUDE.md',
        "line": '2. update https://github.com/MSApps-Mobile/claude-plugins/tree/main/plugins/fix-chrome-connection',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#77 (card vRdQIur9), open and unmerged on 2026-11-06. #77 deletes this entry in the same change.',
    },
    {
        "plugin": 'fix-chrome-connection',
        "path": 'skills/fix-chrome-connection/SKILL.md',
        "line": '2. Commit and push:',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#77 (card vRdQIur9), open and unmerged on 2026-11-06. #77 deletes this entry in the same change.',
    },
    {
        "plugin": 'fix-chrome-connection',
        "path": 'skills/fix-chrome-connection/SKILL.md',
        "line": 'git pull --rebase origin main && git push origin main',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#77 (card vRdQIur9), open and unmerged on 2026-11-06. #77 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": '7. If anything new was learned → updates this CLAUDE.md and pushes to GitHub',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": 'git push origin main',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": '## ⚠️ Git Push Rule — ALWAYS Push Changes',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": '**Whenever ANY file in this plugin is modified — CLAUDE.md, any SKILL.md, references, config, or CONNECTORS.md — push to GitHub.**',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": 'This is not limited to self-learning. If the task modifies ANY local plugin file for ANY reason, it MUST push:',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": 'token-efficiency-audit',
        "path": 'CLAUDE.md',
        "line": '- Push CLAUDE.md updates to GitHub',
        "kind": "TODO",
        "date": "2026-11-06",
        "reason": 'Removed by MSApps-Mobile/claude-plugins#76 (card ubBZgFTJ), open and unmerged on 2026-11-06. #76 deletes this entry in the same change.',
    },
    {
        "plugin": "notion-memory",
        "path": "skills/notion-knowledge-capture/examples/how-to-guide.md",
        "line": "git push origin v1.2.3",
        "kind": "permanent",
        "reason": (
            "Sample document text shown to the user as an example how-to guide "
            "(a release tag push), not an instruction the plugin gives the agent."
        ),
    },
]

SEGMENT_SPLIT = re.compile(r"&&|\|\||;|\|")
LEAD = re.compile(
    r"^[\s>]*(?:[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)?"       # list marker / checkbox
    r"(?:\*{0,2}[^:`]{1,60}:\*{0,2}\s*)?"                      # "Step 3:" / "Label:" prefix
    r"(?:\$\(|\$\s|\(|\{|then\s+|do\s+|else\s+)*\s*`*\s*"
    r"(?:(?:command|sudo|exec|env)\s+)*"
    r"(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"                      # VAR=x git push
)
GIT_PUSH_CMD = re.compile(r"^git\s+(?:-[Cc]\s+\S+\s+)*push\b")  # case-sensitive: "Git push requires..." is prose
SH_GIT_PUSH = re.compile(r"\bgit(?:\s+-[Cc]\s+\S+|\s+--\S+)*\s+push\b")
PUSH_ORIGIN = re.compile(r"\bpush\s+origin\b", re.I)
UPDATE_GH_URL = re.compile(r"\bupdate\b[^\n]{0,40}?https://github\.com/", re.I)
MD_PHRASES = (
    re.compile(r"\b(?:always|must)\s+push\b", re.I),
    re.compile(r"\bcommit\s+and\s+push\b", re.I),
    re.compile(r"\bpush(?:es)?\s+(?:\S+\s+){0,3}?to\s+(?:the\s+)?(?:github|main\b|master\b)", re.I),
    re.compile(r"\brun\s+`git\s+push\b|\b(?:after|every|always)\b[^`\n]*`git\s+push\b"
               r"|\bgit\s+push\b[^\n]*\b(?:after|every|always)\b", re.I),
)
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
OPTIN_NAMES = re.compile(r"userConfig", re.I)
OPTIN_DEFAULT_OFF = re.compile(
    r"default\s*[:=]?\s*(?:false|off)\b|default-off|defaults?\s+to\s+(?:false|off)\b", re.I
)


def line_hit(line, shell=False):
    """Return the rule letter ('A','B','C','D') this line trips, or None."""
    if UPDATE_GH_URL.search(line):
        return "C"
    if PUSH_ORIGIN.search(line):
        return "B"
    if shell:
        if not line.lstrip().startswith("#") and SH_GIT_PUSH.search(line):
            return "A"
        return None
    for seg in SEGMENT_SPLIT.split(line):
        if GIT_PUSH_CMD.match(LEAD.sub("", seg, count=1)):
            return "A"
    if any(p.search(line) for p in MD_PHRASES):
        return "D"
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
    shell = path.endswith(".sh")
    hits = []
    for no, line, fence in blocks(text):
        rule = line_hit(line, shell)
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
                if name.endswith(SCAN_SUFFIXES) and not name.endswith(SKIP_FILE_SUFFIXES):
                    full = os.path.join(dirpath, name)
                    yield plugin, os.path.relpath(full, pdir).replace(os.sep, "/"), full


def entry_errors(entry):
    """Why an allow-list entry is malformed (empty list = well formed)."""
    errs = [f"missing {k!r}" for k in ENTRY_KEYS if not entry.get(k)]
    if entry.get("kind") == "TODO":
        try:
            datetime.date.fromisoformat(str(entry.get("date", "")))
        except ValueError:
            errs.append("TODO entry needs an ISO 'date'")
        if "#" not in str(entry.get("reason", "")):
            errs.append("TODO entry's reason must name the PR it waits on")
    elif entry.get("kind") != "permanent":
        errs.append("kind must be 'TODO' or 'permanent'")
    return errs


def allowed(entry, plugin, rel, line):
    return (
        entry.get("plugin") == plugin
        and entry.get("path") == rel
        and entry.get("line") == line.strip()
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

    allowlist = [] if args.no_allowlist else ALLOWLIST
    problems, suppressed, stale = audit(args.root, allowlist)
    for entry in allowlist:
        for err in entry_errors(entry):
            problems.append(f"malformed allow-list entry for {entry.get('plugin')!r}: {err}")

    seen = set()
    for entry, rel, no in suppressed:
        if id(entry) in seen:
            continue
        seen.add(id(entry))
        print(f"::notice::allow-listed ({entry['kind']} {entry.get('date', '')}) "
              f"{rel}:{no} - {entry['reason']}")
    for entry in stale:
        problems.append(
            f"stale allow-list entry for plugins/{entry.get('plugin')}/{entry.get('path')} "
            f"({entry.get('line')!r}) matches nothing - delete it from "
            "scripts/check-no-default-push.py in the same change that removed the text"
        )
    for p in problems:
        print(f"::error::{p}")
    if problems:
        print(f"{len(problems)} default-push problem(s) found")
        return 1
    print("OK: no shipped plugin instructs a push by default")
    return 0


if __name__ == "__main__":
    sys.exit(main())
