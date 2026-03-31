# github-cli-health-check — Task Notes

## Purpose

Scheduled health check for the GitHub CLI (`gh`) on MSApps machines. Verifies installation, authentication, repo access, and API rate limit. Saves a structured report to the workspace.

## Critical: Tool Selection

**Always use the Bash tool for all `gh` commands.**

The Bash tool runs inside the Claude sandbox (Linux). `gh` is NOT pre-installed there — it must be downloaded at runtime (see auto-fix loop in SKILL.md). Desktop Commander is NOT used for gh commands.

| Tool | Environment | Has `gh`? |
|------|-------------|-----------|
| `Bash` | Claude sandbox (Linux) | ✅ After auto-download |
| `mcp__Desktop_Commander__start_process` | User's Mac | ✅ At `/opt/homebrew/bin/gh` (but not used) |

## Authentication

**GH_TOKEN** must be set as a Cowork environment variable. Details and the token itself are stored in the project's CLAUDE.md (not this file). If `GH_TOKEN` is not in the environment, the skill documents this in the report and falls back to unauthenticated checks.

## gh Binary

The `gh` CLI binary (v2.45.0) is downloaded at runtime to `/tmp/gh_2.45.0_linux_{arch}/bin/gh`. The auto-fix loop in SKILL.md handles detection, download, and extraction automatically.

## Commands

```bash
# Check installation
/tmp/gh_2.45.0_linux_arm64/bin/gh --version

# Check auth
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh auth status

# List repos
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh repo list --limit 5

# Rate limit
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh api rate_limit
```

## Output

Report file: `github-health-check-YYYY-MM-DD.md`
Saved to the active Cowork workspace folder.

## Version History

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-03-27 | Initial skill using Bash tool (broken — gh not in sandbox) |
| 0.2.0 | 2026-03-29 | Fixed: switched all gh commands to Desktop Commander |
| 1.0.0 | 2026-03-31 | Switched back to Bash tool with auto-download of gh binary |
| 1.1.0 | 2026-03-31 | Added GH_TOKEN env var support + better auth failure messaging |
| 1.2.0 | 2026-03-31 | Removed sensitive paths from skill file; paths documented in project CLAUDE.md only |

## Scheduled Task

Configured in Cowork scheduled tasks as `github-cli-health-check`. The canonical SKILL.md loaded by the scheduler is documented in project CLAUDE.md (not stored here to avoid exposing machine paths in a public repo).
