# chrome-connections-health-check — Task Instructions

copy instruction to task as CLAUDE.md on every run /opsagents-md-composer

1. /fix-chrome-connection:chrome-health-check  - if healthy done 
   1. if came back from fixing and fix succeeded:
      1. update both skills locally
      2. update https://github.com/MSApps-Mobile/claude-plugins/tree/main/plugins/fix-chrome-connection
2. /fix-chrome-connection:fix-chrome-connection  - than go back to 1

dont stop until fixed (cap at 3 cycles in sandboxed sessions — see Outcome C below)

---

## Health Check Protocol (Scheduled Task)

- `tabs_context_mcp` ALWAYS fails in scheduled tasks — expected, NOT an error
- `list_connected_browsers` returning `[]` in a scheduled task — also expected (auth pairing limitation)
- **True health check for scheduled tasks:** use `Control_Chrome.get_current_tab`
  - Returns valid tab data → Chrome is healthy ✅
  - Fails → Chrome not responding → proceed with fix flow

> NOTE (observed 2026-05-23): In some scheduled task sessions, `list_connected_browsers` returns the connected browser AND `tabs_context_mcp(createIfEmpty:true)` actually succeeds and creates a
> tab group. This appears to depend on whether Chrome's cloud bridge is active vs. the local socket.
> When socket dir `/tmp/claude-mcp-browser-bridge-{user}/` is absent, the cloud bridge is used and
> MCP tools CAN work in scheduled sessions. Treat a successful `tabs_context_mcp` as a healthy signal.

## Account-mismatch diagnostic (NEW 2026-05-11 — definitive fix in sandbox)

When `tabs_context_mcp` fails with `"Claude in Chrome is not connected"` AND `switch_browser` returns
`"No other browsers available to switch to"` AND `Control_Chrome.get_current_tab` succeeds, do NOT
classify as Outcome C yet — first rule out an account mismatch. From a sandbox (no macOS shell needed):

1. `Control_Chrome.open_url("chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html")`.
2. `Control_Chrome.get_page_content(tab_id)`. The first two lines of the returned text are:
   `Claude in Chrome settings\n{email}` — `{email}` is the extension's logged-in account.
3. Compare it to the Cowork session's user email (in the task user info block at the top of the prompt).
4. **Mismatch** → tell the user: "The extension is logged in as `{ext_email}` but this Cowork session
   is `{session_email}`. The bridge WebSocket is namespaced per user UUID, so they can never pair.
   Log out on the extension Options page, sign Claude.ai into `{session_email}` (magic link), then
   click Log in on the extension Options page." After re-auth, run
   `Control_Chrome.open_url("https://clau.de/chrome/reconnect")` then `tabs_context_mcp(createIfEmpty: true)` — should succeed.
5. **Match** → real Outcome C (focus pairing or stale `0.sock`).

Real-world fix logged 2026-05-11: extension was `michal@msapps.mobi`, session was `info@msapps.mobi`.
User re-authed extension. Pairing succeeded on first retry — `tabGroupId 523665234`, `tabId 1618993344`.

## Fix Flow

1. Check `list_connected_browsers`
   - `[]` + Chrome NOT running → `open_application("Google Chrome")`, wait 60s, recheck
   - `[]` + Chrome IS running → auth failure → run the account-mismatch diagnostic above
2. Reconnect URL: `https://clau.de/chrome/reconnect`
3. Pairing page: `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html`
4. Manual re-auth (Step 6 in fix skill) — last resort, requires user interaction

## Outcome C — session pairing failure (sandboxed sessions)

When the account-mismatch diagnostic shows accounts MATCH but pairing still fails,
conclude Outcome C (sandboxed session can't fix it). Needs user action.

## Known Accounts

| Side | Account |
|------|---------|
| Cowork session (live) | varies per session — read from task user info block |
| Chrome extension (correct) | match the Cowork session email |
| Previously seen (wrong) | michal@msapps.mobi, msmobileapps@gmail.com, ms.apps@msapps.mobi |

## Trello Board

**Dedicated board:** https://trello.com/b/hX5om9CS/opsagents-chrome-runner (ID: c69fbf3cb9b01b031ac3ce445)
Log all health check runs and fixes to the **✅ Done** list on this board.

## Last Run

- Date: 2026-05-23
- Result: ✅ HEALTHY -- no fix needed
- Diagnostic: `list_connected_browsers` → 1 browser (deviceId: ec456ec2-7370-4922-a473-a221cb51a5bc, isLocal: true)
- Socket: socket dir `/tmp/claude-mcp-browser-bridge-$(whoami)/` NOT present -- cloud bridge in use
- `tabs_context_mcp(createIfEmpty:false)` → "No tab group exists" (Chrome connected)
- `tabs_context_mcp(createIfEmpty:true)` → SUCCESS -- tabGroupId 202217902, tabId 1833342161
- New learning: MCP tools CAN work in scheduled sessions when cloud bridge is active (no local socket)
- No fix applied

## Last Run (prior)

- Date: 2026-05-20
- Result: ✅ HEALTHY - no fix needed
- Diagnostic: `list_connected_browsers` → 1 browser (deviceId :ec456ec2-7370-4922-a473-a221cb51a5bc)
- Socket: `0.sock → 23415.sock` (symlink current), native host `chrome-na` PID 23415 alive
- Log pattern: `connected=true, authenticated=true, wsState=1` → 10s wait → healthy scheduled-task exit
- LevelDB: `mcpConnected` present — bridge was paired
- `tabs_context_mcp(createIfEmpty:true)` → expected failure (scheduled task session — pairing not possible)
- No fix applied, no new learnings