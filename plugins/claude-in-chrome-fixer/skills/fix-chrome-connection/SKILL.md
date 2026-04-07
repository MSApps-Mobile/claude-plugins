---
name: fix-chrome-connection
description: >
  This skill should be used when running the "fix-chrome-connection" scheduled task,
  or when the user says "fix Chrome", "Chrome MCP is broken", "reconnect Chrome",
  "Chrome connection failed", or "Chrome extension not responding".
  It diagnoses and repairs broken Claude-in-Chrome MCP connections step by step,
  then self-reflects on any new learnings to improve future runs.
metadata:
  version: "0.6.0"
  author: "MSApps"
---

## Purpose

Diagnose and repair a broken Claude-in-Chrome MCP connection. This typically happens after switching Claude Desktop accounts or after Chrome restarts. Work through the steps below in order, stopping as soon as the connection works.

---

## Step 1: Test current connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

- If it responds (even with "no tab group exists") → **Chrome is already connected.** Proceed to Step 1b (verify tab group creation works).
- If it throws a connection error or times out → note the error and continue to Step 2.

### Step 1b: Verify tab group creation

Call `tabs_context_mcp` with `createIfEmpty: true`.

- If it succeeds → report success and jump to the Self-Reflection step.
- If it returns **"Tabs can only be moved to and from normal windows"** → See Known Issue: tabs_context_mcp "normal windows" error below. Fix: open a new Chrome window via AppleScript:
  ```bash
  osascript -e 'tell application "Google Chrome" to make new window'
  ```
  Then retry `createIfEmpty: true`.

---

## Step 2: Diagnose the failure mode

Before trying anything, determine WHY it's broken:

