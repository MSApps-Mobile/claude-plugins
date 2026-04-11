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

## Architecture (fully reverse-engineered 2026-04-11)

The Claude in Chrome connection uses a 3-layer bridge:

```
Chrome Extension
      ↕ (stdin/stdout native messaging)
chrome-native-host (binary at /Applications/Claude.app/Contents/Helpers/chrome-native-host)
      ↕ (Unix socket at /tmp/claude-mcp-browser-bridge-{user}/{pid}.sock)
Claude App MCP server
      ↕ (WebSocket wsState, connects to Anthropic's Cowork servers)
Cowork Session
```

- The native host creates the socket and waits for the Claude app to connect to it
- The Claude app does "discovery" by scanning the socket directory
- When a match is found, the native host notifies Chrome: "MCP connected"

## Root Cause (critical — 2026-04-11)

**Chrome extension pairing is SESSION-SPECIFIC.**

- `bridge-state.json` (`~/Library/Application Support/Claude/bridge-state.json`) stores the pairing between a Chrome extension instance and a specific Cowork `localSessionId`
- The Chrome extension pairs to whichever Cowork session is ACTIVE when the user clicks Connect
- **Scheduled task sessions have their own session ID** — Chrome cannot pair to them because there is no user-facing window to click Connect in
- `tabs_context_mcp` will ALWAYS fail in scheduled task sessions — this is by design

## Key Learnings

- **Control_Chrome (CDP) ≠ Claude_in_Chrome (MCP extension)** — two separate connections
  - `Control_Chrome` uses Chrome DevTools Protocol — works as long as Chrome is open
  - `Claude_in_Chrome` uses the Claude desktop extension WebSocket bridge — requires session pairing
- **Chrome restart does NOT auto-reconnect** — after restart, user must click Connect in the active Cowork session window
- **Programmatic fix is impossible for session mismatch** — no bash command can re-pair Chrome to a different session
- **Diagnostic triage:**
  1. `tabs_context_mcp` fails → check `Control_Chrome list_tabs`
  2. If `Control_Chrome` fails → Chrome not running → `pkill -a "Google Chrome" && sleep 3 && open -a "Google Chrome"`
  3. If `Control_Chrome` works but `tabs_context_mcp` fails → extension disconnected OR session mismatch
  4. Check `~/Library/Logs/Claude/main.log` for `[Claude in Chrome] No Chrome extension connected after discovery`
  5. If that error appears → user must click Connect in the correct Cowork session window

## Best Practices

- **Claude-in-Chrome tools only work in live Cowork sessions** — not in scheduled task runs
- **Health checks for Chrome should use `Control_Chrome`** — it works in scheduled tasks and doesn't require pairing
- **To verify Claude-in-Chrome is working**: ask user to open a Cowork chat, click Connect in Chrome, then run the check
- **Bash restart** useful only when native host is crashed — `pkill -a "Google Chrome" && sleep 3 && open -a "Google Chrome"`
- **Works after system sleep** — connection breaks after macOS sleep/wake; run check after waking
