# Cowork Session Fixer — Plugin Context

## What This Plugin Does
Fixes the "RPC error: process with name already running" bug in Claude Cowork. When a session crashes or loses its VM connection, the orphaned process blocks all future work in that session. This plugin detects and clears the stuck process using a 5-tier escalation strategy.

## Plugin Structure
- `.claude-plugin/plugin.json` — Plugin metadata (name, version, author)
- `skills/fix-stuck-session/SKILL.md` — Core skill with the 5-tier fix procedure
- `skills/fix-stuck-session/references/error-patterns.md` — Detailed error catalog with regex patterns and OS-specific notes
- `README.md` — User-facing documentation

## Key Technical Details
- **Skill trigger:** Any mention of "RPC error", "process already running", "stuck session", "task didn't load"
- **5 Fix Tiers:** Identify → Graceful Cleanup → OS-Level Kill → Cache Cleanup → Full Reset
- **Platforms:** macOS, Windows, Linux
- **Error categories:** Orphaned process, missing session directory, connection aborted, daemon disconnected, generic load failure

## GitHub Issues Addressed
- #30655, #24483, #28094, #25707, #24190 on anthropics/claude-code

## Distribution
- Free plugin on Gumroad and Anthropic marketplace
- Part of the MSApps Claude Plugins collection
