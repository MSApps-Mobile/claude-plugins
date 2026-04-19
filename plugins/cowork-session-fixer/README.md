# Cowork Session Fixer

**By [MSApps](https://msapps.mobi)**

Fixes the notorious "RPC error: process with name already running" bug that blocks Claude Cowork sessions after a crash or connection drop.

## The Problem

When a Cowork session crashes or loses its VM connection, the background process isn't always cleaned up. The next time you try to use that session — or even send a follow-up message — you get:

```
RPC error: process with name "your-session-name" already running
```

This blocks all work in that session. No UI button exists to clear it. Users resort to rebooting their entire computer.

## The Fix

This plugin adds a skill that Claude can use to diagnose and fix stuck sessions automatically. It uses a 5-tier approach, starting with the gentlest fix and escalating only if needed:

1. **Identify** — Parse the error and find the stuck session
2. **Graceful Cleanup** — Kill the orphaned process through proper channels
3. **Process-Level Kill** — OS-level termination commands (macOS/Windows/Linux)
4. **Cache & State Cleanup** — Remove stale session state files
5. **Full Reset** — Nuclear option: fresh VM image + reboot

## How to Use

Just tell Claude about the error. Any of these will trigger the fix:

- Paste the error message directly
- Say "my cowork session is stuck"
- Say "I'm getting an RPC error"
- Say "process already running error"
- Say "fix my stuck session"

Claude will walk you through the fix step by step, asking permission before any destructive actions.

## Supported Platforms

- macOS (Apple Silicon & Intel)
- Windows 10/11
- Linux

## Known Issues This Fixes

- [#30655](https://github.com/anthropics/claude-code/issues/30655) — Orphaned VM process blocks resume
- [#24483](https://github.com/anthropics/claude-code/issues/24483) — RPC error persists after cleanup
- [#28094](https://github.com/anthropics/claude-code/issues/28094) — Connection errors after crash
- [#25707](https://github.com/anthropics/claude-code/issues/25707) — Task didn't load properly
- [#24190](https://github.com/anthropics/claude-code/issues/24190) — Error on opening session

## Support

- Website: [msapps.mobi](https://msapps.mobi)
- Email: hello@msapps.mobi

