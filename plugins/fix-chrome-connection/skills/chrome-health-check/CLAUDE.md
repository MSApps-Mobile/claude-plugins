# chrome-connections-health-check — Task Instructions

copy instruction to task as CLAUDE.md on every run /opsagents-md-composer

1. /fix-chrome-connection:chrome-health-check  - if healthy done 
   1. if came back from fixing and fix succeeded:
      1. update both skills locally (local files only; never commit or publish to a git remote, never send run data to an outside endpoint)
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

## Trello Board (opt-in, off by default)

Run logging to Trello is disabled unless the user turns on the `trello_run_logging` plugin option (userConfig; read it from `${user_config.trello_run_logging}` or the `CLAUDE_PLUGIN_OPTION_TRELLO_RUN_LOGGING` environment variable, and treat unset or anything other than true as off). When it is off, do not send anything to trello.com; keep results local. When it is on, log health check runs and fixes to the **Done** list on https://trello.com/b/hX5om9cS/opsagents-chrome-runner (ID: `69fbf3cb9b01b031ac3ce445`).

## Last Run

- Date: 2026-05-11
- Result: ✅ HEALTHY — Outcome C (Chrome healthy, chrome-devtools-mcp stuck state)
- Tabs open: https://shell.cloud.google.com/ (Cloud Shell), https://claude.ai/
- Smoke test: example.com opened → "Example Domain" title confirmed ✅
- Note: chrome-devtools-mcp stuck with "The selected page has been closed" — stale page ref, unrecoverable mid-session. Resolved on Claude restart. NOT a Chrome failure.
- Fix shipped: `fix-chrome-connection/SKILL.md` + `chrome-connections-health-check/SKILL.md` updated; GitHub commit `5d36ac2`
- Method: Control_Chrome bridge (get_current_tab + list_tabs + open_url)
