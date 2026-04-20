# github-cli-health-check

Scheduled health check plugin for the GitHub CLI (`gh`).

## What it does

Verifies that `gh` is installed, authenticated, can list repositories, and has sufficient API rate limit remaining. Saves a structured `✅/❌` report to a dedicated folder outside any git repo (`~/Claude/Scheduled/github-cli-health-check/`).

## ⚠️ Important: Desktop Commander Required

All `gh` commands run via `mcp__Desktop_Commander__start_process` — **not** via the sandbox `Bash` tool. The sandbox usually has GitHub blocked by proxy and has no `gh` installed. Desktop Commander runs on the user's host machine where `gh` is available on `$PATH` (typically `/opt/homebrew/bin/gh` on macOS, `/usr/bin/gh` on Linux).

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `github-cli-health-check` | Runs the full health check and saves a report |

## Setup

Requires `gh` CLI installed on the host machine:
```bash
brew install gh       # macOS
# or: sudo apt install gh   # Debian/Ubuntu
gh auth login
```

`gh auth login` stores the token in the OS keyring — no environment variable needed when running via Desktop Commander. If you prefer env-var auth, set `GH_TOKEN` to a personal access token with the scopes required by the checks you want to run (see the [gh manual](https://cli.github.com/manual/gh_auth_login) for scope recommendations).

## Usage

Trigger the skill by saying any of:
- "Run a GitHub CLI health check"
- "Check if gh is working"
- "Is GitHub authenticated?"
- "GitHub health check"

Or run it via the scheduled task `github-cli-health-check`.

## Output

A report saved to `~/Claude/Scheduled/github-cli-health-check/github-health-check-YYYY-MM-DD.md` (or `~/Documents/Claude/Scheduled/...` if you keep your Claude workspace under Documents). Contains:
- ✅/❌ table for Installation / Authentication / Repo Access / API Rate Limit
- Authenticated account
- Recent-repos count + visibility breakdown
- Rate limit remaining and reset time
- Warning if rate limit is below 100 requests

The report folder is intentionally **outside** any git repo — no risk of accidentally committing the run history.
