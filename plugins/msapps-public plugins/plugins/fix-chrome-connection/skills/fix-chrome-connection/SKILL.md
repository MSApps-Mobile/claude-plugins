---
name: fix-chrome-connection
description: >
  Use when: tabs_context_mcp fails, Chrome MCP is broken, user says "fix Chrome",
  "reconnect Chrome", "Chrome extension not responding", or after switching Claude Desktop accounts.
  Diagnoses and repairs broken Claude-in-Chrome MCP connections step by step,
  then commits any new learnings to GitHub.
metadata:
  version: "1.0.0"
  author: "MSApps"
---

## Purpose

Diagnose and repair a broken Claude-in-Chrome MCP connection. Work through steps in order, stop as soon as it works.

---

## Step 1: Test current connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

- Returns anything (even "no tab group exists") → Chrome is connected. Go to Step 1b.
- Throws a connection error or times out → note the error, go to Step 2.

### Step 1b: Verify tab group creation

Call `tabs_context_mcp` with `createIfEmpty: true`.

- Succeeds → report success, jump to Self-Reflection.
- Returns **"Tabs can only be moved to and from normal windows"** → run:
  ```bash
  osascript -e 'tell application "Google Chrome" to make new window'
  ```
  Then retry `createIfEmpty: true`. (See Known Issue: "normal windows" error.)

---

## Step 2: Diagnose the failure mode

Check logs first — this determines the correct fix immediately:

```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -iE "chrome|extension|bridge" | grep -v "getSessionsFor\|scheduledTaskId"
```

> **⚠️ Scheduled task log noise:** When `fix-chrome-connection` runs as a scheduled task, `main.log` is flooded with `LocalAgentModeSessions.getSessionsForScheduledTask: scheduledTaskId=fix-chrome-connection` entries — these contain "chrome" so a plain `grep -i chrome` returns only those. Always pipe through `| grep -v getSessionsFor`.

| Log message | Meaning | Go to |
|---|---|---|
| `"No Chrome extension connected after discovery"` + live session | Session mismatch or account switch | Step 3 (session fix) or Step 6 (re-auth) |
| `"No Chrome extension connected after discovery"` + scheduled task | Expected — Chrome can't pair to scheduled sessions | Report status only, use Control_Chrome |
| `connected=true, authenticated=true` + tool calls fail ~70ms | Stale 0.sock symlink | Step 2b |
| `"Chrome extension connected to bridge"` | Bridge connected — may be transient | Retry tabs_context_mcp |
| No Chrome entries at all | Chrome not running | Restart Chrome |

**Quick LevelDB diagnostic (extension bridge status):**
```bash
EXTDIR="$HOME/Library/Application Support/Google/Chrome/Default/Local Extension Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn"
strings "$EXTDIR/"*.ldb "$EXTDIR/"*.log 2>/dev/null | grep -E "mcpConnected|Connected:"
```
> **Note:** LevelDB may have only `.log` (WAL) files when recently compacted — check both extensions.

- `Connected: false`, no `mcpConnected: true` → auth failure → Step 6 (re-auth)
- `mcpConnected: true` → bridge connected before, may be transient or stale socket → Step 2b
- Only `oauthState` key → OAuth started but never completed → Step 6 (re-auth)

**Quick account mismatch check** (do alongside LevelDB check):
```bash
# Bridge userId Claude Desktop is using:
grep "Connecting to bridge:" ~/Library/Logs/Claude/main.log | grep -v "getSessionsFor" | tail -1
# Extension's stored accountUuid:
EXTDIR="$HOME/Library/Application Support/Google/Chrome/Default/Local Extension Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn"
strings "$EXTDIR/"*.ldb "$EXTDIR/"*.log 2>/dev/null | grep -A1 "ountUuid" | head -3
```
If the bridge URL shows `chrome/{UUID-A}` but extension `accountUuid` is `UUID-B` → **account mismatch → Step 6 directly**.

---

## Step 2b: Stale Socket Symlink Fix

**Symptom:** `connected=true, authenticated=true, wsState=1` but every tool call fails in ~70ms.

