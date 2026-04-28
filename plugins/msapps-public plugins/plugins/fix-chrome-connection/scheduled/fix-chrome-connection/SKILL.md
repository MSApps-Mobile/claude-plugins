---
name: fix-chrome-connection
description: Diagnose and fix Chrome MCP connection issues — run after switching macOS users when Chrome won't connect
---

This is an automated run of a scheduled task. The user is not present to answer questions.
Make reasonable choices autonomously and note them in your output.
For "write" actions, only take them if explicitly required by the task.
When in doubt, produce a report of what you found.

You are fixing a broken Chrome MCP connection. Work through these steps in order,
stopping as soon as the connection works.

## Step 1: Test current connection

Call tabs_context_mcp with createIfEmpty: false.
- If it responds (any response other than a connection error) → report "Chrome is already connected!" and stop.
- If it fails with a connection error → note it and continue.

## Step 2: Screenshot the current desktop state

```bash
screencapture -x /tmp/chrome_check.png
sips -Z 1920 /tmp/chrome_check.png --out /tmp/chrome_check_small.png
```

Copy to workspace and Read it. Note what's visible (Chrome open? which app is in focus? any errors?).

## Step 3: Open Chrome

```bash
open -a "Google Chrome"
sleep 3
```

Retry connection test. If connected → report success and stop.

## Step 4: Quit and relaunch Chrome ← MOST RELIABLE FIX

Do NOT attempt to click UI elements on chrome://extensions — the Claude desktop app steals
focus from Chrome, making coordinate-based clicking fail. Go straight to quit+relaunch:

```bash
osascript -e 'tell application "Google Chrome" to quit'
sleep 5
open -a "Google Chrome"
sleep 8
```

Retry connection test. If connected → report success and stop.

## Step 5: Report failure and ask the user

If all automated steps failed, report:
- Every step attempted and what happened
- Current state of Chrome (from last screenshot)
- Ask: "Are you logged into the correct Chrome profile? After switching macOS users, Chrome
  may open under a different profile where the extension isn't installed."

## Step 6: Last resort

If the profile check doesn't help, suggest reinstalling the Claude in Chrome extension:
open chrome://extensions → remove Claude in Chrome → reinstall from Chrome Web Store.

## After each step

Report what you tried and what happened. Do not silently retry.