**Check logs for clues:**
```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

Key log messages and their meaning:
- `"No Chrome extension connected after discovery"` → Extension not authenticated with current account (account switch issue)
- `"Chrome extension connected to bridge"` → Bridge connected successfully
- `"Selected Chrome extension: ..."` → Fully working
- `connected=true, authenticated=true, wsState=1` WITH `Tool call error: ... after ~70ms` → **Stale socket symlink** — bridge thinks it's connected but `0.sock` points to a dead socket from a previous Chrome session. Fix: see Step 2b below.

**Quick LevelDB diagnostic (extension bridge status):**
```bash
strings ~/Library/Application\ Support/Google/Chrome/Default/Local\ Extension\ Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn/*.ldb 2>/dev/null | grep -E "mcpConnected|Connected:"
```
- `Connected: false` with no `mcpConnected: true` → bridge WebSocket was never successfully established → account switch issue, skip to Step 4.
- `mcpConnected: true` present → bridge did connect at some point; failure may be transient or stale socket.
- Only `oauthState` key (no `mcpConnected: true`, no `Connected: false`) → extension started an OAuth flow but never completed it → treat as auth failure, go to **Step 5 (Manual Re-auth)**. This pattern appears when Chrome is freshly launched and the extension lost its auth between sessions.

**Ask yourself (or check logs):** Did the user recently switch Claude Desktop accounts?
- If **yes** → skip directly to **Step 5 (Manual Re-auth)**. ⚠️ Do NOT waste tokens on Steps 3, 3b, or 4. The CDP approach (Step 4) cannot fix an account switch — the debug Chrome profile has no session cookies, so the OAuth page just shows a login screen. Go straight to Step 5.
- If logs show `connected=true, authenticated=true` but tool calls fail in ~70ms → go to **Step 2b (Stale Socket Fix)**.
- If **no** → continue to Step 3.

---

## Step 2b: Stale Socket Symlink Fix

**Symptom:** Logs show `connected=true, authenticated=true, wsState=1` but every tool call fails in ~70ms with "Selected Chrome extension disconnected."

**Also applies when:** Chrome was not running → was just launched → socket directory exists but has NO `0.sock` symlink (only `XXXXXX.sock` files). The socket directory is freshly created without the symlink every time Chrome starts.

**Root cause:** Chrome restart (or fresh start) creates a new `.sock` file (named after the new Chrome PID) in `/tmp/claude-mcp-browser-bridge-{username}/`. If `0.sock` doesn't exist or still points to an old dead socket, Claude Desktop can't talk to Chrome.

**Important:** Fixing `0.sock` alone does NOT resolve authentication issues. If `tabs_context_mcp` still fails after fixing the symlink, the real problem is the WebSocket bridge auth — go to Step 5.

**Fix:**
```bash
# List the socket directory
ls -la /tmp/claude-mcp-browser-bridge-$(whoami)/

# Update 0.sock to point to the current socket (replace XXXXX with current Chrome PID socket)
ln -sf /tmp/claude-mcp-browser-bridge-$(whoami)/XXXXX.sock /tmp/claude-mcp-browser-bridge-$(whoami)/0.sock
```

**Automated fix (finds newest .sock automatically):**
```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
NEW_SOCK=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '0.sock' | head -1)
if [ -n "$NEW_SOCK" ]; then
  ln -sf "$NEW_SOCK" "$DIR/0.sock"
  echo "Updated 0.sock → $NEW_SOCK"
else
  echo "No active socket found"
fi
```

After running, retry `tabs_context_mcp` with `createIfEmpty: false`. If it works → jump to Self-Reflection.

---

## Step 3: Simple reconnect (no account switch)

Run via Desktop Commander:
```bash
open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"
```
Wait 3 seconds, then retry `tabs_context_mcp` with `createIfEmpty: false`.

- If it works → report success and jump to Self-Reflection.
- If not → tell the user: **"Chrome is open with a pairing page. Click the orange Connect button once."**

> **Note on pairing page:** The Connect button is DISABLED until you type a name in the input field. This is a React controlled input — see Known Issue: Pairing Page below.

---

## Step 3b: Reconnect URL (quick trigger — try before Step 4)

Navigate a Chrome tab to this URL. The extension service worker listens via `chrome.webNavigation.onBeforeNavigate` and triggers its reconnect handler (native host reconnect + bridge init):

```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://clau.de/chrome/reconnect"'
```

Wait 5 seconds, then check logs:
```bash
tail -10 ~/Library/Logs/Claude/main.log | grep -iE "chrome extension|bridge|No Chrome"
```
- `"Chrome extension connected to bridge"` → success! Test with `tabs_context_mcp`.
- Still `"No Chrome extension connected"` → continue to Step 4.

> **Note:** Requires Chrome to have an open window. If AppleScript returns "Can't get window 1" → open a window first: `osascript -e 'tell application "Google Chrome" to make new window'`

---

## Step 4: Re-auth Fix via CDP (NOT for account switches — only for expired/lost token)

> ⚠️ **Do NOT use this step for account switches.** If the failure happened after a Claude Desktop account switch, go directly to **Step 5**. The CDP approach cannot fix account switches because the debug Chrome profile has no session cookies — the OAuth page shows a login screen instead of the Authorize button.

This step only helps when the extension's token expired or was cleared, but the user's Chrome profile still has an active Claude.ai session.

When the extension lost auth but Chrome still has a valid Claude.ai session, the programmatic fix uses Chrome's DevTools Protocol (CDP) to click the Authorize and Connect buttons automatically.

**This procedure requires opening a temporary Chrome instance with a debug port.**

### 4a: Create a debug Chrome profile (symlinked to real profile)

```bash
# Create temp profile dir that mirrors real Chrome profile
mkdir -p /tmp/chrome-debug-profile/NativeMessagingHosts

# Symlink profile contents so extension stays installed
ln -sf "$HOME/Library/Application Support/Google/Chrome/Default" /tmp/chrome-debug-profile/Default
ln -sf "$HOME/Library/Application Support/Google/Chrome/Local State" /tmp/chrome-debug-profile/Local State"

# Copy native messaging manifest (needed for extension ↔ Claude Desktop communication)
cp ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json \
   /tmp/chrome-debug-profile/NativeMessagingHosts/ 2>/dev/null || true

# Also check Chromium path as fallback source
ls ~/Library/Application\ Support/Chromium/NativeMessagingHosts/ 2>/dev/null
```

> **If native messaging manifest doesn't exist in Chrome path yet:**
> ```bash
> mkdir -p ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
> cp ~/Library/Application\ Support/Chromium/NativeMessagingHosts/com.anthropic.claude_browser_extension.json \
>    ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
> ```

### 4b: Launch debug Chrome

> ⚠️ **Session cookie limitation:** The debug profile symlinks extension LevelDB storage but NOT Chrome session cookies. If the user hasn't previously logged into Claude.ai in this debug profile, the OAuth page will show a login screen — CDP can't proceed. Fall back to Step 5.

```bash
# Quit regular Chrome first if running
osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null; sleep 3

# ⚠️ `open -a "Google Chrome" --args` does NOT pass arguments to the binary.
# Use the full binary path directly:
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug-profile \
  --no-first-run \
  --no-default-browser-check &
sleep 5

# Verify CDP is listening
cat /tmp/chrome-debug-profile/DevToolsActivePort 2>/dev/null || echo "⚠️ DevToolsActivePort missing — CDP not available, fall back to Step 5"
```

### 4c: Authorize the extension with the correct account via CDP

Use Python to connect to CDP and click the OAuth Authorize button:

```python
import asyncio, json, urllib.request, websockets

async def cdp_click_authorize():
    # Get list of debuggable tabs
    tabs = json.loads(urllib.request.urlopen("http://localhost:9222/json").read())
    ws_url = tabs[0]["webSocketDebuggerUrl"]
    
    async with websockets.connect(ws_url) as ws:
        msg_id = 1
        
        async def send(method, params={}):
            nonlocal msg_id
            await ws.send(json.dumps({"id": msg_id, "method": method, "params": params}))
            msg_id += 1
            while True:
                r = json.loads(await ws.recv())
                if r.get("id") == msg_id - 1:
                    return r
        
        # Navigate to OAuth page
        await send("Page.navigate", {"url": "https://claude.ai/oauth/authorize?response_type=code&client_id=chrome_extension&redirect_uri=chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/oauth_callback.html&scope=openid+profile+email"})
        await asyncio.sleep(3)
        
        # Click the Authorize button
        await send("Runtime.evaluate", {"expression": """
            (function() {
                // Find button with text "Authorize" or "Allow"
                let btns = Array.from(document.querySelectorAll('button'));
                let btn = btns.find(b => /authorize|allow|continue/i.test(b.textContent));
                if (btn) { btn.click(); return 'clicked: ' + btn.textContent.trim(); }
                return 'button not found. Buttons: ' + btns.map(b=>b.textContent.trim()).join(', ');
            })()
        """})
        await asyncio.sleep(4)
        
        # Navigate to pairing page
        await send("Page.navigate", {"url": "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"})
        await asyncio.sleep(3)
        
        # Type a name in the input field (React controlled input — need native setter)
        await send("Runtime.evaluate", {"expression": """
            (function() {
                let input = document.querySelector('input[type="text"], input[placeholder]');
                if (!input) return 'no input found';
                let nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
                nativeInputValueSetter.call(input, 'Claude Desktop');
                input.dispatchEvent(new Event('input', { bubbles: true }));
                input.dispatchEvent(new Event('change', { bubbles: true }));
                return 'typed name: ' + input.value;
            })()
        """})
        await asyncio.sleep(1)
        
        # Click Connect button
        result = await send("Runtime.evaluate", {"expression": """
            (function() {
                let btns = Array.from(document.querySelectorAll('button'));
                let btn = btns.find(b => /connect/i.test(b.textContent) && !b.disabled);
                if (btn) { btn.click(); return 'clicked Connect'; }
                let allBtns = btns.map(b => b.textContent.trim() + '(disabled=' + b.disabled + ')').join(', ');
                return 'Connect not found. Buttons: ' + allBtns;
            })()
        """})
        return result

asyncio.run(cdp_click_authorize())
```

Run this via Desktop Commander's Python process.

### 4d: Check logs for successful bridge connection

```bash
sleep 5
tail -20 ~/Library/Logs/Claude/main.log | grep -i chrome
```

Look for:
- `"Chrome extension connected to bridge"` ✅
- `"Selected Chrome extension: ..."` ✅

### 4e: Switch back to regular Chrome

```bash
# Quit the debug Chrome instance
osascript -e 'tell application "Google Chrome" to quit'; sleep 3

# Launch regular Chrome
open -a "Google Chrome"; sleep 4

# The extension service worker will auto-reconnect to the bridge
```

### 4f: Open a new window to ensure tabs_context_mcp works

```bash
osascript -e 'tell application "Google Chrome" to make new window'
```

Then test `tabs_context_mcp` with `createIfEmpty: true`. It should succeed now.

---

## Step 5: Manual Re-auth (always works — the reliable fix for account switches)

Tell the user:

> **"The Chrome extension needs to be re-authenticated with your current Claude Desktop account. This takes ~60 seconds:"**
> 1. In Chrome toolbar → click the puzzle piece icon (🧩) → find "Claude in Chrome" → sign out
> 2. Sign back in with the **same account you use for Claude Desktop** (check Claude Desktop's account menu if unsure)
> 3. Authorize the connection when prompted
> 4. When the pairing page appears — type any name and click **Connect**
> 5. Navigate Chrome to **https://claude.ai** to wake the extension service worker
> 6. Tell Claude: "done" — then Claude will fix the `0.sock` symlink and verify

After the user says done, run the socket fix and test:
```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
NEW=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '/0.sock' | head -1)
[ -n "$NEW" ] && ln -sf "$NEW" "$DIR/0.sock" && echo "Updated 0.sock → $NEW" || echo "No socket — Chrome may need a new window"
```
Then call `tabs_context_mcp` with `createIfEmpty: true`. May take a few seconds to appear in logs — retry once if it fails immediately.

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

1. Edit any relevant file in `~/claude-plugins/plugins/claude-in-chrome-fixer/` to incorporate the new knowledge.
2. Run via Desktop Commander:

```bash
cd ~/claude-plugins
git add plugins/claude-in-chrome-fixer/
git commit -m "fix-chrome-connection: self-improvement from run on $(date '+%Y-%m-%d')"
git push origin main
```

3. Report what you learned, which files you changed, and confirm the push succeeded.

**Only commit and push AFTER the fix is confirmed working or after learnings are captured from a failed run.**

**If you did not learn anything new:** Simply state "No new learnings from this run." and finish.

---

## Reporting

After each run, always output a brief summary:
- Which steps were attempted
- What the outcome was
- What (if anything) was learned and updated

---

## Known Issue: tabs_context_mcp "Tabs can only be moved to and from normal windows"

**Symptom:** `tabs_context_mcp` with `createIfEmpty: true` returns one of these errors:
> `"Failed to query tabs: Tabs can only be moved to and from normal windows"`
> `"Failed to query tabs: Grouping is not supported by tabs in this window."`

Both errors have the same root cause and the same fix (see below).

**Root cause:** Chrome has one or more non-normal windows open — typically OAuth/login popup windows (e.g., "Zoho Accounts", "Adobe ID" login popups). These appear as "normal" to AppleScript but Chrome's internal API sees them as type "popup". When the extension tries to create a tab group, Chrome refuses because it can't move tabs from popup windows.

**Note:** This error does NOT mean the MCP connection is broken. `tabs_context_mcp` with `createIfEmpty: false` will succeed and confirm the extension is connected.

**Fix:**
```bash
osascript -e 'tell application "Google Chrome" to make new window'
```
Then retry `tabs_context_mcp` with `createIfEmpty: true`. The new window gives the extension a clean normal window to create the tab group in.

**Diagnostic:** Check window titles to identify popup windows:
```bash
osascript -e 'tell application "Google Chrome" to return name of windows'
```
If you see auth/login titles ("Zoho Accounts", "Adobe ID", "Google Sign In", etc.), those are likely the popup windows causing the issue.

---

## Known Issue: Pairing Page — The One Unavoidable Click (now automatable via CDP!)

**What was learned:** When the extension loses auth (e.g. after account switch), the extension shows a pairing page at:
`chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html`

**The pairing protocol (from reverse-engineering the JS):**
- Clicking Connect sends: `chrome.runtime.sendMessage({type:"pairing_confirmed", request_id, name})`
- Clicking Ignore sends: `chrome.runtime.sendMessage({type:"pairing_dismissed", request_id})`
- `request_id` comes from the URL parameter `?request_id=xxx` (opened by the service worker)

**Critical: The Connect button is DISABLED until a name is typed.** The input is a React controlled component — you CANNOT just set `input.value = "text"` and expect React to see it. You must use the React native input setter:
```javascript
let nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
nativeInputValueSetter.call(input, 'Claude Desktop');
input.dispatchEvent(new Event('input', { bubbles: true }));
input.dispatchEvent(new Event('change', { bubbles: true }));
```

**Automation approach (via CDP):** See Step 4 above. CDP on a debug Chrome instance allows programmatic clicking of both the OAuth Authorize button AND the pairing page Connect button. This is fully automated — no user clicks required.

**When CDP is not available (fallback):**
1. Open the pairing page: `open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"`
2. Tell the user: "The pairing page is open in Chrome. Type any name in the input field, then click the orange **Connect** button."

---

## Known Issue: Account Switch — Only Manual Re-auth Works

**Problem:** After switching Claude Desktop accounts, the Chrome extension stays authenticated with the old account. Chrome restart, socket fixes, and the CDP approach all fail.

**Symptoms:** `"No Chrome extension connected after discovery"` persists in logs regardless of what automated steps are taken. Both accounts may show the same email (e.g. `michal@msapps.mobi`) yet still fail — the mismatch is at the userId level on the bridge, not just the email.

**Root cause:** Claude Desktop connects to `wss://bridge.claudeusercontent.com/chrome/{userId}`. After account switch the userId changes. The extension still connects to the OLD userId channel. They never find each other.

**Why CDP (Step 4) doesn't work for account switches:** The debug Chrome profile symlinks extension LevelDB storage (so the extension loads) but does NOT copy session cookies. The OAuth authorize page just shows a login screen. No way to complete re-auth programmatically without a live session.

**The only working fix:** Step 5 — user signs out and back into the extension with the correct account, navigates to claude.ai, then fixes the 0.sock symlink.

**Complete working procedure (confirmed 2026-03-31):**
1. In Chrome: sign out of Claude in Chrome extension, sign back in with current Claude Desktop account
2. When pairing page appears — type a name, click Connect
3. Navigate Chrome to `https://claude.ai` (wakes the extension service worker, starts native host)
4. Fix the socket: `ln -sf $(ls -t /tmp/claude-mcp-browser-bridge-$(whoami)/*.sock | grep -v 0.sock | head -1) /tmp/claude-mcp-browser-bridge-$(whoami)/0.sock`
5. Wait a few seconds — bridge connection log entry `"Chrome extension connected to bridge"` should appear
6. Test with `tabs_context_mcp`

**Diagnostic hint:** `"No Chrome extension connected after discovery"` in logs = go directly to Step 5, skip everything else.

---

## Known Issue: Debug Chrome Profile — Session Cookies Not Transferred

**Problem:** The symlink approach in Step 4a copies the extension's LevelDB storage (allowing the extension to load with its OAuth token) but does NOT transfer Chrome session cookies. These are stored separately in `Cookies` (SQLite) and `Network/Cookies` files which are NOT symlinked.

**Result:** When debug Chrome opens the OAuth authorize page (`https://claude.ai/oauth/...`), it redirects to the Claude login page instead of showing the "Authorize" button — because the debug profile has no active session.

**Workaround options:**
1. Copy the real `Cookies` file (but this risks profile corruption if both Chrome instances open simultaneously)
2. Ask the user to log in manually (Step 5) — most reliable
3. Close ALL Chrome instances first, then launch debug Chrome with `--user-data-dir` pointing to the REAL profile directory (risky but avoids the cookie issue entirely). Use with caution.

**Quick diagnosis:** If CDP navigation to `https://claude.ai/oauth/authorize?...` returns a page with a login form instead of an Authorize button → session cookies are missing from the debug profile. Fall back to Step 5.

---

## Known Issue: Focus Grabbing (Chrome loses focus to Claude app)

**Problem:** When Claude tries to control Chrome via coordinate-based clicking, the Claude desktop app itself steals window focus.

**Solution:** Use Chrome MCP tools and AppleScript for all Chrome interaction — these work in the background without requiring Chrome to be focused.

---

## Architecture Reference

The Claude-in-Chrome connection uses a **WebSocket bridge** (not a local socket):

- Claude Desktop connects to: `wss://bridge.claudeusercontent.com/chrome/{userId}`
- Chrome extension also connects to the same URL using its OAuth session
- They find each other on the bridge via a pairing protocol
- Local Unix socket at `/tmp/claude-mcp-browser-bridge-{username}/0.sock` is a secondary/legacy path — NOT the main connection path

**After account switch:** The userId changes, so Claude Desktop connects to a new bridge channel. The extension must re-authenticate to join the same channel.

**Native host binary:** `/Applications/Claude.app/Contents/Helpers/chrome-native-host` — started by Chrome extension via native messaging, creates the Unix socket. The manifest must be in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/` (NOT just Chromium).

**Claude Desktop socket client (`vNr()`):** Looks specifically for `/tmp/claude-mcp-browser-bridge-{username}/0.sock`. If multiple `.sock` files exist (different PIDs), create a symlink from `0.sock` to the active one.

---

## Known Issue: macOS Quarantine on Socket Directory

**Symptom:** Connection fails despite native host running and socket accepting connections.

**Diagnosis:** Check xattrs on the socket directory:
```bash
xattr -l /tmp/claude-mcp-browser-bridge-$(whoami)/
```
If output shows `com.apple.quarantine: 0081;00000000;Chrome;` → Chrome set a quarantine flag on the directory.

**Note:** In testing, the quarantine attribute did NOT actually prevent socket connections (Python test confirmed socket accepted connections even with quarantine). However it is worth clearing as a precaution:
```bash
xattr -rd com.apple.quarantine /tmp/claude-mcp-browser-bridge-$(whoami)/
```

**Important:** The quarantine attribute is NOT the cause of "No Chrome extension connected after discovery". That error is always an auth issue. Check logs FIRST before attempting socket fixes.

---

## Diagnostic Priority (Lessons from 2026-04-02)

**ALWAYS check logs as Step 2 before attempting ANY fixes:**
```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -i chrome
```

The log pattern determines the correct fix path immediately:
- `connected=true, authenticated=true` + `"No Chrome extension connected after discovery"` → **auth failure → Step 5 only**
- `connected=true` + tool calls fail in ~70ms → **stale socket → Step 2b**
- No chrome entries at all → **Chrome not launched or MCP server not started**

**`tengu_copper_bridge` flag is a red herring for auth failures.** Setting `tengu_copper_bridge: false` in `~/.claude.json` switches from WebSocket bridge to local socket mode, but does NOT fix auth failures. The WebSocket bridge (`wss://bridge.claudeusercontent.com/chrome/{userId}`) is the primary connection path. Only change this flag if the local socket approach is specifically needed.


---

## Known Issue: Corrupt LevelDB (Partial Deletion Leaves Broken MANIFEST)

**Symptom:** Chrome logs show `IO error: FILE_ERROR_ACCESS_DENIED (ChromeMethodBFE: 0::SequentialFileRead::5)` and Chrome cannot write new auth data to the extension's LevelDB.

**Root cause:** If only the `.ldb` and `.log` files are deleted from the extension's LevelDB directory (but `MANIFEST-000001` is left behind), LevelDB becomes permanently corrupt. The MANIFEST references `.ldb` files that no longer exist, causing every write attempt to fail with an access error.

**Diagnosis:**
```bash
cat ~/Library/Application\ Support/Google/Chrome/Profile\ 3/Local\ Extension\ Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn/LOG
```
If output contains `Error recovering version set with 0 records: IO error: ...FILE_ERROR_ACCESS_DENIED` → MANIFEST is corrupt.

**Fix: Delete the ENTIRE directory and let Chrome recreate it (NOT just the .ldb files):**
```bash
# Quit Chrome first!
osascript -e 'tell application "Google Chrome" to quit'; sleep 3

rm -rf "$HOME/Library/Application Support/Google/Chrome/Profile 3/Local Extension Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn"

# Relaunch Chrome — it will recreate a fresh LevelDB automatically
open -a "Google Chrome"
sleep 6

# Confirm fresh LevelDB was created (should see 000003.log file)
ls "$HOME/Library/Application Support/Google/Chrome/Profile 3/Local Extension Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn/"
```

**Profile note:** The LevelDB may be in `Default` or `Profile 3` depending on which Chrome profile has the extension installed. Check both.

---

## Known Issue: "Multiple Chrome Extensions Connected"

**Symptom:** `tabs_context_mcp` returns:
> `"Multiple Chrome extensions connected. Open the Claude extension in the browser you want to use and click 'Connect'."`

**Meaning:** The bridge IS working and the extension IS connected — but multiple Chrome sessions or windows are connected simultaneously. Claude Desktop can't decide which one to use.

**This is NOT a broken connection — it's a disambiguation prompt.**

**Fix:**
1. In Chrome, click the **Claude extension icon** (orange Claude logo in the toolbar)
2. In the popup that appears, click **"Connect"**

This selects the current Chrome window as the active MCP connection. `tabs_context_mcp` should succeed immediately after.

---

## Known Issue: Manual OAuth URL Always Fails (Missing State Parameter)

**Never manually construct the OAuth URL** — it will always fail with "Invalid OAuth Request - Missing state parameter".

The extension's `initiateOAuthFlow()` function generates a cryptographically random `state` and PKCE `code_verifier`/`code_challenge`, stores them in LevelDB, then opens:
```
https://claude.ai/oauth/authorize
  ?client_id=dae2cad8-15c5-43d2-9046-fcaecc135fa4
  &response_type=code
  &scope=user:profile+user:inference+user:chat
  &redirect_uri=chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/oauth_callback.html
  &state=<random_32_chars>
  &code_challenge=<sha256_base64url>
  &code_challenge_method=S256
```

**Note:** Despite the `redirect_uri` referencing `oauth_callback.html`, this file does NOT exist in the extension. Instead, claude.ai's page JavaScript sends the authorization code directly to the extension via:
```javascript
chrome.runtime.sendMessage("fcoeoabgfenejglbffodgkkbkcdhcgfn", {
    type: "oauth_redirect",
    redirect_uri: "chrome-extension://...?code=AUTH_CODE&state=STATE"
})
```

**The correct way to trigger OAuth:** Open `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html` as a Chrome tab — the pairing page's JS calls `initiateOAuthFlow()` automatically when no stored token is found.

---

## Diagnostic Update (2026-04-02, Run 2)

**The complete fix for "no token after LevelDB clear" + "Multiple extensions connected":**

1. Wipe the ENTIRE LevelDB directory (not just `.ldb` files — see Corrupt LevelDB issue above)
2. Quit and restart Chrome (it recreates a fresh LevelDB)
3. Navigate Chrome to `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html` — this triggers OAuth + pairing
4. If `tabs_context_mcp` returns "Multiple Chrome extensions connected" → click **Connect** in the Chrome extension popup
5. Test again — should succeed

