# Fix Chrome Connection

> Diagnoses and repairs broken Claude in Chrome MCP connections in seconds.

Most common cause: switching macOS users causes Chrome's extension service worker to go stale. This plugin detects the problem and fixes it automatically — no manual steps needed.

---

## Skills

### `fix-chrome-connection`
Full repair workflow. Say **"fix chrome"** or **"chrome not connecting"** to trigger it.

Steps it runs:
1. Tests the current connection
2. Screenshots the desktop to assess state
3. Opens Chrome if not running
4. Quits and relaunches Chrome (the reliable fix — no UI clicking required)
5. Asks about Chrome profiles if automated steps fail
6. Suggests reinstalling the extension as a last resort

### `chrome-health-check`
Quick one-call status check. Say **"is chrome connected?"** or **"check chrome"**.

Reports ✅ connected or ❌ disconnected, and offers to run the fix if needed.

---

## Scheduled Task

A pre-configured daily task is included under `scheduled/fix-chrome-connection/`.

**To set it up in Cowork:**
1. Copy `scheduled/fix-chrome-connection/SKILL.md` into your `Scheduled/fix-chrome-connection/` folder
2. Create a new scheduled task in Cowork pointing to that file
3. Set it to run daily at your preferred startup time

---

## Requirements

- macOS (uses AppleScript and `open` command)
- Google Chrome
- Claude in Chrome extension installed

---

## How the fix works

The key insight: **don't try to toggle/reload the extension through `chrome://extensions` UI**.

When Claude is running alongside Chrome, the Claude desktop app steals focus — any AppleScript coordinate clicks land in the wrong window. Instead, the plugin uses:

```bash
osascript -e 'tell application "Google Chrome" to quit'
sleep 5
open -a "Google Chrome"
```

No UI interaction. Works every time.

---

## Author

[MSApps](https://msapps.mobi) · [All plugins](https://msapps-mobile.github.io/claude-plugins/)
