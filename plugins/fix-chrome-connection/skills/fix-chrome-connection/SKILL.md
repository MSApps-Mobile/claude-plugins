---

## name: fix-chrome-connection description: &gt; Use when: tabs_context_mcp fails, Chrome MCP is broken, user says "fix Chrome", "reconnect Chrome", "Chrome extension not responding", or after switching Claude Desktop accounts. Diagnoses and repairs broken Claude-in-Chrome MCP connections step by step, then commits any new learnings to GitHub. metadata: version: "1.1.1" author: "MSApps"

## Purpose

Diagnose and repair a broken Claude-in-Chrome MCP connection. Work through steps in order, stop as soon as it works.

---

## Step 0: Check Chrome is running (scheduled tasks)

> **⚠️ Scheduled task only:** Before any other step, verify Chrome is actually running. Call `list_connected_browsers`.
>
> **If it returns `[]` and Chrome is NOT running:** Fix: call `open_application("Google Chrome")` via computer-use tools, wait \~60s, then call `list_connected_browsers` again. If 1+ browser appears, Chrome is healthy — proceed to verify with `tabs_context_mcp` with `createIfEmpty: true`. Observed 2026-04-26: Chrome was completely closed; opening it auto-selected the last profile and activated the extension with no manual interaction needed.
>
> **If it returns `[]` and Chrome IS already running** (confirm with `pgrep "Google Chrome"`): This is an **auth failure**, not a closed-Chrome situation. Check `chrome-native-host.log` — if native host processes have been alive for >1 hour with no `"Chrome extension connected to bridge"` in `main.log`, the extension cannot authenticate. Try the reconnect URL (Step 4) and pairing page (Step 5), but if `list_connected_browsers` still returns `[]`, **manual re-auth (Step 6) is required — cannot be resolved autonomously in a scheduled task. Report to the user.** Observed 2026-04-28: Chrome running with native host processes alive since prior day, `0.sock` absent, `list_connected_browsers=[]` — reconnect URL + pairing page did not resolve without user interaction.
---

## Step 1: Test current connection

