---
name: fix-stuck-session
description: >
  Fixes the "RPC error: process with name already running" bug in Claude Cowork.
  Use this skill when the user reports: "process already running", "RPC error",
  "session won't load", "task didn't load properly", "stuck session", "cowork
  not working", "can't resume session", "orphaned process", "connection aborted",
  "session crashed", "cowork frozen", "follow-up message fails", or any error
  mentioning a session name like "optimistic-stoic-knuth already running".
  Also trigger when the user pastes an error containing "RPC error" or
  "process with name" or "already running".
metadata:
  version: "1.1.0"
  author: "MSApps"
  supported_os: "Windows, macOS, Linux"
  sosa:
    level: 3
    supervised: "User confirmation required before any destructive action"
    orchestrated: "Plan > Act > Verify with structured report"
    secured: "Local filesystem only, no credentials"
    agents: "Scoped to session diagnostics — no file deletion, no config changes"
---

# Fix Stuck Cowork Session

Resolve the common "RPC error: process with name already running" bug that blocks Cowork sessions.
Uses a tiered approach — trying the most elegant fix first, then escalating only if needed.
## SOSA Supervised Gate

**CRITICAL**: Before ANY fix action (archiving, killing processes, clearing cache), present
findings to the user and ask for explicit confirmation. Example:

```
| Session Name | Title | Status | Error | Proposed Action |
|-------------|-------|--------|-------|-----------------|
| busy-wizardly-mccarthy | WhatsApp reminder | idle | RPC error: already running | Archive |
```

"I found [N] stuck session(s). Should I proceed with the fix?"

**Do NOT proceed without explicit user confirmation.** This applies to ALL tiers below.

## Understanding the Problem

Two root causes produce this error:

1. **Orphaned State File** — The session JSON at `~/Library/Application Support/Claude/
   local-agent-mode-sessions/<org-id>/<user-id>/local_<uuid>.json` retains
   `isArchived: false` and holds a `vmProcessName`, blocking new sessions.
2. **Orphaned Process** — A previous session crashed but its process entry was never cleaned up.

Both manifest as the same blocking error that prevents follow-up messages or session resumption.
## Diagnostic & Fix Procedure

Work through these tiers in order. Stop as soon as the issue is resolved.

### Tier 1: Identify the Stuck Session

Parse the error message to extract the **session name** and **process ID** if present.

Use `mcp__session_info__list_sessions` to cross-reference which sessions are idle but holding
a process name. Report findings to the user in a table (see Supervised Gate above).

### Tier 2: Archive Session State File (Fastest Fix)

**macOS** — Find and archive the stuck session JSON:

```bash
mdfind -onlyin ~/Library/Application\ Support/Claude "RPC error"
```

Then set `isArchived: true`:

```python
python3 -c "
import json
path = '<session-file-path>'
with open(path) as f:
    data = json.load(f)
data['isArchived'] = True
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print('Archived: ' + data.get('processName', 'unknown'))
"
```

This usually works immediately without restarting Claude Desktop.
### Tier 3: Graceful Process Cleanup

If Tier 2 doesn't resolve it, try killing the orphaned process:

1. List active sessions using Desktop Commander's `list_sessions`
2. Confirm the session is truly orphaned (no recent activity)
3. Use `force_terminate` or `kill_process` to end it
4. Ask user to close the stuck tab and reopen

### Tier 4: Process-Level Kill

**macOS/Linux:**
```bash
ps aux | grep -i "claude\|cowork" | grep -v grep
kill -9 <PID>
```

**Windows:**
```powershell
Get-Process | Where-Object { $_.ProcessName -like "*claude*" }
Stop-Process -Name "claude*" -Force
```

### Tier 5: Cache & State Cleanup

**WARNING**: Ask user confirmation — this clears ALL active Cowork sessions.

**macOS:** `rm -rf ~/Library/Application\ Support/Claude/cowork/`
**Windows:** `Remove-Item -Recurse -Force "$env:APPDATA\Claude\cowork\"`

### Tier 6: Full Reset (Nuclear Option)

1. Quit Claude Desktop completely
2. Delete VM state (macOS: `~/Library/Application Support/Claude/vm_bundles/`)
3. Reboot computer
4. Relaunch Claude Desktop — fresh VM image downloads on first use
## Verify (Post-Fix)

After any fix:

1. Call `mcp__session_info__list_sessions` to confirm the session is cleared
2. Ask user to create a new Cowork task to verify it works
3. Produce a structured report:

```
## Session Fix Report
- Sessions scanned: [N]
- Stuck sessions found: [N]
- Sessions fixed: [N]
- Fix tier used: [1-6]
- Status: [SUCCESS / PARTIAL / NEEDS_RESTART]
```

## Error Variants Handled

- `RPC error: process with name "X" already running (id: Y)`
- `RPC error -1: process with name "X" already running`
- `RPC error: ensure user: user X should already exist but does not`
- `failed to write stdin: Error: failed to write data: An established connection was aborted`
- `kill failed with error: Error: sdk-daemon not connected`
- `This task didn't load properly`
- `Failed to run onQuitCleanup(cowork-vm-shutdown): Error: Request timed out`

## Domain Boundaries

This skill ONLY handles session diagnostics and recovery. It does NOT:
- Delete user files or data
- Modify Claude Desktop configuration
- Access anything outside session state files and processes

## Reference Issues

- [#30655](https://github.com/anthropics/claude-code/issues/30655) — Orphaned VM process blocks resume
- [#28094](https://github.com/anthropics/claude-code/issues/28094) — Connection errors after crash
- [#37810](https://github.com/anthropics/claude-code/issues/37810) — Exits with code 1
- [#25707](https://github.com/anthropics/claude-code/issues/25707) — Task didn't load properly