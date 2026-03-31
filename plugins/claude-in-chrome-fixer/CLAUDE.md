# Claude in Chrome Fixer — Claude Code Guide

This plugin diagnoses and repairs broken Claude-in-Chrome MCP connections. It is fully self-improving: after every run it commits its learnings back to this repository.

---

## When to use this skill

Use `fix-chrome-connection` when:
- `tabs_context_mcp` returns a connection error or times out
- `tabs_context_mcp` returns "Tabs can only be moved to and from normal windows"
- The user says "fix Chrome", "Chrome MCP broken", "reconnect Chrome", "Chrome not responding"
- The user recently switched Claude Desktop accounts
- A scheduled task triggers `fix-chrome-connection`

---

## Quick decision tree

```
tabs_context_mcp(createIfEmpty=false) errors?
├── YES → Check main.log for "No Chrome extension connected after discovery"
│   ├── FOUND → Account switch issue → Go to Step 5 (MANUAL re-auth, skip CDP entirely)
│   └── NOT FOUND → Check logs for connected=true but 70ms timeout
│       ├── YES → Stale 0.sock → Run Step 2b (fix symlink)
│       └── NO → Simple disconnect → Run Step 3b (reconnect URL) then Step 3 (pairing page)
└── NO (returns "no tab group") → Connection OK, test createIfEmpty=true
    ├── SUCCEEDS → Done ✅
    └── "normal windows" error → osascript make new window → retry
```

---

## Key commands

### Test connection
```bash
# Via MCP tool
mcp__Claude_in_Chrome__tabs_context_mcp(createIfEmpty=False)
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

### Reconnect URL (quick trigger — try first)
```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://clau.de/chrome/reconnect"'
sleep 5
tail -5 ~/Library/Logs/Claude/main.log | grep -i "chrome extension"
```

### Open pairing page (for non-account-switch disconnects)
```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"'
```

### Fix "normal windows" error
```bash
osascript -e 'tell application "Google Chrome" to make new window'
```

---

## Account Switch Fix — MANUAL ONLY (CDP does not work)

> ⚠️ The CDP/debug-profile approach (Step 4 in SKILL.md) **does not work** for account switches. The debug profile has no session cookies — the OAuth page shows a login screen. Don't attempt it.

**Tell the user:**
1. Chrome toolbar → 🧩 → Claude in Chrome → sign out
2. Sign back in with the **same account as Claude Desktop** (check Claude Desktop's account menu)
3. When pairing page appears — type a name → click Connect
4. Navigate Chrome to `https://claude.ai` ← **critical: wakes the extension service worker**
5. Tell Claude "done"

**After user says done:**
```bash
# Fix 0.sock
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
NEW=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '/0.sock' | head -1)
[ -n "$NEW" ] && ln -sf "$NEW" "$DIR/0.sock" && echo "Updated"

# Wait for bridge — may take a few seconds
sleep 5
tail -10 ~/Library/Logs/Claude/main.log | grep -iE "chrome extension|bridge"
```

Then call `tabs_context_mcp(createIfEmpty=true)`. Retry once if it fails immediately — the bridge connection log entry appears shortly after the socket is fixed.

---

## Architecture facts (critical for correct diagnosis)

- Connection uses **WebSocket bridge**: `wss://bridge.claudeusercontent.com/chrome/{userId}`
- Each Claude account = different `userId` = different bridge channel
- After account switch: Claude Desktop joins new channel, extension stays on old → they never find each other
- Both sides can show the same email but still fail — mismatch is at userId level
- Chrome restarts do NOT fix account switches — extension auth persists across restarts
- Local Unix socket `/tmp/claude-mcp-browser-bridge-{username}/0.sock` — secondary path
- The `0.sock` symlink goes stale on **every Chrome restart** — must be updated manually
- Multiple `.sock` files = multiple native host instances (normal with multiple Chrome processes) — use newest
- Navigating to `https://claude.ai` wakes the extension service worker and triggers native host start

## Pairing page: React input trick

The Connect button is **disabled** until a name is typed. Standard `input.value = "text"` doesn't work with React — use the native setter:

```javascript
let setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
setter.call(input, 'Claude Desktop');
input.dispatchEvent(new Event('input', { bubbles: true }));
input.dispatchEvent(new Event('change', { bubbles: true }));
```

## Known bugs filed with Anthropic

GitHub issue: https://github.com/anthropics/claude-code/issues/41298
- `0.sock` symlink not auto-updated on Chrome restart (native host bug)
- Account switch doesn't trigger extension re-auth (should send native message to re-auth automatically)

## Self-improvement rule

After a successful fix OR after capturing learnings from a failed run:
```bash
cd ~/claude-plugins
git add plugins/claude-in-chrome-fixer/
git commit -m "fix-chrome-connection: self-improvement from run on $(date '+%Y-%m-%d')"
git push origin HEAD:main
```

Note: push to `HEAD:main` (not just `main`) to avoid branch mismatch issues.

---

## Files in this plugin

| File | Purpose |
|------|---------|
| `skills/fix-chrome-connection/SKILL.md` | Full step-by-step repair procedure with all known issues |
| `README.md` | User-facing documentation |
| `CLAUDE.md` | This file — quick reference for Claude Code |
| `.claude-plugin/plugin.json` | Plugin metadata |
