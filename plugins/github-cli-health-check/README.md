# github-cli-health-check

Scheduled health check plugin for the GitHub CLI (`gh`).

## What it does

Verifies that `gh` is installed, authenticated, can list repositories, and has sufficient API rate limit remaining. Saves a structured `✅/❌` report to a dedicated folder outside any git repo (`~/Claude/Scheduled/github-cli-health-check/`).

## Runtime expectation: `gh` in the sandbox VM

All `gh` commands run via the **Bash tool** (the sandbox VM). Having `gh` inside the VM is a required dependency — this is a scheduled task that should run entirely in the sandbox.

If the VM is missing `gh`, a token, or network to `api.github.com`, the skill's auto-fix loop installs / reports what's needed and re-runs. Desktop Commander (against the host machine's `gh`) is an **emergency fallback only**, flagged as an anomaly in the report so the infra gap is visible.

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `github-cli-health-check` | Runs the full health check and saves a report |

## Setup

Inside the sandbox VM you need:

1. `gh` on `$PATH` (the auto-fix loop will install it via apt or tarball if missing — see [gh releases](https://github.com/cli/cli/releases))
2. `GH_TOKEN` env var set to a personal access token with the scopes required by the checks you want to run (see the [gh manual](https://cli.github.com/manual/gh_auth_login) for scope recommendations)
3. Network access to `api.github.com` (if the sandbox proxy blocks it, request allowlisting from your platform)

If you keep a `gh` on the host instead (`brew install gh` / `sudo apt install gh` + `gh auth login`), it's used as an emergency fallback via Desktop Commander.

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
