---
name: toggl
description: >
  Track time and pull reports from Toggl Track.
  Use this skill whenever the user wants to start a timer, stop a timer, log time,
  check what's running, see time reports, or anything related to time tracking.
  Trigger on phrases like "start timer", "stop timer", "log time", "track time",
  "how much time", "time report", "what am I tracking", "toggl", "timesheet",
  or any mention of time tracking or Toggl.
---

# Toggl Time Tracker

Track time and pull reports via the Toggl Track API.

> **Environment note:** This skill works in both Claude Code and Cowork. The only difference is how the config file is read in Step 1 — Claude Code reads it directly, Cowork uses osascript.

---

## Step 1: Read the config

The config lives on the Mac at `~/.toggl-config.json`.

**In Claude Code** (direct file system access):
```bash
CONFIG=$(cat ~/.toggl-config.json 2>/dev/null || echo "NOT_CONFIGURED")
```

**In Cowork** (VM — needs osascript to reach the Mac home):
```bash
CONFIG=$(osascript -e 'do shell script "cat ~/.toggl-config.json 2>/dev/null || echo NOT_CONFIGURED"')
```

Then parse it safely in Python — **never log or print the raw config or API token**:

```bash
python3 -c "
import json, sys, base64
raw = '''$CONFIG'''
if raw.strip() == 'NOT_CONFIGURED':
    print('STATUS:NOT_CONFIGURED')
    sys.exit(0)
try:
    cfg = json.loads(raw)
    token = cfg['apiToken']
    # Build Basic Auth header: token:api_token base64-encoded
    auth = base64.b64encode(f'{token}:api_token'.encode()).decode()
    print('STATUS:OK')
    print(f'AUTH:Basic {auth}')
    print(f'WORKSPACE:{cfg.get(\"workspaceId\", \"\")}')
except Exception as e:
    print(f'STATUS:PARSE_ERROR:{e}')
"
```

- If `STATUS:NOT_CONFIGURED` → tell the user:
  > "Toggl isn't set up yet. Create `~/.toggl-config.json` with your API token:
  > ```json
  > {
  >   "apiToken": "your-toggl-api-token",
  >   "workspaceId": 1234567
  > }
  > ```
  > Find your API token at https://track.toggl.com/profile (scroll to 'API Token').
  > Find your workspace ID in the URL when logged into Toggl: `https://track.toggl.com/{workspaceId}/timer`."
  Stop here.
- If `STATUS:PARSE_ERROR` → tell the user the config file is malformed.
- If `STATUS:OK` → extract AUTH and WORKSPACE from output. Continue.

**IMPORTANT**: The API token belongs to the user. Never print it, log it, or include it in any output shown to the user.

---

## API Base

All requests go to:
```
https://api.track.toggl.com/api/v9
```

All requests need:
```bash
-H "Authorization: $AUTH" -H "Content-Type: application/json"
```

Where `$AUTH` is the `Basic ...` value from Step 1.

---

## Start a timer

```bash
RESPONSE=$(curl -s -X POST \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"created_with\": \"claude-toggl-plugin\",
    \"description\": \"<what the user is working on>\",
    \"workspace_id\": $WORKSPACE,
    \"start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"duration\": -1,
    \"project_id\": <project_id or null>,
    \"tags\": [<optional tags>]
  }" \
  "https://api.track.toggl.com/api/v9/workspaces/$WORKSPACE/time_entries")
echo "$RESPONSE"
```

- `duration: -1` means the timer is running
- Parse the response for `id` (you'll need it to stop the timer)
- Tell the user: "Timer started: <description>"

---

## Stop the running timer

First, get the current running entry:

```bash
CURRENT=$(curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/me/time_entries/current")
echo "$CURRENT"
```

If `null` → no timer running, tell the user.

If a timer is running, extract its `id` and `workspace_id`, then stop it:

```bash
ENTRY_ID=<id from current>
RESPONSE=$(curl -s -X PATCH \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"stop\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
  "https://api.track.toggl.com/api/v9/workspaces/$WORKSPACE/time_entries/$ENTRY_ID/stop")
echo "$RESPONSE"
```

Parse the response and tell the user:
- What was stopped (description)
- How long it ran (calculate from start/stop)

---

## Check what's currently running

```bash
curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/me/time_entries/current"
```

If `null` → "No timer running."
Otherwise → show description, project, and how long it's been running.

---

## Log a completed time entry

For time already spent (not a running timer):

```bash
curl -s -X POST \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  -d "{
    \"created_with\": \"claude-toggl-plugin\",
    \"description\": \"<description>\",
    \"workspace_id\": $WORKSPACE,
    \"start\": \"<ISO 8601 start time>\",
    \"stop\": \"<ISO 8601 stop time>\",
    \"duration\": <seconds>,
    \"project_id\": <project_id or null>,
    \"tags\": [<optional tags>]
  }" \
  "https://api.track.toggl.com/api/v9/workspaces/$WORKSPACE/time_entries"
```

- Duration must match the difference between start and stop (in seconds)
- Ask the user for the details if not provided

---

## List recent time entries

```bash
# Today's entries
TODAY=$(date -u +%Y-%m-%d)
curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/me/time_entries?start_date=$TODAY&end_date=$TODAY"
```

For a date range:
```bash
curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/me/time_entries?start_date=<YYYY-MM-DD>&end_date=<YYYY-MM-DD>"
```

Format the results as a clean summary:
- Group by project
- Show description, duration (human-readable), and tags
- Show total hours

---

## List projects

```bash
curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/workspaces/$WORKSPACE/projects?active=true"
```

Use this to help the user pick a project when starting a timer.

---

## List workspaces

```bash
curl -s \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  "https://api.track.toggl.com/api/v9/me/workspaces"
```

Use this if the user hasn't set a workspace ID in their config, or needs to switch workspaces.

---

## Weekly summary report

Pull all entries for the current week and summarize:

```bash
python3 -c "
from datetime import datetime, timedelta
today = datetime.utcnow()
monday = today - timedelta(days=today.weekday())
sunday = monday + timedelta(days=6)
print(f'START:{monday.strftime(\"%Y-%m-%d\")}')
print(f'END:{sunday.strftime(\"%Y-%m-%d\")}')
"
```

Then fetch entries for that range and summarize by:
- Total hours this week
- Hours per project
- Hours per day
- Top tags

---

## Error handling

- **401/403**: Auth failed — tell the user to check their API token
- **429**: Rate limited — wait and retry (free tier: 30 req/hour)
- **404**: Resource not found — check workspace ID or entry ID
- Network errors: Report the curl exit code

---

## Notes

- All times are in UTC — convert to the user's local time for display
- API token is at https://track.toggl.com/profile
- Workspace ID is in the Toggl URL: `https://track.toggl.com/{workspaceId}/timer`
- Rate limits: Free=30/hr, Starter=240/hr, Premium=600/hr
- Config at `~/.toggl-config.json`
- The user's API token is NEVER printed or logged
