---
name: fix-chrome-connection
description: >
  Fixes a broken Claude in Chrome MCP connection. Use this skill whenever the user says
  "fix chrome", "chrome not connecting", "chrome is broken", "reconnect chrome",
  "chrome MCP not working", "chrome stopped working", or any complaint about the
  Claude in Chrome extension not responding. Also trigger when any Chrome MCP tool call
  fails with a connection error and the user asks to fix it.
---

# Fix Chrome MCP Connection

Systematically restore a broken Chrome MCP connection. Work through steps in order,
stopping and reporting success as soon as the connection is restored.

**Platform note:** This skill uses macOS-specific commands (AppleScript, `open`, `osascript`).
It requires Chrome to be the browser and macOS to be the OS.

## ⚠️ Critical: do not attempt UI clicking

Do NOT try to click elements on `chrome://extensions` using coordinate-based AppleScript.
The Claude desktop app steals focus from Chrome, causing clicks to land in the wrong window.
Use only terminal commands (Desktop Commander) to control Chrome.

---

## Step 1: Test current connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

- Response contains tab info OR "no tab group exists" → **Chrome IS connected.** Tell the user and stop.
- Response says "not connected" error → note it, continue to Step 2.
- Response says **"Multiple Chrome extensions connected"** → go to **Step 1a** below.

---

## Step 1a: Handle "Multiple Chrome extensions connected"

This error means the Claude Desktop app's MCP server sees more than one Chrome extension
instance connected (e.g., from a prior session, stale WebSocket, or multiple Chrome profiles).

**First, try the automated fix — quit and relaunch Chrome:**

```bash
osascript -e 'tell application "Google Chrome" to quit'
sleep 5
open -a "Google Chrome"
sleep 10
```

Retry `tabs_context_mcp` with `createIfEmpty: false`.

- If connected → done, report success.
- If still showing "Multiple Chrome extensions connected" → the issue persists on the MCP
  server side (stale connections from previous Claude sessions survive a Chrome restart).
  **User action is required:** Tell the user:

> "Chrome is showing as 'Multiple Chrome extensions connected', which means there are leftover
> connections from a previous session that I can't clear automatically.
> Please click the Claude in Chrome extension icon (top-right in Chrome's toolbar) and then
> click the **Connect** button in the popup. This tells the MCP bridge which Chrome window to use.
> Let me know once you've done that and I'll retry."

After the user confirms, retry `tabs_context_mcp`. If it succeeds → report success and stop.
If not → continue to Step 2.

---

## Step 2: Screenshot and assess

Use Desktop Commander to capture and view the current screen state:

```bash
screencapture -x /tmp/chrome_check.png
sips -Z 1920 /tmp/chrome_check.png --out /tmp/chrome_check_small.png
```

Copy to the workspace folder and Read it. Note: Is Chrome open? Is it on the right profile?
Report what you see before continuing.

---

## Step 3: Open Chrome

```bash
open -a "Google Chrome"
sleep 3
```

Retry connection test. If connected → done and report success.

---

## Step 4: Quit and relaunch Chrome ← PRIMARY FIX

If Step 3 didn't work, go straight here. This is the most reliable fix — no UI interaction needed.

```bash
# Quit Chrome via AppleScript
osascript -e 'tell application "Google Chrome" to quit'
sleep 5

# Relaunch
open -a "Google Chrome"
sleep 8
```

Retry connection test. If connected → done and report success.

**Why this works:** Quitting Chrome terminates any stale extension service workers.
On relaunch, extensions reinitialize cleanly and the MCP bridge reconnects.

---

## Step 5: Ask the user

If automated steps haven't worked, report every step tried and ask:

> "Are you on the correct Chrome profile? After switching macOS users, Chrome sometimes opens
> under a different profile where the extension isn't installed. Try clicking the profile icon
> (top-right in Chrome) and switching profiles, then let me know and I'll retry."

After they confirm, retry the connection test.

---

## Step 6: Last resort

Tell the user:
- Open `chrome://extensions` in Chrome
- Find "Claude in Chrome", click Remove
- Reinstall from the Chrome Web Store

---

## Reporting

After every step, tell the user:
- What you tried
- What happened (success, error, still broken)
- What you're trying next

---

## Self-Reflection Step

After completing the skill (whether successful or not), record what happened:

1. What error was encountered?
2. What step resolved it (or what step failed)?
3. Was there a new scenario not covered by this skill?
4. If new knowledge was gained, update this SKILL.md and commit the changes.

**Known error scenarios and their resolutions:**
- `not connected` → Step 3 (open Chrome) or Step 4 (quit/relaunch) usually fixes this.
- `Multiple Chrome extensions connected` (persists after Chrome restart) → Requires user to click
  **Connect** in the Chrome extension popup. Cannot be fully automated. (Documented 2026-03-26)
