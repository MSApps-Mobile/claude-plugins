# github-cli-health-check — Task Notes

## Purpose

Scheduled health check for the GitHub CLI (`gh`) on MSApps machines. Verifies installation, authentication, repo access, and API rate limit. Saves a structured report to the workspace.

## Critical: Tool Selection

**Always use `mcp__Desktop_Commander__start_process` for all `gh` commands.**

The `Bash` tool runs inside a sandboxed Linux container where `gh` is not installed. Desktop Commander executes on the user's real macOS machine where `gh` lives at `/opt/homebrew/bin/gh`.

| Tool | Environment | Has `gh`? |
|------|-------------|-----------|
| `Bash` | Claude sandbox (Linux) | ❌ No |
| `mcp__Desktop_Commander__start_process` | User's Mac | ✅ Yes |

## Commands

```bash
# Check installation
gh --version

# Check auth
gh auth status

# List repos
gh repo list --limit 5

# Rate limit
gh api rate_limit
```

## Output

Report file: `github-health-check-YYYY-MM-DD.md`  
Saved to: `/Users/michalshatz/Documents/Claude/outputs/` (workspace folder)

## Version History

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-03-27 | Initial skill using Bash tool (broken — gh not in sandbox) |
| 0.2.0 | 2026-03-29 | Fixed: switched all gh commands to Desktop Commander |

## Scheduled Task

Configured in Cowork scheduled tasks as `github-cli-health-check`. The task file at `/Users/michalshatz/Documents/Claude/Scheduled/github-cli-health-check/SKILL.md` is the canonical source loaded by the scheduler.
