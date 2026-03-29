---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check — verify authentication, list repos, and check API rate limit.
  Use this skill when the user says "GitHub health check", "check gh CLI", "is GitHub working",
  "gh auth check", "check my GitHub", "GitHub CLI health check", "test gh", "verify GitHub access",
  or any request to verify that the GitHub CLI is authenticated and operational.
  Also triggered by the scheduled task named "github-cli-health-check".
metadata:
  version: "0.2.0"
  author: "MSApps"
---

Run a GitHub CLI (gh) health check. All `gh` commands MUST be run via `mcp__Desktop_Commander__start_process` — NOT via the Bash tool. The Bash tool runs inside a sandboxed Linux environment where `gh` is not installed. Desktop Commander runs on the user's real Mac where `gh` is available at `/opt/homebrew/bin/gh`.

## Step 1 — Verify gh is installed

Run via `mcp__Desktop_Commander__start_process`:
```
gh --version
```

If exit code is non-zero or output is empty, mark Installation as ❌ and skip all remaining steps.

## Step 2 — Check authentication

Run via `mcp__Desktop_Commander__start_process`:
```
gh auth status
```

Parse the output to determine:
- Which GitHub account is authenticated
- What scopes/permissions are available
- Whether the token is valid or expired

If auth fails, mark Auth as ❌ and skip remaining steps.

## Step 3 — List repositories (quick access test)

Run via `mcp__Desktop_Commander__start_process`:
```
gh repo list --limit 5
```

This verifies read access to the GitHub API. Record the repo names returned.
If the call fails, mark Repos as ❌.

## Step 4 — Check API rate limit

Run via `mcp__Desktop_Commander__start_process`:
```
gh api rate_limit
```

Parse the JSON output and extract:
- `resources.core.limit` — total allowed requests
- `resources.core.remaining` — requests left
- `resources.core.reset` — reset timestamp (convert to human-readable)

If remaining is below 100, flag it as a warning. If the call fails, mark Rate Limit as ❌.

## Step 5 — Save report

Save a markdown report to the workspace folder as `github-health-check-YYYY-MM-DD.md` with this structure:

```
# GitHub CLI Health Check — YYYY-MM-DD HH:MM

## Summary Table

| Check | Status |
|-------|:------:|
| Installation | ✅/❌ |
| Authentication | ✅/❌ |
| Repo Access | ✅/❌ |
| API Rate Limit | ✅/❌ |

## Details

### Authentication
- Account: <username>
- Scopes: <scopes>
- Token status: valid / expired

### Recent Repos (last 5)
1. owner/repo-name
...

### API Rate Limit
- Limit: X / hr
- Remaining: X
- Resets at: HH:MM
- ⚠️ Warning: rate limit low (if applicable)

## Notes
- Any issues, anomalies, or observations
```

Present the summary to the user after saving the report.

## Autonomy rules

- Run gh commands: ✅ always allowed (read-only)
- Save report to workspace: ✅ always allowed
- Modify any GitHub config or push any changes: ❌ never without user confirmation
