---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check — verify authentication, list repos, and check API rate limit.
  Use this skill when the user says "GitHub health check", "check gh CLI", "is GitHub working",
  "gh auth check", "check my GitHub", "GitHub CLI health check", "test gh", "verify GitHub access",
  or any request to verify that the GitHub CLI is authenticated and operational.
  Also triggered by a scheduled task named "github-cli-health-check".
metadata:
  version: "1.4.0"
  updated: "2026-04-20"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. For write actions (send, post, create, update, delete), only take them if explicitly requested. When in doubt, produce a report of what you found.

Run a GitHub CLI (gh) health check. All `gh` commands MUST be run via **Desktop Commander** (`mcp__Desktop_Commander__start_process`), NOT via the sandbox Bash tool. The Bash tool runs in a sandboxed Linux environment where GitHub is typically blocked by proxy. Desktop Commander runs on the user's real machine where `gh` is installed (usually at `/opt/homebrew/bin/gh` on macOS or `/usr/bin/gh` on Linux).

## Step 1 — Verify gh is installed

Run via Desktop Commander:
```bash
gh --version
```

If the binary exists → proceed. If missing → fall back to Chrome-based check (see AUTO-FIX LOOP).

## Step 2 — Check authentication

Run via Desktop Commander:
```bash
gh auth status
```

Parse the output to determine:
- Which GitHub account is authenticated
- What scopes/permissions are available
- Whether the token is valid or expired

If auth fails, mark Auth as ❌ and skip repo/rate-limit steps. Document reason in report.

## Step 3 — List repositories (quick access test)

Run via Desktop Commander:
```bash
gh repo list --limit 5 --json name,visibility,description,updatedAt,primaryLanguage
```

Record the repo metadata returned. If the call fails, mark Repos as ❌.

> **Privacy note:** the list of repo names that comes back is personal to the authenticated user. Include counts and visibility breakdown in the saved report if you like, but avoid echoing full repo names back to the user unless they've asked.

## Step 4 — Check API rate limit

Run via Desktop Commander:
```bash
gh api rate_limit
```

Parse the JSON output and extract:
- `resources.core.limit` — total allowed requests per hour
- `resources.core.remaining` — requests left
- `resources.core.reset` — reset timestamp (convert to human-readable UTC)

If remaining is below 100, flag as ⚠️ warning. If the call fails, mark Rate Limit as ❌.

## Step 5 — Save report

**ALWAYS** save the generated report to a fixed, predictable folder on the user's machine:

```
$HOME/Claude/Scheduled/github-cli-health-check/github-health-check-YYYY-MM-DD.md
```

On most setups this resolves to `~/Claude/Scheduled/github-cli-health-check/`. If the user keeps their Claude workspace under `~/Documents/Claude/` instead, use `$HOME/Documents/Claude/Scheduled/github-cli-health-check/` — detect which one exists, create it if neither does.

Create the folder before writing:
```bash
mkdir -p "$HOME/Claude/Scheduled/github-cli-health-check" 2>/dev/null || \
mkdir -p "$HOME/Documents/Claude/Scheduled/github-cli-health-check"
```

Never save the report inside the workspace folder, a git repo, or anywhere that could be pushed to a public remote. This folder is the single source of truth for health-check history.

### Report template

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
- Binary: <path>

### Authentication
- Account: <username>
- Scopes: <list of scopes>
- Token: stored in keyring / env var

### Recent Repos (last 5)
| Repo | Visibility | Language | Updated |
|------|-----------|----------|---------|
| <name> | PUBLIC/PRIVATE | <lang> | <date> |

### API Rate Limit
- Limit: 5,000 / hr (authenticated) or 60 / hr (unauthenticated)
- Remaining: X
- Used: X
- Resets at: HH:MM UTC

## Notes
- Any issues, anomalies, or observations
```

Present a short summary to the user after saving the report, and link to the file.

## AUTO-FIX LOOP

If any step fails, attempt these fixes automatically before giving up:

1. **If Desktop Commander not available or `gh` not found:**
   - Try `which gh` via Desktop Commander to find the binary
   - Try `brew install gh` (macOS) or `apt-get install gh` (Debian/Ubuntu) via Desktop Commander if gh is missing
   - If Desktop Commander unavailable → fall back to Chrome-based check (see below)
   - Do NOT use sandbox Bash — GitHub is typically blocked by proxy in the sandbox

2. **If auth fails:** gh uses the system keyring on most platforms — the token should be available. If not:
   - Run `gh auth login` via Desktop Commander (may require user interaction)
   - Document the issue in the report and note that the user must run `gh auth login` on their machine

3. **If rate limit check fails but auth succeeded:** retry once after 5 seconds.

4. **If the report folder doesn't exist:** create it with `mkdir -p` before writing.

Maximum 3 fix attempts per step. Always save the final report regardless of pass/fail count.

## CHROME-BASED FALLBACK (when Desktop Commander unavailable)

When Desktop Commander is not available, use Chrome MCP:

**Auth check:** Navigate to `https://github.com`, read `meta[name="user-login"]` via JavaScript.

**Repo listing:** Navigate to `https://github.com/<username>?tab=repositories`, use `get_page_text`.

**Rate limit (unauthenticated):**
```javascript
(async () => {
  const resp = await fetch('https://api.github.com/rate_limit', {
    headers: { 'Accept': 'application/vnd.github.v3+json' }
  });
  return JSON.stringify(await resp.json());
})()
```
Note: Chrome fetch to `api.github.com` is unauthenticated (CORS) and shows 60/hr. Run this from a neutral page (not github.com itself — CORS override interferes).

## Autonomy rules

- Run gh commands via Desktop Commander: ✅ always allowed (read-only)
- Save report to `~/Claude/Scheduled/github-cli-health-check/` (or `~/Documents/Claude/...`): ✅ always allowed
- Update this SKILL.md based on new lessons learned: ✅ always allowed
- Modify any GitHub repo content or config: ❌ never without explicit user confirmation
- Echo private repo names or token values back to the user: ❌ avoid unless asked

## Learned Fixes

- **Always save reports to `~/Claude/Scheduled/github-cli-health-check/`** (or `~/Documents/Claude/Scheduled/github-cli-health-check/` if the user keeps their Claude workspace under Documents). One fixed folder — never the cowork workspace, never a git repo, never `/mnt/...`.
- **Use Desktop Commander, not sandbox Bash** — the sandbox proxy blocks github.com in most cowork/agent setups.
- **Use `gh` from `$PATH`** via Desktop Commander — no need to hardcode an install path; let the user's shell find it.
- **Auth via keyring** — no `GH_TOKEN` env var needed when running via Desktop Commander on a logged-in machine.
- **Chrome fallback works** for auth + repo listing, but gives unauthenticated rate limit (60/hr vs 5000/hr).
- **Chrome `fetch()` to `api.github.com` from github.com context fails** with CORS — use a neutral page.
- **Never log the token value** — `gh auth status` masks it by default; don't un-mask it.
