# Toggl Time Tracker Plugin

Track time and pull reports from Toggl Track, right from Claude. Start timers, stop timers, log hours, and get weekly summaries — all by just asking.

## What you can do

- "Start a timer for client meeting" — starts a running timer in Toggl
- "Stop the timer" — stops whatever's running and shows the duration
- "What am I tracking?" — shows the current running timer
- "Log 2 hours for code review yesterday" — creates a completed time entry
- "Show my time this week" — pulls a weekly summary grouped by project
- "List my projects" — shows active Toggl projects

## Setup (one-time)

1. Get your API token from https://track.toggl.com/profile (scroll to "API Token")
2. Find your workspace ID in the Toggl URL: `https://track.toggl.com/{workspaceId}/timer`
3. Save your config:

```json
// ~/.toggl-config.json
{
  "apiToken": "your-toggl-api-token-here",
  "workspaceId": 1234567
}
```

That's it. Your API token stays on your machine and is never shared.

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install toggl-time-tracker@msapps-plugins
```

**Cowork:** Search for "toggl-time-tracker" in Settings → Plugins.

## Requirements

- A Toggl Track account (free tier works)
- One of the following:
  - **Claude Code** (CLI) — reads config and calls Toggl API directly
  - **Claude Cowork** with Desktop Commander

---

Built by [MSApps](https://msapps.mobi) · Support: michal@msapps.mobi
