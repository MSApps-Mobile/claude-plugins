#!/usr/bin/env python3
"""
cowork-mem PostToolUse auto-capture hook.

Reads tool context from stdin (JSON), decides whether the tool output
is worth saving, and writes a compact observation to memory.

Called by the PostToolUse hook in settings.json:
  python3 {SKILL_DIR}/scripts/post_tool_capture.py

Stdin format (Claude Code hook payload):
  {
    "tool_name": "Edit",
    "tool_input": { ... },
    "tool_response": { "content": "..." }
  }

Captured tools and what we save:
  Edit / Write   → file_edit: path + summary of change
  Bash           → tool_use: command + condensed output (if significant)
  Task (Agent)   → insight: final result summary
  TodoWrite      → note: what was added to the plan

Deliberately NOT captured:
  Read, Glob, Grep, WebFetch, WebSearch — passive lookups, not state changes
  screenshot, mouse, keyboard — transient UI actions

Secrets (card gFeFnGRA, CTO review 5554454332): every field that is stored is
passed through redact() over a bounded window BEFORE it is sliced or stored, so a bearer token, a
token=/key=/password= value, a user:pass@ URL or a known key shape (ghp_,
github_pat_, sk-, AIza, xox*) never reaches memory.db. Files are private: the
process runs under umask 077 (dir 0700, DB and log 0600).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MAX_CONTENT_LEN = 300   # chars per observation (keep lean)
MAX_OUTPUT_LEN  = 500   # chars of tool output to inspect

# Tools we want to capture (exact matches)
CAPTURE_TOOLS = {"Edit", "Write", "Bash", "Task", "TodoWrite", "NotebookEdit"}

# Bash commands that indicate meaningful work (not just navigation)
MEANINGFUL_BASH_PREFIXES = (
    "python", "node", "npm", "npx", "pip", "git",
    "curl", "wget", "docker", "gcloud", "gh ",
    "mkdir", "cp ", "mv ", "rm ", "chmod",
    "pytest", "jest", "cargo", "go ", "make",
)

# Bash commands that are too trivial to save
TRIVIAL_BASH_PREFIXES = (
    "ls ", "cat ", "head ", "tail ", "echo ",
    "cd ", "pwd", "env ", "export ", "which ",
    "find . -type f", "wc ", "grep ",
)


# capture-errors.log is rotated to capture-errors.log.1 past this size
MAX_ERROR_LOG_BYTES = 256 * 1024

# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------

REDACTED = "[REDACTED]"

# Order matters: whole-value shapes first, then the name=value forms.
_REDACTIONS = (
    # PEM private keys (OpenSSH, EC, RSA, PKCS#8; also inside a service-account JSON): BEGIN through
    # END, or through the end of the window when END was cut off. First, so nothing below sees a body.
    (re.compile(r"-----BEGIN[A-Z0-9 ]{0,64}PRIVATE KEY(?: BLOCK)?-----[\s\S]*?"
                r"(?:-----END[A-Z0-9 ]{0,64}PRIVATE KEY(?: BLOCK)?-----|\Z)"), REDACTED),
    # PuTTY .ppk: the private lines through the MAC (or the end of the window)
    (re.compile(r"Private-Lines:[ \t]{0,64}\d{1,4}[\s\S]*?(?:Private-MAC:[ \t]{0,64}\S{1,256}|\Z)"), REDACTED),
    # credentials in a URL: scheme://user:pass@host (a password may itself contain '@')
    (re.compile(r"(?i)\b([a-z][a-z0-9+.-]*://)[^\s/@:]+:[^\s/]*@"), r"\1" + REDACTED + "@"),
    # curl -u / -U user:pass, bundled (-su), --user / --proxy-user with a space or '='; a quoted
    # value is masked through its closing quote, so a password with spaces does not leak a tail
    (re.compile(r"((?:^|\s)(?:-[A-Za-z]{0,8}[uU]\s{0,64}|--(?:proxy-)?user(?:\s{1,64}|=)))(?!\[REDACTED\])"
                r"(?:\"[^\"\n:]{0,128}:[^\"\n]{0,256}\"|'[^'\n:]{0,128}:[^'\n]{0,256}'|[^\s\"':]+:[^\s\"']+)"),
     r"\1" + REDACTED),
    # Authorization header (any scheme) and bare Bearer tokens
    (re.compile(r"(?i)(\bauthorization[\"']?\s{0,64}[:=]\s{0,64}[\"']?)(?:(?:bearer|basic|token)\s{1,64})?[^\s\"',;]+"),
     r"\1" + REDACTED),
    (re.compile(r"(?i)\b(bearer\s{1,64})[A-Za-z0-9._~+/=-]{6,}"), r"\1" + REDACTED),
    # known key shapes
    (re.compile(r"\bgithub_pat_[A-Za-z0-9_]{10,}"), REDACTED),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{10,}"), REDACTED),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{10,}"), REDACTED),
    (re.compile(r"\bAIza[0-9A-Za-z_-]{20,}"), REDACTED),
    (re.compile(r"\bxox[a-z]-[A-Za-z0-9-]{8,}"), REDACTED),
    (re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"), REDACTED),
    (re.compile(r"\b[rs]k_(?:live|test)_[A-Za-z0-9]{10,}"), REDACTED),
    (re.compile(r"\bnpm_[A-Za-z0-9]{20,}"), REDACTED),
    (re.compile(r"\bhf_[A-Za-z0-9]{20,}"), REDACTED),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}"), REDACTED),
    # name=value / name: value where the name says token, key, secret or password
    (re.compile(r"(?i)([\"']?\b(?:[A-Za-z0-9_.-]{0,64}(?:token|secret|passwd|password|pwd)[A-Za-z0-9_]{0,64}"
                r"|(?:[A-Za-z0-9.-]{0,64}[_.-])?key)[\"']?"
                r"\s{0,64}[:=]\s{0,64}[\"']?)(?!\[REDACTED\])[^\s\"'&,;}]+"), r"\1" + REDACTED),
    # aws configure set aws_secret_access_key VALUE (a space, no '=' or ':')
    (re.compile(r"(?i)(\baws_(?:secret_access_key|session_token)[\"']?\s{1,64})(?![=:\s]|\[REDACTED\])[^\s\"']+"),
     r"\1" + REDACTED),
    # CLI flags: --token X, --password X, -p X is too ambiguous and is left alone
    (re.compile(r"(?i)(--(?:[a-z0-9-]{0,64}-)?(?:token|api-key|key|secret|password)(?:\s{1,64}|=))(?!\[REDACTED\])[^\s\"']+"),
     r"\1" + REDACTED),
)


# redact() only ever sees a bounded window: callers slice a value to what is stored plus
# this margin, so a secret cut at the stored slice's edge is still matched whole, and
# the regexes never run over a large Write payload or tool output.
REDACT_MARGIN = 400


def redact(text) -> str:
    """Mask secrets in text. Callers pass a bounded slice (stored length + REDACT_MARGIN)."""
    return _redact_window(str(text), MAX_OUTPUT_LEN + 4 * REDACT_MARGIN)


def _redact_window(s: str, width: int) -> str:
    """Redact s[:width]. When the window cuts s, the last partial token at the cut is
    dropped first, so no fragment of a secret that straddles the edge can survive or be
    shifted into a stored prefix when earlier redactions shorten the text."""
    if len(s) > width:
        s = re.sub(r"\S*$", "", s[:width]) + " " + REDACTED
    for pattern, repl in _REDACTIONS:
        s = pattern.sub(repl, s)
    return s


def safe(value, keep: int) -> str:
    """The first `keep` chars of value, redacted over a wider window first."""
    return _redact_window(str(value), keep + REDACT_MARGIN)[:keep]


def make_private(db_path: str = ""):
    """umask 077 for everything this process (and memory_store) creates, and tighten the
    store a pre-umask install left world-readable (dir 0700, DB/log 0600). Best effort."""
    os.umask(0o077)
    d = Path(db_path).parent if db_path else Path.home() / ".claude" / ".cowork-mem"
    try:
        if d.is_dir():
            os.chmod(d, 0o700)
            for f in d.iterdir():
                if f.is_file() and (f.name.startswith("memory.db") or f.name.startswith("capture-errors.log")):
                    os.chmod(f, 0o600)
    except OSError:
        pass

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def truncate(s: str, max_len: int) -> str:
    s = str(s).strip()
    return s if len(s) <= max_len else s[:max_len - 3] + "..."


def is_meaningful_bash(cmd: str) -> bool:
    """Return True if the bash command is worth capturing."""
    cmd = cmd.strip().lower()
    if any(cmd.startswith(p) for p in TRIVIAL_BASH_PREFIXES):
        return False
    if any(cmd.startswith(p) for p in MEANINGFUL_BASH_PREFIXES):
        return True
    # Long commands (>60 chars) are usually doing something real
    return len(cmd) > 60


def extract_response_text(tool_response) -> str:
    """Pull text content out of the tool_response field."""
    if isinstance(tool_response, str):
        return tool_response
    if isinstance(tool_response, list):
        parts = []
        for item in tool_response:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(item.get("text", ""))
        return " ".join(parts)
    if isinstance(tool_response, dict):
        return tool_response.get("text", tool_response.get("content", ""))
    return ""


def find_memory_script() -> str | None:
    """Find memory_store.py relative to this script."""
    this_dir = Path(__file__).parent
    candidate = this_dir / "memory_store.py"
    return str(candidate) if candidate.exists() else None


def _add_timeout() -> float:
    """Outlast memory_store's worst case: integrity check + repair + command, each
    allowed to wait COWORK_MEM_BUSY_TIMEOUT (default 10s) on a lock."""
    try:
        busy = float(os.environ.get("COWORK_MEM_BUSY_TIMEOUT", "10"))
    except ValueError:
        busy = 10.0
    return 3 * busy + 5


def save_observation(obs_type: str, content: str, tags: str = "auto-capture"):
    """Call memory_store.py to save an observation."""
    script = find_memory_script()
    if not script:
        return  # Plugin not found — silent
    content = redact(content)  # last line of defence; every field was redacted already

    db_path = os.environ.get("COWORK_MEM_DB", "")
    env = dict(os.environ)
    if db_path:
        env["COWORK_MEM_DB"] = db_path

    try:
        r = subprocess.run(
            ["python3", script, "add", obs_type, content, "--tags", tags],
            env=env,
            timeout=_add_timeout(),
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            _report_failure(f"memory_store add exited {r.returncode}: {(r.stderr or r.stdout).strip()}", db_path)
    except Exception as e:
        # Hook errors must not break Claude's workflow -- but never lose a write silently.
        _report_failure(f"capture failed: {e}", db_path)


def _report_failure(message: str, db_path: str = ""):
    """Surface a failed write: stderr line + append to capture-errors.log next to the DB."""
    line = f"[cowork-mem] WRITE FAILED: {redact(message)}"
    try:
        print(line, file=sys.stderr)
    except Exception:
        pass
    try:
        log_dir = Path(db_path).parent if db_path else Path.home() / ".claude" / ".cowork-mem"
        log_dir.mkdir(parents=True, exist_ok=True)
        log = log_dir / "capture-errors.log"
        if log.exists() and log.stat().st_size > MAX_ERROR_LOG_BYTES:
            os.replace(log, log_dir / "capture-errors.log.1")
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(f"{datetime.now(timezone.utc).isoformat()} {line}\n")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Per-tool handlers
# ---------------------------------------------------------------------------

def handle_edit(tool_input: dict, _response: str):
    file_path = safe(tool_input.get("file_path", "unknown"), 200)
    old = tool_input.get("old_string", "")
    new = tool_input.get("new_string", "")
    # Build a compact diff summary
    old_lines = len(old.splitlines())
    new_lines = len(new.splitlines())
    delta = f"+{new_lines}/-{old_lines} lines"
    content = truncate(f"Edited {file_path} ({delta}): {safe(new, 120)}", MAX_CONTENT_LEN)
    save_observation("file_edit", content, tags="auto-capture,file-edit")


def handle_write(tool_input: dict, _response: str):
    file_path = safe(tool_input.get("file_path", "unknown"), 200)
    file_content = tool_input.get("content", "")
    lines = len(file_content.splitlines())
    content = truncate(f"Wrote {file_path} ({lines} lines)", MAX_CONTENT_LEN)
    save_observation("file_edit", content, tags="auto-capture,file-write")


def handle_bash(tool_input: dict, response: str):
    raw_cmd = tool_input.get("command", "").strip()
    if not is_meaningful_bash(raw_cmd):
        return  # Skip trivial commands

    output_snippet = truncate(response, 150)
    content = truncate(f"Ran: {safe(raw_cmd, 200)}" + (f" → {output_snippet}" if output_snippet else ""), MAX_CONTENT_LEN)
    save_observation("tool_use", content, tags="auto-capture,bash")


def handle_task(tool_input: dict, response: str):
    description = safe(tool_input.get("description", tool_input.get("prompt", "")), 100)
    result_snippet = truncate(response, 200)
    content = truncate(f"Agent task: {description}" + (f" → {result_snippet}" if result_snippet else ""), MAX_CONTENT_LEN)
    save_observation("insight", content, tags="auto-capture,agent-task")


def handle_todo_write(tool_input: dict, _response: str):
    todos = tool_input.get("todos", [])
    pending = [safe(t.get("content", ""), 200) for t in todos if t.get("status") == "pending"]
    if not pending:
        return
    items = "; ".join(pending[:3])
    content = truncate(f"Plan updated. Pending: {items}", MAX_CONTENT_LEN)
    save_observation("note", content, tags="auto-capture,plan")


HANDLERS = {
    "Edit":         handle_edit,
    "Write":        handle_write,
    "Bash":         handle_bash,
    "Task":         handle_task,
    "TodoWrite":    handle_todo_write,
    "NotebookEdit": handle_write,
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    try:
        make_private(os.environ.get("COWORK_MEM_DB", ""))
        raw = sys.stdin.read()
        if not raw.strip():
            return

        payload = json.loads(raw)
        tool_name    = payload.get("tool_name", "")
        tool_input   = payload.get("tool_input", {})
        tool_response = payload.get("tool_response", "")

        if tool_name not in CAPTURE_TOOLS:
            return  # Not a tool we care about

        response_text = safe(extract_response_text(tool_response), MAX_OUTPUT_LEN)

        handler = HANDLERS.get(tool_name)
        if handler:
            handler(tool_input, response_text)

    except Exception:
        pass  # Never surface hook errors to Claude


if __name__ == "__main__":
    main()
