---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check — verify authentication, list repos, and check API rate limit.
  Use this skill when the user says "GitHub health check", "check gh CLI", "is GitHub working",
  "gh auth check", "check my GitHub", "GitHub CLI health check", "test gh", "verify GitHub access",
  or any request to verify that the GitHub CLI is authenticated and operational.
  Also triggered by the scheduled task named "github-cli-health-check".
metadata:
  version: "1.3.0"
  updated: "2026-04-10"
  author: "MSApps"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. For write actions (send, post, create, update, delete), only take them if explicitly requested. When in doubt, produce a report of what you found.

Run a GitHub CLI (gh) health check. All `gh` commands MUST be run via **Desktop Commander** (`mcp__Desktop_Commander__start_process`), NOT via the sandbox Bash tool. The Bash tool runs in a sandboxed Linux environment where GitHub is blocked by proxy. Desktop Commander runs on the user's real Mac where `gh` is installed at `/opt/homebrew/bin/gh`.

## Step 1 — Verify gh is installed

Run via Desktop Commander:
```bash
/opt/homebrew/bin/gh --version
```

If the binary exists → proceed. If missing → fall back to Chrome-based check (see AUTO-FIX LOOP).

## Step 2 — Check authentication

Run via Desktop Commander:
```bash
/opt/homebrew/bin/gh auth status
```

Parse the output to determine:
- Which GitHub account is authenticated
- What scopes/permissions are available (`read:org`, `repo`)
- Whether the token is valid or expired

If auth fails, mark Auth as ❌ and skip repo/rate-limit steps. Document reason in report.

## Step 3 — List repositories (quick access test)

Run via Desktop Commander:
```bash
/opt/homebrew/bin/gh repo list --limit 5 --json name,visibility,description,updatedAt,primaryLanguage
```

Record the repo names and metadata returned. If the call fails, mark Repos as ❌.

## Step 4 — Check API rate limit

Run via Desktop Commander:
```bash
/opt/homebrew/bin/gh api rate_limit
```

Parse the JSON output and extract:
- `resources.core.limit` — total allowed requests per hour
- `resources.core.remaining` — requests left
- `resources.core.reset` — reset timestamp (convert to human-readable UTC)

If remaining is below 100, flag as ⚠️ warning. If the call fails, mark Rate Limit as ❌.

## Step 5 — Save report

Save a markdown report to the workspace folder as `github-health-check-YYYY-MM-DD.md`:

```markdown
# GitHub CLI Health Check — YYYY-MM-DD

## Summary Table

| Check | Status |
|-------|:------:|
| Installation | ✅/❌ |
| Authentication | ✅/❌ |
| Repo Access | ✅/❌ |
| API Rate Limit | ✅/⚠️/❌ |

## Details

### Installation
- Version: gh X.Y.Z
- Binary: /opt/homebrew/bin/gh

### Authentication
- Account: <username>
- Scopes: <scopes>
- Token: stored in keyring / GH_TOKEN env var

### Recent Repos (last 5)
| Repo | Visibility | Language | Updated |
|------|-----------|----------|---------|
| name | PUBLIC/PRIVATE | Lang | date |

### API Rate Limit
- Limit: 5,000 / hr
- Remaining: X
- Used: X
- Resets at: HH:MM UTC

## Notes
- Any issues, anomalies, or observations
```

Present the summary to the user after saving the report.

## AUTO-FIX LOOP

If any step fails, attempt these fixes automatically before giving up:

1. **If Desktop Commander not available or `gh` not found at `/opt/homebrew/bin/gh`:**
   - Try `which gh` via Desktop Commander to find alternate gh path
   - Try `brew install gh` via Desktop Commander if gh is missing
   - If Desktop Commander unavailable → fall back to Chrome-based check (see below)
   - Do NOT use sandbox Bash tool — GitHub is blocked by proxy in the sandbox

2. **If auth fails:** gh on Mac uses the system keyring — token should always be available. If not:
   - Run `gh auth login` via Desktop Commander (may require user interaction)
   - Document the issue in the report and note that user must run `gh auth login` on their Mac

3. **If rate limit check fails but auth succeeded:** retry once after 5 seconds.

Maximum 3 fix attempts per step. Always save the final report regardless of pass/fail count.

## CHROME-BASED FALLBACK (when Desktop Commander unavailable)

When Desktop Commander is not available, use Chrome MCP:

**Auth check:** Navigate to `https://github.com`, read `meta[name="user-login"]` via JavaScript.

**Repo listing:** Navigate to `https://github.com/{username}?tab=repositories`, use `get_page_text`.

**Rate limit (unauthenticated):**
```javascript
(async () => {
  const resp = await fetch('https://api.github.com/rate_limit', {
    headers: { 'Accept': 'application/vnd.github.v3+json' }
  });
  return JSON.stringify(await resp.json());
})()
```
Note: Chrome fetch to `api.github.com` is unauthenticated (CORS). Rate limit shows 60/hr. Run this from a neutral page (not github.com itself — CORS override interferes).

## Known Infrastructure

- **gh binary:** `/opt/homebrew/bin/gh` on user's Mac (version 2.89.0 as of 2026-04-10)
- **Auth storage:** Mac system keyring (no GH_TOKEN env var needed when using Desktop Commander)
- **Account:** `msmobileapps` (github.com)
- **Token scopes:** `read:org`, `repo`
- **Sandbox proxy:** Blocks `github.com` and `api.github.com` — do NOT use sandbox Bash for gh commands

## Autonomy rules

- Run gh commands via Desktop Commander: ✅ always allowed (read-only)
- Save report to workspace: ✅ always allowed
- Update SKILL.md and push to GitHub if new lessons learned: ✅ always allowed
- Modify any GitHub repo content or config: ❌ never without explicit user confirmation

## Learned Fixes (updated 2026-04-10)

- **Use Desktop Commander, not sandbox Bash** — sandbox proxy blocks github.com entirely
- **gh is on the Mac at `/opt/homebrew/bin/gh`** — version 2.89.0, auth via keyring
- **No GH_TOKEN env var needed** when running via Desktop Commander (uses Mac keyring)
- **Chrome fallback works** for auth + repo listing, but gives unauthenticated rate limit (60/hr vs 5000/hr)
- **Chrome `fetch()` to `api.github.com` from github.com context fails** with CORS — use neutral page
- **GitHub sudo required** to create new tokens — can't be automated; use existing keyring auth instead
