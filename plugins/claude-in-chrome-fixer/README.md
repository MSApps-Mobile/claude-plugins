# Claude-in-Chrome Fixer

Automatically diagnoses and repairs broken [Claude in Chrome](https://claude.ai/download) MCP connections — including the hard case of **Claude Desktop account switches**. Designed to run as a scheduled task and **self-improves** after each run by committing learnings back to this repository.

---

## What it fixes

| Scenario | Fix |
|----------|-----|
| Chrome restarted / extension disconnected | Opens pairing page, guides reconnect |
| **Claude Desktop account switch** | Full programmatic fix via Chrome DevTools Protocol — no user clicks needed |
| `tabs_context_mcp` "normal windows" error | Opens a new Chrome window to clear OAuth popup interference |
| Extension lost auth state | OAuth re-authorization via CDP |

---

## How it works

### Simple disconnect (Chrome restarted)
1. Tests current connection via `tabs_context_mcp`
2. Opens the pairing page directly: `chrome-extension://...pairing.html`
3. Guides user to click Connect (or does it automatically if debug port is available)

### Account switch (the hard case)
When you switch Claude Desktop accounts, the extension stays authenticated with the **old** account. Claude Desktop and the extension connect to different bridge channels (`wss://bridge.claudeusercontent.com/chrome/{userId}`) and can't find each other.

**The automated fix:**
1. Creates a temporary Chrome profile (symlinked to real profile, preserves extension)
2. Launches Chrome with `--remote-debugging-port=9222` on the temp profile
3. Uses Chrome DevTools Protocol (CDP) to navigate to the OAuth page and click **Authorize**
4. Uses CDP to type a name in the pairing page input and click **Connect**
5. Quits debug Chrome → regular Chrome reconnects automatically
6. Opens a new window if needed to clear the "normal windows" tab group error

**Result: Fully automated — zero user clicks required.**

---

## Skills

| Skill | Trigger phrases |
|-------|----------------|
| `fix-chrome-connection` | Scheduled task · "fix Chrome" · "Chrome MCP is broken" · "reconnect Chrome" · "Chrome connection failed" · "Chrome extension not responding" |

---

## Setup as a Scheduled Task

```
Ask Claude: "Run fix-chrome-connection"
```

Or set it up to run automatically:
```
Ask Claude: "Create a scheduled task that runs fix-chrome-connection every morning at 7am"
```

---

## Requirements

- Claude in Chrome extension installed and previously configured
- Desktop Commander MCP connected (for shell commands and process management)
- Python 3 + `websockets` package: `pip3 install websockets`
- Git configured with push access to `MSApps-Mobile/claude-plugins`
- macOS (AppleScript used for Chrome window management)

---

## Architecture: How the connection actually works

```
Claude Desktop ←→ wss://bridge.claudeusercontent.com/chrome/{userId} ←→ Chrome Extension
```

- Each Claude account has its own bridge channel (keyed by `userId`)
- After an account switch, Claude Desktop connects to a **new** bridge channel
- The extension must re-authenticate (via OAuth) to join the same channel
- Chrome restarts do **not** fix account switch issues — extension auth state persists across restarts
- Secondary local socket at `/tmp/claude-mcp-browser-bridge-{username}/0.sock` exists but is not the primary connection path

---

## Self-improvement

After every run, the skill asks itself: *"Did I learn anything new?"* If yes, it:
- Updates `skills/fix-chrome-connection/SKILL.md` with new knowledge
- Commits and pushes to `MSApps-Mobile/claude-plugins` on GitHub
- Reports what was learned

The skill gets smarter over time automatically — no manual updates needed.

---

## Diagnostic reference

**Check bridge connection status:**
```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

Key log messages:
- `"No Chrome extension connected after discovery"` → account switch or extension not running
- `"Chrome extension connected to bridge"` → bridge connected ✅
- `"Selected Chrome extension: ..."` → fully working ✅

**Check for OAuth popup windows causing tab group errors:**
```bash
osascript -e 'tell application "Google Chrome" to return name of windows'
```
If you see "Zoho Accounts", "Adobe ID", "Google Sign In" etc. — those are popup windows. Fix:
```bash
osascript -e 'tell application "Google Chrome" to make new window'
```