**Root cause:** Chrome restart creates a new `{pid}.sock` file but doesn't update `0.sock`. Claude Desktop looks specifically for `0.sock`.

```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
ls -la "$DIR/"
NEW_SOCK=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '0.sock' | head -1)
if [ -n "$NEW_SOCK" ]; then
  ln -sf "$NEW_SOCK" "$DIR/0.sock"
  echo "Updated 0.sock → $NEW_SOCK"
else
  echo "No active socket found"
fi
```

Retry `tabs_context_mcp` with `createIfEmpty: false`. Works → jump to Self-Reflection.

---

## Step 3: Session focus fix (live sessions only)

**Root cause:** Chrome extension pairs to whichever Cowork window is in focus when Connect is clicked.

Tell the user:
> "Please focus this Cowork chat window, then click the Claude extension icon in Chrome's toolbar and click **Connect**."

After they confirm:
1. Call `tabs_context_mcp` with `createIfEmpty: false` → if it works → done ✅
2. Also run the 0.sock fix from Step 2b as a safety measure.

---

## Step 4: Reconnect URL (quick trigger for non-account-switch disconnects)

```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://clau.de/chrome/reconnect"'
sleep 5
tail -10 ~/Library/Logs/Claude/main.log | grep -iE "chrome extension|bridge|No Chrome"
```

- `"Chrome extension connected to bridge"` → success! Test with `tabs_context_mcp`.
- Still failing → continue to Step 5.

> If AppleScript returns "Can't get window 1": `osascript -e 'tell application "Google Chrome" to make new window'`

---

## Step 5: Open pairing page

```bash
open -a "Google Chrome" "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html"
```

Wait 3 seconds, retry `tabs_context_mcp`.

If still failing, tell user: **"The pairing page is open in Chrome. Type any name in the input field, then click the orange Connect button."**

> **Note:** The Connect button is disabled until a name is typed. If automating via CDP, use the React native setter — `input.value = "text"` does NOT work with React controlled inputs. Use:
> ```javascript
> let setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
> setter.call(input, 'Claude Desktop');
> input.dispatchEvent(new Event('input', { bubbles: true }));
> ```

---

## Step 6: Manual Re-auth (account switch — the reliable fix)

> ⚠️ Go directly here if logs show `"No Chrome extension connected after discovery"` in a live session and Steps 3–5 don't work. This is the ONLY fix for account switches.

Tell the user:

