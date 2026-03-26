---
name: fix-chrome-connection
description: >
  This skill should be used when running the "fix-chrome-connection" scheduled task,
  or when the user says "fix Chrome", "Chrome MCP is broken", "reconnect Chrome",
  "Chrome connection failed", or "Chrome extension not responding".
  It diagnoses and repairs broken Claude-in-Chrome MCP connections step by step,
  then self-reflects on any new learnings to improve future runs.
metadata:
  version: "0.1.0"
  author: "MSApps"
---

## Purpose

Diagnose and repair a broken Claude-in-Chrome MCP connection. This typically happens after switching macOS users or after Chrome restarts. Work through the steps below in order, stopping as soon as the connection works.

---

## Step 1: Test current connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

- If it responds (even with "no tab group exists") → **Chrome is already connected.** Report success and jump to the Self-Reflection step.
- If it throws a connection error or times out → note the error and continue to Step 2.

---

## Step 2: Take a screenshot to assess desktop state

Run via Desktop Commander:
```
screencapture -x /tmp/chrome_check.png
sips -Z 1920 /tmp/chrome_check.png
```
Copy to the workspace folder and read the image to understand the current desktop state. Note what you observe.

---

## Step 3: Open/focus Chrome

Run via Desktop Commander:
```
open -a "Google Chrome"
```
Wait 3 seconds, then retry `tabs_context_mcp` with `createIfEmpty: false`.

- If it works → report success and jump to Self-Reflection.
- If not → continue.

---

## Step 4: Quit and relaunch Chrome (most effective fix)

> **Note:** Avoid trying to click UI elements in chrome://extensions — the Claude desktop app steals focus and clicks land in the wrong window. A full quit+relaunch is more reliable.

Run these commands in sequence via Desktop Commander:
```
osascript -e 'tell application "Google Chrome" to quit'
sleep 5
open -a "Google Chrome"
sleep 8
```

Then retry `tabs_context_mcp` with `createIfEmpty: false`.

- If it works → report success and jump to Self-Reflection.
- If not → continue.

---

## Step 5: Inform the user

If all automated steps failed, report everything that was tried and ask the user:

1. Are you logged into the correct Chrome profile? After a macOS user switch, Chrome may open under a different profile where the extension is not installed.
2. Ask them to click the profile icon (top-right in Chrome) and switch to the right profile, then retry.

---

## Step 6: Last resort

Tell the user to open `chrome://extensions`, remove the Claude in Chrome extension, then reinstall it from the Chrome Web Store.

---

## Self-Reflection Step (run after EVERY execution)

After completing any of the steps above, pause and ask yourself:

> "Did I learn anything during this run that would make future runs faster, more reliable, or better at diagnosing problems?"

Examples of learnings worth capturing:
- A step that consistently fails or succeeds
- A new failure mode encountered
- A faster diagnostic shortcut discovered
- An edge case or timing issue worth noting
- A step ordering improvement

**If you learned something:**

1. Edit any relevant file in `~/claude-plugins/plugins/claude-in-chrome-fixer/` to incorporate the new knowledge — update SKILL.md steps, add a Known Issues entry, or add a new reference file.
2. Run these git commands via Desktop Commander to commit and push the **entire plugin directory**:

```bash
cd ~/claude-plugins
git add plugins/claude-in-chrome-fixer/
git commit -m "fix-chrome-connection: self-improvement from run on $(date '+%Y-%m-%d')"
git push origin main
```

3. Report what you learned, which files you changed, and confirm the push succeeded.

**If you did not learn anything new:** Simply state "No new learnings from this run." and finish.

---

## Reporting

After each run, always output a brief summary:
- Which steps were attempted
- What the outcome was
- What (if anything) was learned and updated

---

## Known Issue: Focus Grabbing (Chrome loses focus to Claude app)

**Problem:** When Claude in Chrome tries to interact with `chrome://extensions` or any Chrome UI via coordinate-based clicking, the Claude desktop app itself steals window focus. Clicks land in the wrong window (the Claude app instead of Chrome), making UI automation unreliable.

**Root cause:** The Claude desktop app is always-on-top or aggressively reclaims focus when tool calls complete.

**Solution — operate Chrome in the background without stealing focus:**

All Chrome interaction must happen through **MCP tools and AppleScript**, not coordinate-based clicks. The Claude-in-Chrome extension can receive commands via MCP even when Chrome is not the frontmost window.

Preferred approach:
1. Use `tabs_context_mcp`, `navigate`, `javascript_tool`, and other Claude-in-Chrome MCP tools — these communicate with the extension over a background socket and do **not** require Chrome to be focused.
2. Avoid `computer` (screenshot + click) workflows for Chrome — use JavaScript injection via `javascript_tool` instead.
3. For Chrome restart (Step 4), use AppleScript `tell application "Google Chrome" to quit` — this works without Chrome being frontmost.
4. If you must check extension state, use `javascript_tool` to query `chrome.management` or `chrome.runtime` APIs rather than navigating to `chrome://extensions` and clicking.

**AppleScript background activation (when needed):**
```applescript
tell application "Google Chrome"
  activate
  -- do work here
end tell
tell application "Claude" to activate  -- restore focus to Claude after
```

This lets Chrome briefly come to front for AppleScript commands, then returns focus to Claude.
