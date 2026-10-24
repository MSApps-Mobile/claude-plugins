#!/usr/bin/env python3
"""
Trello IcsmluvI - no ${{ }} expression inside a run: body.

GitHub substitutes ${{ ... }} into a run: script as plain text BEFORE the shell
(or a Python heredoc) parses it. validate-pr.yml did that with the matrix
entry, which is a plugin directory name taken from the PR's own changed files,
so a directory named with "$(...)" or a quote ran commands on the runner.
Values must reach a script through env: and be read as "$VAR" (shell) or
os.environ["VAR"] (Python).

This check reads the workflow text (no PyYAML needed on the runner), finds
every run: value - inline or block scalar - and fails on ANY ${{ inside it.
${{ }} stays allowed in name:, env:, with:, if:, strategy: and outputs:.

Run:  python3 scripts/check-workflow-run-expressions.py [--root .] [workflow ...]
Default workflow list: validate-pr.yml, release.yml and sosa-lint.yml under
.github/workflows/ (release.yml and sosa-lint.yml added by card SNQ5Siev).
Exit 0 = clean, 1 = an expression was found in a run: body, 2 = usage error.
"""

import argparse
import os
import re
import sys

DEFAULT_WORKFLOWS = [
    ".github/workflows/validate-pr.yml",
    # Card SNQ5Siev: release.yml is the job that publishes; sosa-lint.yml runs
    # on every PR. Both stay clean only if the default run checks them.
    ".github/workflows/release.yml",
    ".github/workflows/sosa-lint.yml",
]

RUN_KEY = re.compile(r"^(?P<indent>\s*)(?P<dash>-\s+)?run:\s*(?P<rest>.*)$")
EXPR = re.compile(r"\$\{\{")


def run_bodies(text):
    """Yield (line_number, line_text) for every line that is part of a run: value."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        m = RUN_KEY.match(lines[i])
        if not m:
            i += 1
            continue
        key_col = len(m.group("indent")) + len(m.group("dash") or "")
        rest = m.group("rest")
        if rest[:1] in ("|", ">"):
            j = i + 1
            while j < len(lines):
                line = lines[j]
                if line.strip() and (len(line) - len(line.lstrip(" "))) <= key_col:
                    break
                yield j + 1, line
                j += 1
            i = j
        else:
            yield i + 1, rest
            i += 1


def audit(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    problems = []
    for lineno, line in run_bodies(text):
        if EXPR.search(line):
            problems.append(f"{path}:{lineno}: ${{{{ }}}} expression inside a run: body: {line.strip()}")
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--root", default=".")
    ap.add_argument("workflows", nargs="*")
    args = ap.parse_args(argv)

    targets = args.workflows or DEFAULT_WORKFLOWS
    problems = []
    for rel in targets:
        path = rel if os.path.isabs(rel) else os.path.join(args.root, rel)
        if not os.path.isfile(path):
            print(f"::error::workflow not found: {path}")
            return 2
        problems.extend(audit(path))

    for p in problems:
        print(f"::error::{p}")
    if problems:
        print("Route the value through env: and read it as \"$VAR\" / os.environ[\"VAR\"] (card IcsmluvI).")
        return 1
    print(f"OK no expression inside a run: body in {len(targets)} workflow(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
