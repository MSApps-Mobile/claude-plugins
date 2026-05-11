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

## Fix Flow

1. Check `list_connected_browsers`
   - `[]` + Chrome NOT running → `open_application("Google Chrome")`, wait 60s, recheck
   - `[]` + Chrome IS running → auth failure → manual re-auth required (cannot fix autonomously)
2. Reconnect URL: `https://clau.de/chrome/reconnect`
3. Pairing page: `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/pairing.html`
4. Manual re-auth (Step 6 in fix skill) — last resort, requires user interaction

## Outcome C — observed 2026-05-11 (manual restore session)

When `Control_Chrome.get_current_tab` succeeds (Chrome alive) but `tabs_context_mcp` fails with the SDK-level
message `"Claude in Chrome is not connected"` AND `switch_browser` returns `"No other browsers available
to switch to"`, the extension WebSocket is fully offline for this session — and a sandboxed session
(scheduled-task OR manual-restore) CANNOT bring it back. Steps that fail in this state:

- `clau.de/chrome/reconnect` navigation via Control_Chrome.open_url (Chrome navigates but extension can't pair to the unfocused sandbox window)
- `switch_browser` (broadcast has no paired peers to reach)
- All macOS-side fixes (`osascript`, `tail ~/Library/Logs/Claude/main.log`, `ln -sf 0.sock`) — Linux sandbox can't reach the Mac filesystem

Correct handling: classify as Outcome C, write a `health-check-report.md` to the workspace folder, and
exit. The user must click the Claude extension icon → Connect with a Cowork window focused. Looping
beyond ~3 cycles wastes tokens and never converges.

## Known Accounts

| Side | Account |
|------|---------|
| Claude Desktop (correct) | ms.apps@msapps.mobi |
| Chrome extension (correct) | ms.apps@msapps.mobi |
| Chrome extension (OLD/wrong) | msmobileapps@gmail.com |

## Trello Board

**Dedicated board:** https://trello.com/b/hX5om9CS/opsagents-chrome-runner (ID: `69fbf3cb9b01b031ac3ce445`)
Log all health check runs and fixes to the **✅ Done** list on this board.

## Last Run

- Date: 2026-05-11 (manual restore + manual probe — Outcome C)
- Result: ⚠️ Control_Chrome ✅ (9 tabs visible, get_current_tab returned `monday vibe`); extension WebSocket ❌
- Probes tried: tabs_context_mcp(false), tabs_context_mcp(true), switch_browser, Control_Chrome.open_url(clau.de/chrome/reconnect), Control_Chrome.list_tabs, Control_Chrome.get_current_tab
- Plugin freshness: pulled v0.1.20 (commit 64dffa1) — `chrome-devtools-mcp-cleanup` skill is NEW
- Lesson added: Outcome C section above — sandboxed sessions cannot self-repair extension WebSocket
- Trello: TBD (logged via gateway after upstream push)

## Last Run (prior)

- Date: 2026-05-11 (first session)
- Result: 🔇 FIXED — 0.sock absent after Chrome restart → symlink created → Control_Chrome restored
- Root cause: Chrome restarted (PID 97385), created 97385.sock but no 0.sock symlink
- Fix: `ln -sf /tmp/claude-mcp-browser-bridge-michalshatz/97385.sock /tmp/claude-mcp-browser-bridge-michalshatz/0.sock`
- Acceptance: Control_Chrome.get_current_tab → "Example Domain" ✅
- Still stuck: chrome-devtools-mcp stale page ref — resolves on Claude Desktop restart
- Trello: https://trello.com/c/SQ1UBb5V
- Side: azure-client-id + azure-tenant-id populated in GCP Secret Manager (OpsAgents B2Billing)