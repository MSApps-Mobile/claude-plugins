---
name: close-inactive-chrome-tabs
description: >
  Automatically identifies and closes stale/inactive tabs in the Claude-in-Chrome MCP tab group.
  Use this skill whenever Claude needs to clean up leftover browser tabs from previous automation runs.
  Triggers on: "close old tabs", "clean up chrome tabs", "close inactive tabs", "tab cleanup",
  or any request to tidy up the browser between sessions.
---

# Close Inactive Chrome Tabs

Your job is to clean up the MCP Chrome tab group by closing tabs that are no longer needed.
This runs hourly as a background housekeeping task.

## What "inactive" means here

The Claude-in-Chrome MCP tool manages a group of tabs it creates during automation runs.
Over time, completed runs leave tabs open — these are the ones to close.

A tab is considered **inactive / safe to close** if:
- It belongs to the MCP tab group (verified via `tabs_context_mcp`)
- It is **not** the tab currently being used in this run (i.e. not the one you just created or are actively working in)

A tab is **safe to keep** if:
- It is the only tab in the group (closing it would destroy the group — let Chrome clean that up naturally)
- You have reason to believe it is part of an in-progress task (rare in a scheduled run)

## Steps

1. **Get the current tab group state**
   Call `tabs_context_mcp` (with `createIfEmpty: false`) to list all tab IDs in the MCP group.
   If the result is empty or there is no group, log "No MCP tab group found — nothing to close." and exit cleanly.

2. **Decide what to close**
   - If there is only 1 tab: nothing to do, log "Only one tab in group — skipping." and exit.
   - If there are 2+ tabs: close all tabs **except the last one** (keep one alive so the group persists for future runs).

   The reasoning: tabs are appended as sessions run. Older tab IDs (lower numbers) are from earlier runs. Close everything except the most recent tab.

3. **Close the inactive tabs**
   For each tab selected for closure, call `tabs_close_mcp` with its tab ID.
   Log each closure: `Closed tab {id}`.

4. **Report**
   Summarise the result:
   - How many tabs were found
   - How many were closed
   - How many remain

## Error handling

- If `tabs_close_mcp` fails for a tab (e.g. already closed), log the error and continue with the rest.
- Never throw or abort — this is a cleanup task and partial success is fine.

## Example output

```
Tab cleanup complete.
Found: 5 tabs in MCP group
Closed: 4 tabs (IDs: 101, 102, 103, 104)
Remaining: 1 tab (ID: 105)
```
