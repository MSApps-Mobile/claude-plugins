# github-cli-health-check

Scheduled health check plugin for the GitHub CLI (`gh`) on MSApps machines.

## What it does

Verifies that `gh` is installed, authenticated, can list repositories, and has sufficient API rate limit remaining. Saves a structured `✅/❌` report to the workspace.

## ⚠️ Important: Desktop Commander Required

All `gh` commands run via `mcp__Desktop_Commander__start_process` — **not** via the `Bash` tool. The Bash tool runs in a sandboxed Linux environment where `gh` is not installed. Desktop Commander runs on the user's real Mac where `gh` is available at `/opt/homebrew/bin/gh`.

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `github-cli-health-check` | Runs the full health check and saves a report |

## Setup

Requires `gh` CLI installed on the host Mac:
```bash
brew install gh
gh auth login
```

No additional MCPs or environment variables are required.

## Usage

Trigger the skill by saying any of:
- "Run a GitHub CLI health check"
- "Check if gh is working"
- "Is GitHub authenticated?"
- "GitHub health check"

Or run it via the scheduled task `github-cli-health-check`.

## Output

A report saved to the workspace as `github-health-check-YYYY-MM-DD.md` with:
- ✅/❌ table for Installation / Authentication / Repo Access / API Rate Limit
- Authenticated account and scopes
- Last 5 repos listed
- Rate limit remaining and reset time
- Warning if rate limit is below 100 requests
