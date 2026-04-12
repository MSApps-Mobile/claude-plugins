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
"""

import json
import os
import subprocess
import sys
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


def save_observation(obs_type: str, content: str, tags: str = "auto-capture"):
    """Call memory_store.py to save an observation."""
    script = find_memory_script()
    if not script:
        return  # Plugin not found — silent

    db_path = os.environ.get("COWORK_MEM_DB", "")
    env = dict(os.environ)
    if db_path:
        env["COWORK_MEM_DB"] = db_path

    try:
        subprocess.run(
            ["python3", script, "add", obs_type, content, "--tags", tags],
            env=env,
            timeout=5,
            capture_output=True,
        )
    except Exception:
        pass  # Hook errors must not break Claude's workflow


# ---------------------------------------------------------------------------
# Per-tool handlers
# ---------------------------------------------------------------------------

def handle_edit(tool_input: dict, _response: str):
    file_path = tool_input.get("file_path", "unknown")
    old = tool_input.get("old_string", "")
    new = tool_input.get("new_string", "")
    # Build a compact diff summary
    old_lines = len(old.splitlines())
    new_lines = len(new.splitlines())
    delta = f"+{new_lines}/-{old_lines} lines"
    content = truncate(f"Edited {file_path} ({delta}): {new[:120]}", MAX_CONTENT_LEN)
    save_observation("file_edit", content, tags="auto-capture,file-edit")


def handle_write(tool_input: dict, _response: str):
    file_path = tool_input.get("file_path", "unknown")
    file_content = tool_input.get("content", "")
    lines = len(file_content.splitlines())
    content = truncate(f"Wrote {file_path} ({lines} lines)", MAX_CONTENT_LEN)
    save_observation("file_edit", content, tags="auto-capture,file-write")


def handle_bash(tool_input: dict, response: str):
    cmd = tool_input.get("command", "").strip()
    if not is_meaningful_bash(cmd):
        return  # Skip trivial commands

    output_snippet = truncate(response, 150)
    content = truncate(f"Ran: {cmd[:200]}" + (f" → {output_snippet}" if output_snippet else ""), MAX_CONTENT_LEN)
    save_observation("tool_use", content, tags="auto-capture,bash")


def handle_task(tool_input: dict, response: str):
    description = tool_input.get("description", tool_input.get("prompt", ""))[:100]
    result_snippet = truncate(response, 200)
    content = truncate(f"Agent task: {description}" + (f" → {result_snippet}" if result_snippet else ""), MAX_CONTENT_LEN)
    save_observation("insight", content, tags="auto-capture,agent-task")


def handle_todo_write(tool_input: dict, _response: str):
    todos = tool_input.get("todos", [])
    pending = [t.get("content", "") for t in todos if t.get("status") == "pending"]
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
        raw = sys.stdin.read()
        if not raw.strip():
            return

        payload = json.loads(raw)
        tool_name    = payload.get("tool_name", "")
        tool_input   = payload.get("tool_input", {})
        tool_response = payload.get("tool_response", "")

        if tool_name not in CAPTURE_TOOLS:
            return  # Not a tool we care about

        response_text = extract_response_text(tool_response)
        response_text = truncate(response_text, MAX_OUTPUT_LEN)

        handler = HANDLERS.get(tool_name)
        if handler:
            handler(tool_input, response_text)

    except Exception:
        pass  # Never surface hook errors to Claude


if __name__ == "__main__":
    main()
