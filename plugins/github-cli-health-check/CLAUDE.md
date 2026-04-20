# github-cli-health-check — Task Notes

## Purpose

Scheduled health check for the GitHub CLI (`gh`). Verifies installation, authentication, repo access, and API rate limit. Saves a structured report to the workspace.

## Tool selection — VM Bash is primary

VM `gh` is a required dependency. Run every `gh` command via the sandbox Bash tool. If the VM is missing `gh`, a token, or GitHub network reachability, auto-fix in place. Only fall through to Desktop Commander when all three VM fixes have failed, and flag it as an anomaly.

### Step 1 — VM has gh?
```bash
which gh && gh --version
```
- ✅ Found → proceed
- ❌ Not found → install via apt (`sudo apt-get install -y gh`) or tarball download from [gh releases](https://github.com/cli/cli/releases). If both fail, record the infra gap and fall through to Step 3.

### Step 2 — VM has a valid token?
```bash
env | grep -E '^(GH_TOKEN|GITHUB_TOKEN)=' && gh auth status
```
- ✅ Valid → proceed
- ❌ Missing / invalid → report the fix-it step (set `GH_TOKEN` via host's agent env-var settings). Try unauthenticated `curl https://api.github.com/rate_limit` for partial data.

### Step 3 — Emergency fallback (Desktop Commander)
Only when VM fixes have failed. Run via `mcp__Desktop_Commander__start_process` against the host machine's `gh` (on `$PATH`; typically `/opt/homebrew/bin/gh` on macOS). Flag `Path = ⚠️ fallback` in the report and note which VM fix failed.

| Path | Environment | Expected? |
|------|-------------|-----------|
| `Bash` (VM) | Sandbox Linux | ✅ yes — primary |
| `mcp__Desktop_Commander__start_process` | Host machine | ⚠️ fallback only, flag when used |

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
| 0.8.0 | 2026-04-20 | Flipped primary path: VM Bash is now the required primary, Desktop Commander demoted to emergency fallback (flagged as anomaly in report). Auto-fix installs `gh` in the VM via apt/tarball before escalating. Bumped SKILL.md to 2.0.0. |
