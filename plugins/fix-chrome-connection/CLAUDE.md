# Fix Chrome Connection

**Impact Level:** Low (diagnostic, read-only operations)
**Role:** Detect and repair broken Chrome extension connections for Claude-in-Chrome MCP.

Diagnose and repair broken Claude in Chrome MCP connections. Resolves issues when Claude extension loses communication with Claude Code server.

## Available Tools/Skills

- **fix-chrome-connection** - Full repair workflow: diagnose issue, restart Chrome service, verify connection
- **chrome-health-check** - Quick status check without repairs (safe to run anytime)

## Configuration

- **Platform**: macOS only (uses bash commands to quit/restart Chrome)
- **Required**: Google Chrome installed, Claude in Chrome extension
- **Server**: Local bash commands

## Common Workflows

1. **Fix Broken Connection**
   - Trigger: User says "fix chrome", "chrome not connecting", or "is chrome connected?"
   - Tool runs: Diagnose → quit Chrome → restart → verify
   - Result: Connection restored, ready to use

2. **Quick Status Check**
   - Run chrome-health-check anytime
   - Returns: "Connected", "Disconnected", or error details
   - Safe to run repeatedly without side effects

3. **Scheduled Daily Check**
   - Configure daily task: chrome-health-check every morning
   - Proactively catch stale connections before user notices
   - Optional: Auto-repair if unhealthy

## Root Cause

macOS user switches cause Chrome extension service worker to go stale. Extension remains loaded but loses server connection.

## Key Learnings (2026-04-11)

- **Control_Chrome (CDP) ≠ Claude_in_Chrome (MCP extension)** — these are two separate connections.
  - `Control_Chrome` uses Chrome DevTools Protocol — works as long as Chrome is open.
  - `Claude_in_Chrome` uses the Claude desktop extension WebSocket — requires user to click Connect.
- **Chrome restart does NOT auto-reconnect** — even after `pkill + open`, the extension does not reconnect automatically. User must click the Claude extension icon → Connect.
- **Programmatic fix has limits** — bash restart helps when the extension service worker is fully stale/crashed, but cannot substitute for the manual Connect click in the popup.
- **Diagnostic triage:**
  1. `tabs_context_mcp` fails → check `Control_Chrome list_tabs`
  2. If `Control_Chrome` fails → Chrome not running → restart Chrome
  3. If `Control_Chrome` works → Chrome open, but extension disconnected → user must click Connect

## Best Practices

- **Bash restart clears stale service workers** — use `pkill -a "Google Chrome" && sleep 3 && open -a "Google Chrome"` then wait 10s
- **After restart, user must click Connect** — the extension popup requires a manual click; this cannot be automated
- **Schedule proactively** - Run daily health checks to catch issues early
- **Requires Chrome to be running** - Plugin cannot fix if Chrome is closed
- **Safe for repeated use** - Health checks have no side effects
- **Works after system sleep** - Connection often breaks after macOS sleep/wake; run check after waking
- **Logs available** - Check console logs if repair doesn't work
