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

## Outcome C — observed 2026-05-11 (manual restore session)

ONLY conclude Outcome C after the account-mismatch diagnostic above has matched. The signature is:
extension email matches Cowork session email, but pairing still doesn't take. Sandboxed sessions
cannot fix this — needs the user to focus a Cowork window then click Connect, or the macOS
`0.sock` symlink fix.

Steps that fail in this state:
- `clau.de/chrome/reconnect` navigation via Control_Chrome.open_url
- `switch_browser` (broadcast has no paired peers)
- macOS-side fixes (`osascript`, `tail ~/Library/Logs/Claude/main.log`, `ln -sf 0.sock`) — Linux sandbox can't reach the Mac filesystem

Correct handling: write `health-check-report.md` to the workspace and exit. Looping beyond ~3 cycles wastes tokens.

## Known Accounts

| Side | Account |
|------|---------|
| Cowork session (live) | varies per session — read from task user info block |
| Chrome extension (correct) | match the Cowork session email |
| Previously seen (wrong) | michal@msapps.mobi, msmobileapps@gmail.com, ms.apps@msapps.mobi |

## Trello Board

**Dedicated board:** https://trello.com/b/hX5om9CS/opsagents-chrome-runner (ID: `69fbf3cb9b01b031ac3ce445`)
Log all health check runs and fixes to the **✅ Done** list on this board.

## Last Run

- Date: 2026-05-11 (account-mismatch fix)
- Result: ✅ FIXED — extension re-authed from `michal@msapps.mobi` to `info@msapps.mobi`
- Diagnostic that found it: `Control_Chrome.get_page_content` on the extension Options page (`chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html`) returned the extension's logged-in email at line 2 of the page text
- Acceptance: `tabs_context_mcp(createIfEmpty:true)` returned `tabGroupId 523665234`, `tabId 1618993344`
- Lesson added: account-mismatch diagnostic above — sandbox sessions can now check the extension email without macOS shell access
- Trello: https://trello.com/c/4AEFBiHk

## Last Run (prior)

- Date: 2026-05-11 (first session)
- Result: 🔇 FIXED — 0.sock absent after Chrome restart → symlink created → Control_Chrome restored
- Root cause: Chrome restarted (PID 97385), created 97385.sock but no 0.sock symlink
- Fix: `ln -sf /tmp/claude-mcp-browser-bridge-michalshatz/97385.sock /tmp/claude-mcp-browser-bridge-michalshatz/0.sock`
- Trello: https://trello.com/c/SQ1UBb5V
