---
name: chrome-devtools-mcp-cleanup
description: Diagnose + clean up the recurring chrome-devtools-mcp wedge — multiple stale `chrome-devtools-mcp@latest` parent processes colliding on the shared `~/.cache/chrome-devtools-mcp/chrome-profile` directory. Use when state-changing tools (new_page, navigate_page, select_page, take_snapshot) error with "The browser is already running for /Users/.../chrome-profile. Use --isolated to run multiple browser instances." while `list_pages` still works. Card #223 (CvjIx0qZ).
---

# chrome-devtools-mcp wedge cleanup

> **Different server from Claude-in-Chrome.** This is for `chrome-devtools-mcp`
> (DevTools Protocol; tools `new_page`, `take_snapshot`, `navigate_page`,
> `evaluate_script`, `lighthouse_audit`). Not the Claude-in-Chrome extension
> (`mcp__Claude_in_Chrome__*`). Both can be down independently — see the
> sibling `/fix-chrome-connection` skill for the extension.

## Symptom

`list_pages` works (read-only) but every state-changing tool errors with:

> The browser is already running for /Users/michalshatz/.cache/chrome-devtools-mcp/chrome-profile. Use --isolated to run multiple browser instances.

Root cause: ≥2 concurrent `chrome-devtools-mcp@latest` parents, each spawning Chromium pinned to the shared profile dir. The Chrome that the *current* MCP tries to start collides with one started by a stale MCP parent from an earlier session.

The permanent fix landed in `~/.claude.json` (per-user MCP config) — the chrome-devtools server now passes `--isolated` so each session gets its own profile. This skill is the one-time cleanup for hosts where stale parents accumulated *before* that fix.

## When to invoke

Use deliberately — **NOT** from a scheduled-task runner. Killing processes on a shared Mac is destructive; the user must opt in.

Trigger phrases: "fix chrome-devtools-mcp", "chrome-devtools wedged", "browser is already running for chrome-profile", "stale chrome-devtools parents", "card #223 cleanup".

## Diagnosis

```bash
# 1. List all chrome-devtools-mcp parent processes
ps -eo pid,etime,command | awk '/chrome-devtools-mcp@latest/ && !/awk/'

# 2. List Chromium children spawned by them (pinned to chrome-profile)
ps -eo pid,ppid,etime,command \
  | awk '/chrome-devtools-mcp\/chrome-profile/ && !/awk/'

# 3. Show the lock file holder
ls -la ~/.cache/chrome-devtools-mcp/chrome-profile/SingletonLock 2>/dev/null
```

If only ONE parent shows up: the wedge is unrelated to staleness — verify the new `--isolated` flag is in `~/.claude.json`:

```bash
grep -A6 '"chrome-devtools"' ~/.claude.json | head -10
```

Should show `"--isolated"` in the args array. If missing, add it (close every Claude Code window first; the change picks up at next launch).

## Cleanup — only when ≥2 parents found

```bash
# Identify orphaned parents — those whose ppid is 1 (init) or whose parent
# is a long-dead Claude session (stat of /proc/<ppid> equivalent on macOS:
# we just check if the ppid resolves to a live `claude` process).
ps -eo pid,ppid,etime,command | awk '/chrome-devtools-mcp@latest/ && !/awk/' \
  | while read pid ppid etime cmd; do
      parent_alive=$(ps -p "$ppid" -o command= 2>/dev/null | grep -c claude || true)
      printf "%s\tppid=%s\tparent_alive=%s\tetime=%s\n" "$pid" "$ppid" "$parent_alive" "$etime"
    done
```

Identify the parent **owned by the current session** (its ppid corresponds to your active Claude Code process — `pgrep -f "claude.*-l" | head` or check the session you're running in). Keep that one; kill the others:

```bash
# Pseudocode — REVIEW each PID before running. Replace <ORPHAN_PID> with the
# pid of a parent whose own parent is dead / non-Claude.
kill -TERM <ORPHAN_PID>            # graceful
sleep 2
kill -KILL <ORPHAN_PID> 2>/dev/null # if it's still around

# Then sweep their Chromium children:
pkill -f 'chrome-devtools-mcp/chrome-profile' || true
```

Don't `pkill -f chrome-devtools-mcp@latest` blindly — that nukes your active session's parent too.

## Verify

```bash
# 1. Only ONE parent should remain (the active session's).
ps -eo pid,ppid,etime,command | awk '/chrome-devtools-mcp@latest/ && !/awk/' | wc -l

# 2. Lock file should be either gone or owned by the surviving parent.
ls -la ~/.cache/chrome-devtools-mcp/chrome-profile/SingletonLock 2>/dev/null

# 3. From your active Claude Code session, smoke-test:
#    list_pages         → should still work
#    new_page("https://example.com")  → should succeed without "browser already running"
#    take_snapshot      → should succeed
```

## After cleanup — confirm the permanent fix is in place

```bash
grep -A6 '"chrome-devtools"' ~/.claude.json | head -10
```

You should see:

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": [
    "chrome-devtools-mcp@latest",
    "--isolated"
  ],
  "env": {}
}
```

With `--isolated` in place, future sessions will each get their own Chromium profile directory under a tmp path — no more SingletonLock collisions, even if multiple Claude Code windows are open.

## Why we chose --isolated over per-PID userDataDir

`--isolated` is the upstream-blessed flag and is one line of config. Per-PID (`--userDataDir /tmp/chrome-devtools-mcp-${PID}`) requires shell expansion that `claude mcp` doesn't do, and accumulates orphan profile dirs that need their own cleanup pass. The `--isolated` flag handles cleanup automatically when the parent exits.

## Don't

- Don't run this cleanup from a scheduled-task runner. Process-killing is destructive on a shared Mac; the user must opt in.
- Don't `rm -rf ~/.cache/chrome-devtools-mcp/chrome-profile/` while a session is active — corrupts the running Chromium's state.
- Don't `pkill -f chrome-devtools-mcp@latest` blindly — kills your active session's parent too.

## Refs

- Card #223: https://trello.com/c/CvjIx0qZ
- Sibling skill (Claude-in-Chrome extension): `/fix-chrome-connection`
- Permanent fix landed: `~/.claude.json` chrome-devtools args now `["chrome-devtools-mcp@latest", "--isolated"]` (2026-05-06)
