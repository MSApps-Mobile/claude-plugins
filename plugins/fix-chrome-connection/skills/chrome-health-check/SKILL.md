---
name: chrome-health-check
description: >
  Quickly checks whether the Claude in Chrome MCP connection is working and reports the status.
  Use when the user says "is chrome connected?", "check chrome", "chrome status", "test chrome
  connection", "is the chrome extension working?", or any variation of wanting to know if Chrome
  is reachable before starting browser-based work. Also use proactively before running Chrome
  automation tasks if there's any doubt the connection is live.
---

# Chrome Connection Health Check

Run a quick connection test and report clearly whether Chrome is available.

## Step 1: Test the connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

**If successful (returns tab info or "no tab group exists"):**
Report: "✅ Chrome is connected and ready."
Optionally list any open tabs in the MCP group.
Stop here.

**If it returns a connection error:**
Report: "❌ Chrome is not connected."
Then ask: "Want me to try to fix it?"
- If yes → trigger the `fix-chrome-connection` skill.
- If no → stop and let the user know they can ask to fix it anytime.

## Keep it brief

This is a status check, not a repair workflow. One tool call, one clear answer.
Don't take any repair actions unless the user explicitly asks.
