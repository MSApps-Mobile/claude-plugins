# chrome-connections-health-check — Task Instructions

copy instruction to task as CLAUDE.md on every run /opsagents-md-composer

1. /fix-chrome-connection:chrome-health-check  - if healthy done 
   1. if came back from fixing and fix succeeded:
      1. update both skills locally
      2. update https://github.com/MSApps-Mobile/claude-plugins/tree/main/plugins/fix-chrome-connection
2. /fix-chrome-connection:fix-chrome-connection  - than go back to 1

dont stop until fixed

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

## Known Accounts

| Side | Account |
|------|---------|
| Claude Desktop (correct) | ms.apps@msapps.mobi |
| Chrome extension (correct) | ms.apps@msapps.mobi |
| Chrome extension (OLD/wrong) | msmobileapps@gmail.com |

## Last Run

- Date: 2026-05-10
- Result: ✅ HEALTHY — chrome-devtools-mcp list_pages returned 2 pages; smoke test passed
- Pages open: about:blank, https://cli-gateway-zadkrinzra-ey.a.run.app/health
- Smoke test: example.com loaded 200 OK, "Example Domain" found, no critical errors
- Note: 1 console error (404 on non-critical resource, likely favicon) — page fully functional
- Method: chrome-devtools-mcp (not Control_Chrome bridge)
