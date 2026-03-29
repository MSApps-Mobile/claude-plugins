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
  version: "1.0.0"
  author: "MSApps"
  supported_os: "Windows, macOS, Linux"
---

# Fix Stuck Cowork Session

This skill resolves the common "RPC error: process with name already running" bug that blocks
Cowork sessions. It uses a tiered approach — trying the most elegant fix first, then escalating
to more aggressive methods only if needed.

## Understanding the Problem

Two root causes produce this error:

1. **Orphaned Process** — A previous Cowork session crashed or lost its VM connection, but the
   process entry was never cleaned up. The system thinks it's still running and blocks new work.
2. **Missing Session Directory** — The session user was initialized but its home directory
   (\`/sessions/<session-name>\`) was deleted or never created. The VM can't recover.

Both manifest as the same blocking error that prevents any follow-up messages or session resumption.

## Diagnostic & Fix Procedure

Work through these tiers in order. Stop as soon as the issue is resolved.

### Tier 1: Identify the Stuck Session

Parse the error message to extract:
- The **session name** (e.g., \`optimistic-stoic-knuth\`)
- The **process ID** if present (e.g., \`7e090cc5-e7be-48f8-9d10-9c2ba4c167af\`)

Use \`list_sessions\` (if available via session_info MCP or Desktop Commander) to check if the
session appears as active/running. Report findings to the user clearly:

\`\`\`
Found the problem: Session "optimistic-stoic-knuth" has an orphaned process
that wasn't cleaned up after a crash. Let me fix this.
\`\`\`

### Tier 2: Graceful Session Cleanup (Preferred)

Try the gentlest approach first:

1. **List active terminal sessions** using Desktop Commander's \`list_sessions\` tool
2. If the stuck session appears, attempt to **read its output** to confirm it's truly orphaned
   (blocked indefinitely, no recent activity)
3. Use \`force_terminate\` or \`kill_process\` to end it cleanly
4. Ask the user to **close the stuck Cowork tab** in Claude Desktop and reopen it

Tell the user:
\`\`\`
I've cleared the orphaned process. Close the stuck session tab in Claude Desktop,
then reopen it — it should work now.
\`\`\`

### Tier 3: Process-Level Kill (Windows & macOS)

If Tier 2 doesn't work (Desktop Commander can't see the process, or kill doesn't help):

**On macOS/Linux:**
\`\`\`bash
# Find orphaned cowork/claude processes
ps aux | grep -i "claude\\|cowork" | grep -v grep

# Kill specific orphaned processes
pkill -f "claude cowork"
# Or target by PID if found
kill -9 <PID>
\`\`\`

**On Windows (if user has terminal access):**
\`\`\`powershell
# List Claude-related processes
Get-Process | Where-Object { $_.ProcessName -like "*claude*" -or $_.ProcessName -like "*cowork*" }

# Kill orphaned processes
Stop-Process -Name "claude*" -Force
# Or use taskkill
taskkill /F /IM "claude.exe" /T
\`\`\`

Provide these commands to the user with clear instructions. Explain what each command does
before they run it.

### Tier 4: Cache & State Cleanup

If process killing alone doesn't resolve it, stale state files may be the culprit.

**On macOS:**
\`\`\`bash
# Remove VM state (forces clean VM boot on next launch)
rm -rf ~/Library/Application\\ Support/Claude/cowork/
rm -rf ~/Library/Caches/Claude/

# Check for leftover session lock files
ls -la ~/Library/Application\\ Support/Claude/ | grep -i session
\`\`\`

**On Windows:**
\`\`\`powershell
# Remove VM state
Remove-Item -Recurse -Force "$env:APPDATA\\Claude\\cowork\\"
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\\Claude\\Cache\\"
\`\`\`

**IMPORTANT:** Warn the user that this will clear all active Cowork sessions. Any unsaved
in-progress work in OTHER sessions will also be lost. Ask for confirmation before proceeding.

### Tier 5: Full Reset (Nuclear Option)

If nothing else works:

1. **Quit Claude Desktop completely** (not just close — fully quit from system tray/menu bar)
2. **Wait 10 seconds** for all background processes to terminate
3. **Delete all VM state:**
   - macOS: \`rm -rf ~/Library/Application\\ Support/Claude/vm_bundles/\`
   - Windows: \`Remove-Item -Recurse -Force "$env:APPDATA\\Claude\\vm_bundles\\"\`
4. **Reboot the computer** (clears any kernel-level process locks)
5. **Relaunch Claude Desktop** — it will download a fresh VM image on first Cowork use

Tell the user:
\`\`\`
This is the nuclear option — it forces Claude Desktop to start completely fresh.
You won't lose your conversation history, but all active Cowork sessions will reset.
After reboot, the first Cowork task may take a minute longer while it sets up.
\`\`\`

## After Fixing

Once the fix succeeds:

1. **Confirm with the user** that they can create a new Cowork task or resume their session
2. **Explain the root cause** briefly: "This happens when a Cowork session crashes without
   cleaning up its background process. It's a known bug — Anthropic is tracking it."
3. **Share prevention tips:**
   - Avoid opening the same Cowork session in multiple tabs simultaneously
   - If Claude Desktop freezes, quit it fully (don't force-close) to allow cleanup
   - If you see "connection aborted" errors, close and reopen the session tab before
     it becomes fully orphaned

## Error Variants This Skill Handles

All of these are the same underlying issue:

- \`RPC error: process with name "X" already running (id: Y)\`
- \`RPC error -1: process with name "X" already running\`
- \`RPC error: ensure user: user X should already exist but does not\`
- \`failed to write stdin: Error: failed to write data: An established connection was aborted\`
- \`kill failed with error: Error: sdk-daemon not connected\`
- \`This task didn't load properly\`
- \`Failed to run onQuitCleanup(cowork-vm-shutdown): Error: Request timed out\`

## Reference Issues

This skill addresses bugs tracked in:
- [#30655](https://github.com/anthropics/claude-code/issues/30655) — Orphaned VM process blocks resume
- [#24483](https://github.com/anthropics/claude-code/issues/24483) — RPC error persists after cleanup
- [#28094](https://github.com/anthropics/claude-code/issues/28094) — Connection errors after crash
- [#25707](https://github.com/anthropics/claude-code/issues/25707) — Task didn't load properly
- [#24190](https://github.com/anthropics/claude-code/issues/24190) — Error on opening session