> **"The Chrome extension needs to re-authenticate with your current Claude Desktop account:"**
> 1. Chrome toolbar → 🧩 → "Claude in Chrome" → sign out
> 2. Sign back in with the **same account as Claude Desktop** (check Claude Desktop's account menu if unsure)
> 3. Authorize the connection when prompted
> 4. When the pairing page appears — type any name → click **Connect**
> 5. Navigate Chrome to **https://claude.ai** (wakes the extension service worker)
> 6. Tell Claude: "done"

After user says done:
```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
NEW=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '/0.sock' | head -1)
[ -n "$NEW" ] && ln -sf "$NEW" "$DIR/0.sock" && echo "Updated" || echo "No socket"
sleep 5
tail -10 ~/Library/Logs/Claude/main.log | grep -iE "chrome extension|bridge"
```

Then call `tabs_context_mcp` with `createIfEmpty: true`. Retry once if it fails immediately.

---

## Step 7: Last resort

Tell the user to open `chrome://extensions`, remove Claude in Chrome, then reinstall from the Chrome Web Store.

---

## Self-Reflection Step (run after EVERY execution)

> "Did I learn anything that would make future runs faster or better?"

If yes:
1. Update relevant files in `~/Documents/claude-plugins/plugins/fix-chrome-connection/`
2. Commit and push:
```bash
cd ~/Documents/claude-plugins
git add plugins/fix-chrome-connection/
git commit -m "fix-chrome-connection: self-improvement $(date '+%Y-%m-%d')"
git pull --rebase origin main && git push origin main
```

If no: state "No new learnings from this run."

---

## Reporting

After each run, output:
- Steps attempted
- Outcome
- What was learned and updated (if anything)

---

## Known Issues

### "Tabs can only be moved to and from normal windows"
Chrome has popup windows open (OAuth/login popups). Fix: `osascript -e 'tell application "Google Chrome" to make new window'`

### Stale 0.sock
Chrome restart creates new `{pid}.sock` but doesn't update `0.sock`. Claude Desktop looks for `0.sock` specifically. Fix: update symlink (Step 2b).

### Native host cycling (start → ~2 min → stop) = account mismatch or auth failure
`chrome-native-host.log` shows the host repeatedly starting (new `.sock`) then stopping ("Chrome disconnected (EOF received)") within ~2 minutes. This means the extension service worker starts, fails to pair on the bridge (userId/auth mismatch), then Chrome suspends the idle service worker (sending EOF). **This is NOT a socket problem** — updating `0.sock` won't help. Repeatedly navigating pages to "wake" the extension just repeats the cycle. Compare bridge URL userId vs extension `accountUuid` (see account mismatch check above) and go to Step 6.

### Account switch — only manual re-auth works
After switching Claude Desktop accounts, the userId changes. The extension connects to the old bridge channel (`wss://bridge.claudeusercontent.com/chrome/{userId}`). Chrome restart and socket fixes don't help. CDP automation doesn't work (debug profile lacks session cookies for OAuth). Only Step 6 (manual re-auth) works.

### Scheduled task sessions — tabs_context_mcp behavior
`tabs_context_mcp` pairs to a specific Cowork `localSessionId` stored in `bridge-state.json`. Scheduled task sessions have their own ID, so:
- `createIfEmpty: false` → returns "No tab group exists for this session" (expected, not an error)
- `createIfEmpty: true` → **CAN succeed** if the socket is healthy, creating a fresh tab group

Use `Control_Chrome` as the primary health check for scheduled tasks (it doesn't require a session pair). After fixing a stale socket, try `tabs_context_mcp` with `createIfEmpty: true` to confirm the extension is fully functional.

### Pairing page — React input
Connect button is disabled until a name is typed. `input.value = "text"` doesn't work with React. Must use the native setter (see Step 5).

### pgrep doesn't find chrome-native-host
`pgrep -l "chrome-native-host"` often returns empty on macOS because the OS truncates process command names to `chrome-na`. To verify the native host is running, use `lsof` on the socket files instead:
```bash
lsof /tmp/claude-mcp-browser-bridge-$(whoami)/*.sock 2>/dev/null | grep chrome-na
```
If it returns `chrome-na` process entries, the native host IS alive. Socket file `mtime` showing a past date is normal — what matters is whether `lsof` shows a live process holding it.

### Corrupt LevelDB
If only `.ldb`/`.log` files were deleted (not the whole directory), LevelDB is permanently corrupt. Fix: delete the ENTIRE directory:
```bash
osascript -e 'tell application "Google Chrome" to quit'; sleep 3
rm -rf "$HOME/Library/Application Support/Google/Chrome/Default/Local Extension Settings/fcoeoabgfenejglbffodgkkbkcdhcgfn"
open -a "Google Chrome"; sleep 6
```

### Multiple Chrome extensions connected
`tabs_context_mcp` returns: "Multiple Chrome extensions connected. Open the Claude extension and click Connect." This is NOT broken — multiple sessions are connected simultaneously. Fix: click the Claude extension icon → **Connect** in the active Chrome window.

### Manual OAuth URL always fails
Never manually construct the OAuth URL — it will fail (missing `state` parameter). The extension generates a random `state`+PKCE pair and stores it in LevelDB. The correct way: open the pairing page (`pairing.html`) — it triggers `initiateOAuthFlow()` automatically.

### macOS quarantine on socket directory
Check: `xattr -l /tmp/claude-mcp-browser-bridge-$(whoami)/`
If `com.apple.quarantine` present: `xattr -rd com.apple.quarantine /tmp/claude-mcp-browser-bridge-$(whoami)/`
Note: quarantine is NOT the cause of "No Chrome extension connected" — that's always an auth issue.
