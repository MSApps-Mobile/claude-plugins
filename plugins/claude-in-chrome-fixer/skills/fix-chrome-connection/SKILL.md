---
name: fix-chrome-connection
description: >
  This skill should be used when running the "fix-chrome-connection" scheduled task,
  or when the user says "fix Chrome", "Chrome MCP is broken", "reconnect Chrome",
  "Chrome connection failed", or "Chrome extension not responding".
  It diagnoses and repairs broken Claude-in-Chrome MCP connections step by step,
  then self-reflects on any new learnings to improve future runs.
metadata:
  version: "0.2.0"
  author: "MSApps"
---

## Purpose

Diagnose and repair a broken Claude-in-Chrome MCP connection. This typically happens after switching Claude Desktop accounts or after Chrome restarts.

---

## Step 1: Test current connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

- Responds (even "no tab group exists") → **Connected.** Proceed to Step 1b.
- Connection error/timeout → continue to Step 2.

### Step 1b: Verify tab group creation

Call `tabs_context_mcp` with `createIfEmpty: true`.

- Succeeds → report success, jump to Self-Reflection.
- Returns **"Tabs can only be moved to and from normal windows"** → fix by opening a new window: `osascript -e 'tell application "Google Chrome" to make new window'`, then retry.

---

## Step 2: Diagnose the failure mode

```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

- `"No Chrome extension connected after discovery"` → Account switch issue → skip to **Step 4**
- `"Chrome extension connected to bridge"` → Bridge OK, try Step 3
- Did user recently switch accounts? If **yes** → skip to **Step 4**.

---

## Step 3: Simple reconnect (no account switch)

```bash
open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"
```

Wait 3s, retry `tabs_context_mcp`. If it fails, tell user: **"Click the orange Connect button."** (Button is disabled until a name is typed in the input field.)

---

## Step 4: Account Switch Fix (CDP — no user clicks needed)

When the extension is authenticated with the wrong account, use Chrome DevTools Protocol.

### 4a: Setup debug profile

```bash
mkdir -p /tmp/chrome-debug-profile/NativeMessagingHosts
ln -sf "$HOME/Library/Application Support/Google/Chrome/Default" /tmp/chrome-debug-profile/Default
ln -sf "$HOME/Library/Application Support/Google/Chrome/Local State" "/tmp/chrome-debug-profile/Local State"
cp ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json \
   /tmp/chrome-debug-profile/NativeMessagingHosts/ 2>/dev/null || true
```

### 4b: Launch debug Chrome

```bash
osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null; sleep 3
open -a "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug-profile --no-first-run --no-default-browser-check
sleep 4
```

### 4c: Authorize via CDP

Use Python with `websockets` to connect to `http://localhost:9222/json`, navigate to the OAuth authorize URL, click the Authorize button, then navigate to the pairing page. For the pairing input (React controlled), use the native setter:
```javascript
let setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
setter.call(input, 'Claude Desktop');
input.dispatchEvent(new Event('input', { bubbles: true }));
```
Then click Connect.

### 4d: Verify and switch back

```bash
sleep 5 && tail -20 ~/Library/Logs/Claude/main.log | grep -i chrome
# Look for "Chrome extension connected to bridge" ✅
osascript -e 'tell application "Google Chrome" to quit'; sleep 3
open -a "Google Chrome"; sleep 4
osascript -e 'tell application "Google Chrome" to make new window'
```

Test `tabs_context_mcp` with `createIfEmpty: true`.

---

## Step 5: Manual re-auth fallback

Tell the user:
1. Chrome toolbar → puzzle icon → "Claude in Chrome" → sign out
2. Sign in with correct account
3. Connection restores automatically

---

## Step 6: Last resort

Remove extension at `chrome://extensions`, reinstall from Chrome Web Store.

---

## Self-Reflection Step

After every run, ask: "Did I learn anything that would improve future runs?"

If yes, edit files in `~/claude-plugins/plugins/claude-in-chrome-fixer/` and commit:
```bash
cd ~/claude-plugins && git add plugins/claude-in-chrome-fixer/ && git commit -m "fix-chrome-connection: self-improvement from run on $(date '+%Y-%m-%d')" && git push origin main
```

Only push after fix is confirmed working.

---

## Known Issues

**"Tabs can only be moved to and from normal windows"**: Chrome has popup windows open (OAuth/login). Fix: `osascript -e 'tell application "Google Chrome" to make new window'`

**Pairing page input**: React controlled — must use native HTMLInputElement setter, not direct `input.value` assignment.

**Account switch — restart doesn't help**: Claude Desktop uses `wss://bridge.claudeusercontent.com/chrome/{userId}`. After account switch, userId changes. Extension must re-auth to join the new bridge channel. Use Step 4 CDP approach.

**Focus grabbing**: Claude app steals focus from Chrome. Use MCP tools and AppleScript instead of coordinate clicks.

## Architecture

- Claude Desktop → `wss://bridge.claudeusercontent.com/chrome/{userId}` ← Chrome extension
- Native host: `/Applications/Claude.app/Contents/Helpers/chrome-native-host`
- Local socket: `/tmp/claude-mcp-browser-bridge-{username}/0.sock` (legacy/secondary)
- Native messaging manifest: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
