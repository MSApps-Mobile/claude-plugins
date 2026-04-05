---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check — verify authentication, list repos, and check API rate limit.
  Use this skill when the user says "GitHub health check", "check gh CLI", "is GitHub working",
  "gh auth check", "check my GitHub", "GitHub CLI health check", "test gh", "verify GitHub access",
  or any request to verify that the GitHub CLI is authenticated and operational.
  Also triggered by the scheduled task named "github-cli-health-check".
metadata:
  version: "1.2.0"
  updated: "2026-03-31"
  author: "MSApps"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. For write actions (send, post, create, update, delete), only take them if explicitly requested. When in doubt, produce a report of what you found.

Run a GitHub CLI (gh) health check. All `gh` commands MUST be run via the **Bash tool** (in the Claude sandbox), NOT via Desktop Commander. The sandbox uses a downloaded `gh` binary — see auto-fix loop below.

## Step 1 — Verify gh is installed

Run via Bash:
```bash
/tmp/gh_2.45.0_linux_arm64/bin/gh --version
```

If the binary doesn't exist, trigger the auto-fix loop (see below) to download it before continuing.

## Step 2 — Check authentication

Run via Bash:
```bash
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh auth status
```

Parse the output to determine:
- Which GitHub account is authenticated
- What scopes/permissions are available
- Whether the token is valid or expired

If auth fails, mark Auth as ❌ and skip repo/rate-limit steps. Document reason in report.

## Step 3 — List repositories (quick access test)

Run via Bash:
```bash
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh repo list --limit 5
```

Record the repo names returned. If the call fails, mark Repos as ❌.

## Step 4 — Check API rate limit

Run via Bash:
```bash
GH_TOKEN=$GH_TOKEN /tmp/gh_2.45.0_linux_arm64/bin/gh api rate_limit
```

Parse the JSON output and extract:
- `resources.core.limit` — total allowed requests
- `resources.core.remaining` — requests left
- `resources.core.reset` — reset timestamp (convert to human-readable)

If remaining is below 100, flag as ⚠️ warning. If the call fails, mark Rate Limit as ❌.

## Step 5 — Save report

Save a markdown report to the workspace folder as `github-health-check-YYYY-MM-DD.md`:

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

## AUTO-FIX LOOP

If any step fails, attempt these fixes automatically before giving up:

1. **If `gh` binary not found:** detect arch via `uname -m`, download the correct binary:
   - aarch64/arm64 → `https://github.com/cli/cli/releases/download/v2.45.0/gh_2.45.0_linux_arm64.tar.gz`
   - x86_64 → `https://github.com/cli/cli/releases/download/v2.45.0/gh_2.45.0_linux_amd64.tar.gz`
   Extract to `/tmp/` and use at `/tmp/gh_2.45.0_linux_{arch}/bin/gh`. Check if already exists before downloading.

2. **If auth fails (no GH_TOKEN):** check environment for `GH_TOKEN` or `GITHUB_TOKEN`. If neither is set:
   - Do NOT retry in an infinite loop.
   - Document in the report: "GH_TOKEN not in environment — set a GitHub personal access token (repo + read:org scopes) in Cowork → Settings → Environment Variables as GH_TOKEN, then restart Cowork."
   - Attempt unauthenticated rate limit check as fallback: `curl -s https://api.github.com/rate_limit`

3. **If rate limit check fails but auth succeeded:** retry once after 5 seconds.

Maximum 3 fix attempts per step. Always save the final report regardless of pass/fail count.

## Autonomy rules

- Run gh commands: ✅ always allowed (read-only)
- Save report to workspace: ✅ always allowed
- Modify any GitHub config or push changes: ❌ never without explicit user confirmation
