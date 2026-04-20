# github-cli-health-check — Task Notes

## Purpose

Scheduled health check for the GitHub CLI (`gh`). Verifies installation, authentication, repo access, and API rate limit. Saves a structured report to the workspace.

## Critical: Tool Selection — Auto-detect

Use this decision flow at the start of every run:

### Step 1 — Check Bash first
```bash
which gh
```
- ✅ Found → use Bash for all gh commands
- ❌ Not found → go to Step 2

### Step 2 — Try to install gh in Bash
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
sudo apt-get update -q && sudo apt-get install -y gh
```
- ✅ Installed → use Bash
- ❌ Failed → go to Step 3 (sandbox has no network/sudo — this is expected)

### Step 3 — Fallback: Desktop Commander
Use `mcp__Desktop_Commander__start_process` on the user's real Mac where `gh` is at `/opt/homebrew/bin/gh`.

| Tool | Environment | Has `gh`? | Notes |
|------|-------------|-----------|-------|
| `Bash` | Claude sandbox (Linux/aarch64) | ⚠️ Maybe | Try first; install if missing; expect failure in sandbox |
| `mcp__Desktop_Commander__start_process` | User's Mac (macOS) | ✅ Yes | Reliable fallback — gh @ `/opt/homebrew/bin/gh` |

## Commands

```bash
gh --version
gh auth status
gh repo list --limit 5
gh api rate_limit
```

## Output

Report file: `github-health-check-YYYY-MM-DD.md`
Saved to `~/Claude/Scheduled/github-cli-health-check/` (or `~/Documents/Claude/Scheduled/github-cli-health-check/` if the user keeps their Claude workspace under Documents). Never save to the workspace/cowork outputs folder — the Scheduled folder is the single source of truth and is outside any git repo.

## Version History

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-03-27 | Initial — used Bash tool (broken: gh not in sandbox) |
| 0.2.0 | 2026-03-29 | Fixed — all gh commands via Desktop Commander |
| 0.3.0 | 2026-03-31 | Switched to Bash with auto-download of gh binary + GH_TOKEN |
| 0.4.0 | 2026-04-02 | Clarified sandbox limitations: no network/sudo, gh cannot be installed in Bash sandbox |
| 0.5.0 | 2026-04-03 | Auto-detect tool: try Bash first, attempt apt install, fall back to Desktop Commander |
| 0.6.0 | 2026-04-06 | Removed org-specific references — plugin is now fully generic |
| 0.7.0 | 2026-04-20 | Reports now always save to `~/Claude/Scheduled/github-cli-health-check/` (outside any git repo); scrubbed usernames, token scopes, and any host-specific paths from docs and SKILL.md |
