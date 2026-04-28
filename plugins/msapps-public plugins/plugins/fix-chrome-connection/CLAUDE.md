# Fix Chrome Connection — Claude Guide

**Plugin:** fix-chrome-connection
**Author:** MSApps
**Role:** Diagnose and repair broken Claude-in-Chrome MCP connections. Fully self-improving — commits learnings to GitHub after every run.

---

## When to use this skill

- `tabs_context_mcp` returns a connection error or times out
- `tabs_context_mcp` returns "Tabs can only be moved to and from normal windows"
- User says "fix Chrome", "Chrome MCP broken", "reconnect Chrome", "Chrome not responding", "is chrome connected?"
- User recently switched Claude Desktop accounts
- A scheduled task triggers this skill

---

## Quick decision tree

```
tabs_context_mcp(createIfEmpty=false) errors?
├── YES → Check main.log: tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
│   ├── "No Chrome extension connected after discovery"
│   │   ├── Is this a scheduled task session? → Expected — use Control_Chrome only (see Scheduled Tasks)
│   │   └── Live session? → Account switch or session mismatch → Step 5 (manual re-auth)
│   ├── connected=true + tool calls fail in ~70ms → Stale 0.sock → Step 2b
│   └── No log entries → Chrome not running → restart Chrome
└── NO (returns "no tab group") → Connection OK
    └── tabs_context_mcp(createIfEmpty=true)
        ├── SUCCEEDS → Done ✅
        └── "normal windows" error → osascript make new window → retry
```

---

## Key commands

### Test connection
```bash
# MCP tool
mcp__Claude_in_Chrome__tabs_context_mcp(createIfEmpty=false)
```

### Check logs
```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

### Fix stale 0.sock (after any Chrome restart)
```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
NEW=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '/0.sock' | head -1)
[ -n "$NEW" ] && ln -sf "$NEW" "$DIR/0.sock" && echo "Updated 0.sock → $NEW" || echo "No socket found"
```

### Reconnect URL (quick trigger — try first for non-account-switch)
```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://clau.de/chrome/reconnect"'
sleep 5
tail -5 ~/Library/Logs/Claude/main.log | grep -i "chrome extension"
```

### Open pairing page
```bash
open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"
```

### Fix "normal windows" error
```bash
osascript -e 'tell application "Google Chrome" to make new window'
```

### Restart Chrome
```bash
pkill -a "Google Chrome"; sleep 3; open -a "Google Chrome"; sleep 8
```

---

## Architecture (fully reverse-engineered 2026-04-11)

Two separate Chrome connections — do NOT confuse them:

| Connection | Protocol | When it works |
|---|---|---|
| `Control_Chrome` | Chrome DevTools Protocol (CDP) | Any time Chrome is open |
| `Claude_in_Chrome` | WebSocket bridge + native host | Only when extension is paired to the active session |

### Bridge architecture
```
Chrome Extension
      ↕ stdin/stdout (native messaging)
chrome-native-host  (/Applications/Claude.app/Contents/Helpers/chrome-native-host)
      ↕ Unix socket (/tmp/claude-mcp-browser-bridge-{user}/{pid}.sock)
Claude App MCP server
      ↕ WebSocket (wss://bridge.claudeusercontent.com/chrome/{userId})
Cowork Session (paired via ~/Library/Application Support/Claude/bridge-state.json)
```

### Critical session-pairing rule (discovered 2026-04-11)
- The extension pairs to whichever **Cowork session window is in focus** when you click Connect
- `bridge-state.json` stores the `localSessionId` for the pairing
- **Scheduled task sessions have their own sessionId** — Chrome CANNOT pair to them
- `tabs_context_mcp` will ALWAYS fail in scheduled tasks — this is by design, not a bug
- **Fix for live sessions:** focus the Cowork window, THEN click Connect in Chrome

### 0.sock symlink
- Claude Desktop socket client looks specifically for `0.sock` in the socket directory
- Chrome restart creates a new `{pid}.sock` but does NOT update `0.sock`
- Stale `0.sock` = `connected=true, authenticated=true` but every tool call fails in ~70ms
- Fix: `ln -sf {newest.sock} 0.sock`

---

## Scheduled Tasks

`tabs_context_mcp` does NOT work in scheduled task sessions. Use `Control_Chrome` instead:

```bash
mcp__Control_Chrome__list_tabs()  # Works in scheduled tasks
```

Health check logic for scheduled tasks:
1. `Control_Chrome list_tabs` fails → Chrome not running → restart it
2. `Control_Chrome` works + `tabs_context_mcp` fails → expected in scheduled tasks — report status only

---

## Self-improvement rule

After every run (successful or not), if you learned something:
1. Update relevant files in `~/Documents/claude-plugins/plugins/fix-chrome-connection/`
2. Run:
```bash
cd ~/Documents/claude-plugins
git add plugins/fix-chrome-connection/
git commit -m "fix-chrome-connection: self-improvement $(date '+%Y-%m-%d')"
git pull --rebase origin main && git push origin main
```

---

## Files in this plugin

| File | Purpose |
|---|---|
| `skills/fix-chrome-connection/SKILL.md` | Full step-by-step repair procedure |
| `skills/chrome-health-check/SKILL.md` | Lightweight status check (safe to run anytime) |
| `scheduled/fix-chrome-connection/SKILL.md` | Scheduled daily health check task |
| `README.md` | User-facing documentation |
| `CLAUDE.md` | This file — quick reference |
| `.claude-plugin/plugin.json` | Plugin metadata |
