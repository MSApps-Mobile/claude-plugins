# Claude in Chrome Fixer — Claude Code Guide

This plugin diagnoses and repairs broken Claude-in-Chrome MCP connections, including the difficult case of **Claude Desktop account switches**. It is fully self-improving: after every run it commits its learnings back to this repository.

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
├── YES → Check main.log for "No Chrome extension connected"
│   ├── FOUND → Account switch issue → Run Step 4 (CDP fix)
│   └── NOT FOUND → Simple disconnect → Run Step 3 (open pairing page)
└── NO (returns "no tab group") → Connection OK, test createIfEmpty=true
    ├── SUCCEEDS → Done ✅
    └── "normal windows" error → osascript make new window → retry
```

---

## Key commands

### Test connection
```python
# Call MCP tool
mcp__Claude_in_Chrome__tabs_context_mcp(createIfEmpty=False)
```

### Check logs
```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

### Open pairing page (simple fix)
```bash
open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"
```

### Fix "normal windows" error
```bash
osascript -e 'tell application "Google Chrome" to make new window'
```

### Full account switch fix (CDP — programmatic, no user clicks)

```bash
# Step 1: Create debug Chrome profile with symlinks to real profile
mkdir -p /tmp/chrome-debug-profile/NativeMessagingHosts
ln -sf "$HOME/Library/Application Support/Google/Chrome/Default" "/tmp/chrome-debug-profile/Default"
ln -sf "$HOME/Library/Application Support/Google/Chrome/Local State" "/tmp/chrome-debug-profile/Local State"
cp ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json \
   /tmp/chrome-debug-profile/NativeMessagingHosts/ 2>/dev/null || \
cp ~/Library/Application\ Support/Chromium/NativeMessagingHosts/com.anthropic.claude_browser_extension.json \
   /tmp/chrome-debug-profile/NativeMessagingHosts/

# Step 2: Quit regular Chrome, launch debug Chrome
osascript -e 'tell application "Google Chrome" to quit'; sleep 3
open -a "Google Chrome" --args \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug-profile \
  --no-first-run --no-default-browser-check
sleep 5

# Step 3: Run CDP script (see SKILL.md for full Python code)
# Navigates to OAuth page → clicks Authorize → goes to pairing page → types name → clicks Connect

# Step 4: Switch back to regular Chrome
osascript -e 'tell application "Google Chrome" to quit'; sleep 3
open -a "Google Chrome"; sleep 4

# Step 5: Open new window to clear any OAuth popup interference
osascript -e 'tell application "Google Chrome" to make new window'
```

---

## Architecture facts (critical for correct diagnosis)

- Connection uses **WebSocket bridge**: `wss://bridge.claudeusercontent.com/chrome/{userId}`
- Each Claude account = different `userId` = different bridge channel
- After account switch: Claude Desktop joins new channel, extension stays on old channel → they can't find each other
- Chrome restarts do NOT fix account switches — extension auth persists across restarts
- Local Unix socket `/tmp/claude-mcp-browser-bridge-{username}/0.sock` is secondary/legacy
- Claude Desktop's socket client (`vNr()`) looks for `0.sock` specifically

## Pairing page: React input trick

The Connect button is **disabled** until a name is typed. Standard `input.value = "text"` doesn't work with React — use the native setter:

```javascript
let setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
setter.call(input, 'Claude Desktop');
input.dispatchEvent(new Event('input', { bubbles: true }));
input.dispatchEvent(new Event('change', { bubbles: true }));
```

## Self-improvement rule

**Only commit and push AFTER the fix is confirmed working.** Never push when the connection is still broken.

After a successful fix:
```bash
cd ~/claude-plugins
git add plugins/claude-in-chrome-fixer/
git commit -m "fix-chrome-connection: self-improvement from run on $(date '+%Y-%m-%d')"
git push origin main
```

---

## Files in this plugin

| File | Purpose |
|------|---------|
| `skills/fix-chrome-connection/SKILL.md` | Full step-by-step repair procedure with all known issues |
| `README.md` | User-facing documentation |
| `CLAUDE.md` | This file — quick reference for Claude Code |
| `.claude-plugin/plugin.json` | Plugin metadata |
