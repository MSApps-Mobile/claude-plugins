#!/usr/bin/env python3
"""
audit.py — quantitative audit of a CLAUDE.md file.

Usage:
    python3 audit.py <path-to-CLAUDE.md>
    python3 audit.py <path> --json        # machine-readable output
    python3 audit.py <path> --strict      # exit 1 if any anti-pattern found

Reports: line count, rough token estimate (~4 chars/token), detected
anti-patterns with line numbers, per-section sizes. Never modifies the file.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

TARGET_LINES = 200
TARGET_TOKENS = 1600
CHARS_PER_TOKEN = 4  # rough heuristic for English prose + code

# Regex patterns for anti-patterns. Each tuple is (pattern, label, explanation).
ANTI_PATTERNS = [
    (
        re.compile(r"^\s*(don't|do not|never|avoid)\b", re.IGNORECASE),
        "negative-rule",
        "Negative rule — flip to a positive directive where possible.",
    ),
    (
        re.compile(r"^(read|load|always load|before responding,?\s+review)\s+[`'\"/\w./-]+", re.IGNORECASE),
        "preemptive-preload",
        "Preemptive file preload — delete; Claude reads on demand.",
    ),
    (
        re.compile(r"as of \d{4}|\b20\d{2}-\d{2}-\d{2}\b|current sprint|current status", re.IGNORECASE),
        "dated-state",
        "Dated / ephemeral state — move to CLAUDE.local.md or rewrite non-dated.",
    ),
    (
        re.compile(r"^\s*(i like|i prefer|address me as|call me|please use my)\b", re.IGNORECASE),
        "personal-preference",
        "Personal preference — move to ~/.claude/CLAUDE.md (user-level).",
    ),
]

# Crude heuristic: a code block (between ``` fences) longer than this is
# probably reference material that should be extracted.
LONG_CODE_BLOCK_THRESHOLD = 20


@dataclass
class Finding:
    line: int
    label: str
    text: str
    note: str


@dataclass
class Section:
    heading: str
    start_line: int
    end_line: int
    line_count: int
    char_count: int


@dataclass
class Report:
    path: str
    total_lines: int
    non_empty_lines: int
    char_count: int
    token_estimate: int
    target_lines: int = TARGET_LINES
    target_tokens: int = TARGET_TOKENS
    over_line_target: bool = False
    over_token_target: bool = False
    sections: list[Section] = field(default_factory=list)
    findings: list[Finding] = field(default_factory=list)
    long_code_blocks: list[dict] = field(default_factory=list)


def parse_sections(lines: list[str]) -> list[Section]:
    """Split by top-level (## or #) headings."""
    sections: list[Section] = []
    current_heading = "(preamble)"
    current_start = 1
    current_lines: list[str] = []

    def flush(end_line: int) -> None:
        if not current_lines:
            return
        char_count = sum(len(l) for l in current_lines)
        sections.append(
            Section(
                heading=current_heading,
                start_line=current_start,
                end_line=end_line,
                line_count=len(current_lines),
                char_count=char_count,
            )
        )

    for i, line in enumerate(lines, start=1):
        if re.match(r"^#{1,3}\s+\S", line):
            flush(i - 1)
            current_heading = line.strip().lstrip("#").strip()
            current_start = i
            current_lines = [line]
        else:
            current_lines.append(line)
    flush(len(lines))
    return sections


def find_long_code_blocks(lines: list[str]) -> list[dict]:
    blocks = []
    in_block = False
    start = 0
    for i, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not in_block and stripped.startswith("```"):
            in_block = True
            start = i
            continue
        if in_block and stripped.startswith("```"):
            length = i - start - 1
            if length > LONG_CODE_BLOCK_THRESHOLD:
                blocks.append({"start_line": start, "end_line": i, "length": length})
            in_block = False
    return blocks


def scan_anti_patterns(lines: list[str]) -> list[Finding]:
    findings: list[Finding] = []
    for i, line in enumerate(lines, start=1):
        for pattern, label, note in ANTI_PATTERNS:
            if pattern.search(line):
                findings.append(
                    Finding(line=i, label=label, text=line.rstrip()[:120], note=note)
                )
                break  # one label per line
    return findings


def audit(path: Path) -> Report:
    raw = path.read_text(encoding="utf-8")
    lines = raw.splitlines()
    non_empty = sum(1 for l in lines if l.strip())
    char_count = len(raw)
    token_estimate = char_count // CHARS_PER_TOKEN

    report = Report(
        path=str(path),
        total_lines=len(lines),
        non_empty_lines=non_empty,
        char_count=char_count,
        token_estimate=token_estimate,
        over_line_target=len(lines) > TARGET_LINES,
        over_token_target=token_estimate > TARGET_TOKENS,
        sections=parse_sections(lines),
        findings=scan_anti_patterns(lines),
        long_code_blocks=find_long_code_blocks(lines),
    )
    return report


def format_text(r: Report) -> str:
    out = []
    out.append(f"CLAUDE.md audit — {r.path}")
    out.append("=" * 60)
    out.append(f"Total lines:      {r.total_lines:>5}   (target ≤{r.target_lines})")
    out.append(f"Non-empty lines:  {r.non_empty_lines:>5}")
    out.append(f"Characters:       {r.char_count:>5}")
    out.append(f"Token estimate:   {r.token_estimate:>5}   (target ≤{r.target_tokens}, ~{CHARS_PER_TOKEN} chars/token)")

    verdict_parts = []
    if r.over_line_target:
        verdict_parts.append(f"{r.total_lines - r.target_lines} lines over target")
    if r.over_token_target:
        verdict_parts.append(f"~{r.token_estimate - r.target_tokens} tokens over target")
    if verdict_parts:
        out.append("Verdict:          OVER — " + "; ".join(verdict_parts))
    else:
        out.append("Verdict:          within lean target")

    out.append("")
    out.append("Sections")
    out.append("-" * 60)
    for s in r.sections:
        out.append(f"  L{s.start_line:>3}-{s.end_line:<3} [{s.line_count:>3} lines, ~{s.char_count // CHARS_PER_TOKEN:>4} tok]  {s.heading}")

    if r.long_code_blocks:
        out.append("")
        out.append(f"Long code blocks (>{LONG_CODE_BLOCK_THRESHOLD} lines — candidates to extract)")
        out.append("-" * 60)
        for b in r.long_code_blocks:
            out.append(f"  L{b['start_line']:>3}-{b['end_line']:<3}  ({b['length']} lines)")

    if r.findings:
        out.append("")
        out.append("Anti-patterns detected")
        out.append("-" * 60)
        by_label: dict[str, list[Finding]] = {}
        for f in r.findings:
            by_label.setdefault(f.label, []).append(f)
        for label, items in by_label.items():
            out.append(f"  [{label}]  {items[0].note}")
            for f in items[:5]:
                out.append(f"    L{f.line:>3}: {f.text}")
            if len(items) > 5:
                out.append(f"    … and {len(items) - 5} more")
    else:
        out.append("")
        out.append("No anti-patterns matched by regex.")

    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Path to CLAUDE.md (or any .md file to audit)")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 1 if the file is over target or has anti-patterns.",
    )
    args = parser.parse_args()

    path = Path(args.path)
    if not path.exists():
        print(f"error: file not found: {path}", file=sys.stderr)
        return 2

    report = audit(path)

    if args.json:
        print(json.dumps(asdict(report), indent=2, default=str))
    else:
        print(format_text(report))

    if args.strict and (report.over_line_target or report.over_token_target or report.findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
