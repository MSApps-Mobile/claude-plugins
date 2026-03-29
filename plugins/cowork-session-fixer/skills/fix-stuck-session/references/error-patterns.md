# Error Patterns & Session State Schema

## Session State File Location

**macOS:**
```
~/Library/Application Support/Claude/local-agent-mode-sessions/<org-id>/<user-id>/local_<session-uuid>.json
```

**Windows:**
```
%APPDATA%\Claude\local-agent-mode-sessions\<org-id>\<user-id>\local_<session-uuid>.json
```

## Key Fields in Session JSON

| Field | Type | Description |
|-------|------|-------------|
| sessionId | string | `local_<uuid>` format |
| processName | string | Auto-generated name like "busy-wizardly-mccarthy" |
| vmProcessName | string | Usually same as processName |
| cwd | string | `/sessions/<processName>` |
| isArchived | boolean | When true, session is inactive |
| error | string | Error message if session failed |
| title | string | User-visible session title |
## How to Find Stuck Sessions

**macOS (fastest):**
```bash
mdfind -onlyin ~/Library/Application\ Support/Claude "RPC error"
```

**Cross-platform (Python):**
```python
import json, glob, os
base = os.path.expanduser("~/Library/Application Support/Claude/local-agent-mode-sessions")
for f in glob.glob(f"{base}/*/*/local_*.json"):
    data = json.load(open(f))
    if not data.get("isArchived") and data.get("error", "").find("already running") >= 0:
        print(f"STUCK: {data['processName']} — {data.get('title', 'untitled')}")
        print(f"  File: {f}")
```

## Error Variants Map

| Error message pattern | Root cause | Best fix tier |
|----------------------|------------|--------------|
| process with name "X" already running | Orphaned state file | Tier 2 (archive JSON) |
| ensure user: user X should already exist | Missing session dir | Tier 5 (cache cleanup) |
| failed to write stdin / connection aborted | VM connection dropped | Tier 3 (process kill) |
| sdk-daemon not connected | Daemon crash | Tier 4 (process-level kill) |
| Task didn't load properly | Generic session failure | Tier 2 first, then escalate |
| onQuitCleanup timed out | Shutdown race condition | Tier 4 (process-level kill) |