> **⚠️ Scheduled task note:** If this skill is running as a **scheduled task**, `tabs_context_mcp` will ALWAYS fail (known limitation — scheduled sessions can't pair to the Chrome extension). Skip directly to verifying with `Control_Chrome` (`get_current_tab`). If that works, Chrome is healthy — report success.

Call `tabs_context_mcp` with `createIfEmpty: false`.

- Returns anything (even "no tab group exists") → Chrome is connected. Go to Step 1b.
- Throws a connection error or times out → note the error, go to Step 2.

### Step 1b: Verify tab group creation

Call `tabs_context_mcp` with `createIfEmpty: true`.

- Succeeds → report success, jump to Self-Reflection.

- Returns **"Tabs can only be moved to and from normal windows"** *or* **"Grouping is not supported by tabs in this window"** → run:

  ```bash
  osascript -e 'tell application "Google Chrome" to make new window'
  ```

  Then retry `createIfEmpty: true`. Both errors share the same root cause and fix — even when AppleScript reports every existing window as `mode=normal`, a *fresh* window is still required.

---

## Step 2: Diagnose the failure mode

Check logs first — this determines the correct fix immediately:

```bash
tail -50 ~/Library/Logs/Claude/main.log | grep -iE "chrome|extension|bridge" | grep -v "getSessionsFor\|scheduledTaskId"
```

> **⚠️ Scheduled task log noise:** When `fix-chrome-connection` runs as a scheduled task, `main.log` is flooded with `LocalAgentModeSessions.getSessionsForScheduledTask: scheduledTaskId=fix-chrome-connection` entries — these contain "chrome" so a plain `grep -i chrome` returns only those. Always pipe through `| grep -v getSessionsFor`.

> **✅ Healthy scheduled-task early-exit (added 2026-04-19):** In a scheduled-task session, if the log excerpt cleanly shows the sequence `ensureConnected … connected=true, authenticated=true, wsState=1` → `Already connected and authenticated` → `No extensions connected, waiting up to 10000ms for peer_connected` → `No extensions found after waiting` → `Error calling tool: [Claude in Chrome] No Chrome extension connected after discovery` with \~10s elapsed between the first and last lines, **Chrome is healthy**. This is the documented scheduled-task pairing issue (not a stale socket — stale-socket failures are \~70ms, not 10s). Verify with `Control_Chrome.list_tabs` (should succeed), then **report healthy and exit — do NOT touch** `0.sock`**, do NOT restart Chrome, do NOT re-pair.**

Log messageMeaningGo to`"No Chrome extension connected after discovery"` + live sessionSession mismatch or account switchStep 3 (session fix) or Step 6 (re-auth)`"No Chrome extension connected after discovery"` + scheduled taskExpected — Chrome can't pair to scheduled sessionsReport status only, use Control_Chrome`connected=true, authenticated=true` + tool calls fail \~70msStale 0.sock symlinkStep 2b`"Chrome extension connected to bridge"`Bridge connected — may be transientRetry tabs_context_mcpNo Chrome entries at allChrome not runningStep 0 (open Chrome)

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

**Symptom:** `connected=true, authenticated=true, wsState=1` but every tool call fails in \~70ms.

**Root cause:** Chrome restart creates a new `{pid}.sock` file but doesn't update `0.sock`. Claude Desktop looks specifically for `0.sock`.

> **Note (observed 2026-04-19):** On recent Claude Desktop builds, `0.sock` may be **absent entirely** while the bridge still reports `connected=true, authenticated=true, wsState=1` and live sessions work fine. The absence of `0.sock` by itself is NOT proof of a stale-socket failure — only the **\~70ms tool-call timing** signature is.

```bash
DIR="/tmp/claude-mcp-browser-bridge-$(whoami)"
ls -la "$DIR/"
NEW_SOCK=$(ls -t "$DIR"/*.sock 2>/dev/null | grep -v '/0\.sock$' | head -1)
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

> **Note:** The Connect button is disabled until a name is typed. If automating via CDP, use the React native setter:
>
> ```javascript
> let setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
> setter.call(input, 'Claude Desktop');
> input.dispatchEvent(new Event('input', { bubbles: true }));
> ```

---

## Step 6: Manual Re-auth (account switch — the reliable fix)

> ⚠️ Go directly here if logs show `"No Chrome extension connected after discovery"` in a live session and Steps 3–5 don't work.

Tell the user:

> **"The Chrome extension needs to re-authenticate with your current Claude Desktop account:"**
>
> 1. Chrome toolbar → 🧩 → "Claude in Chrome" → sign out
> 2. Sign back in with the **same account as Claude Desktop**
> 3. Authorize the connection when prompted
> 4. When the pairing page appears — type any name → click **Connect**
> 5. Navigate Chrome to [**https://claude.ai**](https://claude.ai) (wakes the extension service worker)
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

1. Update relevant files in `~/claude-plugins/plugins/fix-chrome-connection/`
2. Commit and push:

```bash
cd ~/claude-plugins
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

### Chrome not running at scheduled task start
When the scheduled task runs and Chrome is completely closed, `list_connected_browsers` returns `[]`. Fix: call `open_application("Google Chrome")` via computer-use — Chrome will auto-select the last-used profile and the extension activates within ~60 seconds. Verify with `list_connected_browsers` (should return 1+ browser) then `tabs_context_mcp` with `createIfEmpty: true`. Observed 2026-04-26: Chrome was completely closed; opening it resolved the issue automatically with no manual interaction needed.

### "Tabs can only be moved to and from normal windows" / "Grouping is not supported by tabs in this window"
Chrome extension tries to put the new MCP tab into a tab-group, but the current windows don't accept grouping. Observed in two forms:
- **"Tabs can only be moved to and from normal windows"** — classic case, Chrome has popup windows open.
- **"Grouping is not supported by tabs in this window"** (observed 2026-04-20) — same root cause, surfaces even when AppleScript reports every window as `normal`.

Fix for both: `osascript -e 'tell application "Google Chrome" to make new window'` — a fresh window reliably accepts grouping. Retry `tabs_context_mcp` with `createIfEmpty: true` immediately after.

### Stale 0.sock
Chrome restart creates new `{pid}.sock` but doesn't update `0.sock`. Claude Desktop looks for `0.sock` specifically. Fix: update symlink (Step 2b).

### Native host cycling (start → ~2 min → stop) = account mismatch or auth failure
`chrome-native-host.log` shows the host repeatedly starting then stopping within ~2 minutes. The extension service worker starts, fails to pair on the bridge (userId/auth mismatch), then Chrome suspends it. **This is NOT a socket problem.** Compare bridge URL userId vs extension `accountUuid` and go to Step 6.

### Account switch — only manual re-auth works
After switching Claude Desktop accounts, the userId changes. Chrome restart and socket fixes don't help. CDP automation doesn't work. Only Step 6 (manual re-auth) works.

### Scheduled task sessions — tabs_context_mcp behavior
`tabs_context_mcp` pairs to a specific Cowork `localSessionId`. Scheduled task sessions have their own ID, so:
- `createIfEmpty: false` → returns "No tab group exists for this session" (expected, not an error)
- `createIfEmpty: true` → **CAN succeed** if the socket is healthy, creating a fresh tab group

Use `Control_Chrome` as the primary health check for scheduled tasks. After fixing a stale socket, try `tabs_context_mcp` with `createIfEmpty: true` to confirm the extension is fully functional.

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
`tabs_context_mcp` returns: "Multiple Chrome extensions connected." Fix: click the Claude extension icon → **Connect** in the active Chrome window.

### Manual OAuth URL always fails
Never manually construct the OAuth URL. Open the pairing page (`pairing.html`) instead — it triggers `initiateOAuthFlow()` automatically.

### Control_Chrome partial functionality when extension is disconnected (observed 2026-05-03)
`mcp__Control_Chrome__list_tabs` and `mcp__Control_Chrome__open_url` succeed and return real data even when `list_connected_browsers` returns `[]` and `tabs_context_mcp` fails. This means Control_Chrome can confirm Chrome is alive and even navigate it to a URL. However, `get_page_content` and `execute_javascript` still fail with "Google Chrome is not running" — this is a known limitation of Control_Chrome's DOM access layer, which requires a deeper bridge that only the Claude-in-Chrome extension provides. Use `list_tabs` as the liveness check; don't trust `get_page_content` errors as evidence Chrome is closed.

**Diagnostic sequence for scheduled tasks:**
1. `tabs_context_mcp(createIfEmpty: false)` → if fails, don't panic
2. `Control_Chrome.list_tabs` → if returns tabs, Chrome IS alive
3. Take computer-use screenshot (Chrome = read tier) → visual confirmation
4. Report Chrome alive but extension unpaired → ask user to click Connect

### chrome-devtools MCP is a separate server from Claude-in-Chrome (observed 2026-05-03)
The `/chrome-devtools` skill uses a completely different MCP server (`chrome-devtools-mcp`) with its own tools: `new_page`, `take_snapshot`, `navigate_page`, `evaluate_script`, `lighthouse_audit`, etc. These tools are **not** in the same namespace as `mcp__Claude_in_Chrome__*`. If `chrome-devtools-mcp` isn't running, none of its tools will appear in ToolSearch results at all — the entire server is absent from the deferred tool list. Do not confuse the two:
- **Claude-in-Chrome** (`mcp__Claude_in_Chrome__*`): extension-based, requires pairing
- **chrome-devtools-mcp** (`new_page`, `take_snapshot`, etc.): DevTools Protocol server, runs separately

Both can be down independently. Check ToolSearch for `new_page` to confirm whether chrome-devtools-mcp is connected.

### Control_Chrome partial functionality when extension is disconnected (observed 2026-05-03)
`mcp__Control_Chrome__list_tabs` and `mcp__Control_Chrome__open_url` succeed and return real data even when `list_connected_browsers` returns `[]` and `tabs_context_mcp` fails. Use `list_tabs` as the Chrome liveness check. However, `get_page_content` and `execute_javascript` still fail with "Google Chrome is not running" — known limitation of Control_Chrome's DOM layer; does NOT mean Chrome is closed.

**Scheduled task diagnostic sequence:**
1. `tabs_context_mcp(createIfEmpty: false)` → if fails, don't panic
2. `Control_Chrome.list_tabs` → if returns tabs, Chrome IS alive, extension just unpaired
3. Computer-use screenshot (Chrome = read tier) → visual confirmation
4. Report Chrome alive but extension unpaired → ask user to click Connect

### chrome-devtools MCP is a completely separate server from Claude-in-Chrome (observed 2026-05-03)
The `/chrome-devtools` skill uses a separate MCP server (`chrome-devtools-mcp`) with tools `new_page`, `take_snapshot`, `navigate_page`, `evaluate_script`, `lighthouse_audit`, etc. These are NOT in the `mcp__Claude_in_Chrome__*` namespace. If `chrome-devtools-mcp` isn't running, none of its tools appear in ToolSearch at all. Both can be down independently:
- **Claude-in-Chrome** (`mcp__Claude_in_Chrome__*`): extension-based, requires pairing
- **chrome-devtools-mcp** (`new_page`, `take_snapshot`, etc.): DevTools Protocol server, separate process

Check ToolSearch for `new_page` to confirm whether chrome-devtools-mcp is connected.

### macOS quarantine on socket directory
Check: `xattr -l /tmp/claude-mcp-browser-bridge-$(whoami)/`
If `com.apple.quarantine` present: `xattr -rd com.apple.quarantine /tmp/claude-mcp-browser-bridge-$(whoami)/`
Note: quarantine is NOT the cause of "No Chrome extension connected" — that's always an auth issue.

### Chrome running but list_connected_browsers=[] — two distinct causes

When `list_connected_browsers` returns `[]` but Chrome IS running (native host process alive in `/tmp/claude-mcp-browser-bridge-{user}/`), there are **two different root causes** with different fixes:

**Case A: Suspended service worker (fixable without user)**
- LevelDB has `mcpConnected` AND account UUIDs match (bridge URL user == extension `accountUuid`)
- `chrome-native-host.log` shows host started but no subsequent "Chrome disconnected" — it's just idle
- Fix: navigate Chrome to reconnect URL, then apply 0.sock fix if missing:
  ```bash
  osascript -e 'tell application "Google Chrome" to set URL of active tab of front window to "https://clau.de/chrome/reconnect"'
  sleep 6
  tail -5 ~/Library/Logs/Claude/main.log | grep -i "Chrome extension connected"
  ```
  Then check/fix 0.sock symlink (Step 2b). Verify with `list_connected_browsers` — should return browser within ~10 seconds.
  Observed 2026-04-29: reconnect URL woke the suspended service worker, restoring connection with no manual action.

**Case B: Auth failure (requires Step 6 / manual re-auth)**
- LevelDB does NOT have `mcpConnected`, OR only `oauthState` present, OR account UUIDs MISMATCH
- Reconnect URL and pairing page don't resolve it
- `chrome-native-host.log` shows repeated start/stop cycles (~2 min apart)
- Native host sockets present for >1 hour, no `"Chrome extension connected to bridge"` in `main.log`
- **Step 6 (manual re-auth) is required**. Cannot be fixed in a scheduled task. Observed 2026-04-28.

**Diagnosis order:** Always check LevelDB + account UUID match BEFORE concluding Step 6 is needed.

### pgrep truncation on macOS — use lsof instead
On macOS, `pgrep "chrome-native-host"` returns nothing because pgrep matches the truncated process name `chrome-na` (15-char limit). To verify the native host is alive, use lsof on the socket files instead:
```bash
lsof /tmp/claude-mcp-browser-bridge-$(whoami)/*.sock 2>/dev/null | tail +2
```
Socket mtime showing a past date is normal if the native host hasn't been restarted — it doesn't mean the host is dead. Observed 2026-04-28.

### tabs_context_mcp "No tab group exists for this session" = healthy
In a scheduled-task session, calling `tabs_context_mcp` with `createIfEmpty: false` returns the literal string `"No tab group exists for this session. Use createIfEmpty: true to create one."` — this is the **healthy response**, not an error. The bridge is alive and reachable; there's simply no MCP tab group attached to this session yet. Stop the loop and report success. Confirmed 2026-04-29.

