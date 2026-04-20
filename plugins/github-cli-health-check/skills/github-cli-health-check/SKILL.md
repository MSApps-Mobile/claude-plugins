---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check inside the sandbox VM — verify installation,
  authentication, list repos, and check API rate limit.
  Use this skill when the user says "GitHub health check", "check gh CLI", "is GitHub working",
  "gh auth check", "check my GitHub", "GitHub CLI health check", "test gh", "verify GitHub access",
  or any request to verify that the GitHub CLI is authenticated and operational.
  Also triggered by a scheduled task named "github-cli-health-check".
metadata:
  version: "2.1.0"
  updated: "2026-04-20"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. Only take write actions if explicitly requested; when in doubt, produce a report.

## Primary path — sandbox VM Bash

All `gh` commands run via the **Bash tool** (the sandbox VM). Having `gh` inside the VM is a requirement, not optional — the scheduled task depends on it. If anything is missing (binary, network, token), the auto-fix loop installs / configures it and retries.

Desktop Commander is an **emergency fallback only**. If you end up on the fallback path, mark it as an anomaly in the report so the VM infrastructure gets fixed.

## Known infrastructure block (tracked upstream)

As of 2026-04-20, the Cowork sandbox proxy blocks `api.github.com` (and `raw.githubusercontent.com`, `release-assets.githubusercontent.com`, `codeload.github.com`, `proxy.golang.org`). Signature: `403 X-Proxy-Error: blocked-by-allowlist`. Project-level `sandbox.network.allowedDomains` has no effect. `sudo` is also broken in the VM. **No VM-side install of `gh` can function** until the allowlist is fixed — `gh` itself talks to `api.github.com`.

Tracked upstream: https://github.com/anthropics/claude-code/issues/37970

**Until the upstream issue is resolved, the runbook is:**
1. Do NOT spend time re-probing the allowlist or trying fresh install recipes — the block is policy-level and documented.
2. Run the full health check via Desktop Commander (emergency fallback path).
3. In every report, add a "Blocked by upstream" note linking #37970 and flagging that the VM primary path is unavailable.
4. When #37970 closes, delete this section and return to VM-first.

## Step 1 — Verify gh is installed in the VM

```bash
which gh && gh --version
```

If missing → auto-fix Step 1 (install in VM). Do not fall back to Desktop Commander yet.

## Step 2 — Check authentication

```bash
gh auth status
```

Token is expected in the `GH_TOKEN` env var inside the VM (set via the host's Cowork/agent environment-variable settings). If the token is missing or invalid → auto-fix Step 2.

## Step 3 — List repositories (access test)

```bash
gh repo list --limit 5 --json name,visibility,description,updatedAt,primaryLanguage
```

Mark Repos as ❌ if this fails. Keep private repo details in the saved report only — avoid echoing repo names back to the user unless they ask.

## Step 4 — Check API rate limit

```bash
gh api rate_limit
```

Extract `resources.core.{limit,remaining,reset}`. Warn at < 100 remaining.

## Step 5 — Save report

Reports **always** save to a fixed folder on the host (outside any git repo), written via Desktop Commander:

```
$HOME/Claude/Scheduled/github-cli-health-check/github-health-check-YYYY-MM-DD.md
```

Fallback to `$HOME/Documents/Claude/Scheduled/github-cli-health-check/` if that's where the host's Claude workspace lives. Create the folder if missing:

```bash
# via Desktop Commander against the host — not sandbox Bash
mkdir -p "$HOME/Claude/Scheduled/github-cli-health-check" 2>/dev/null || \
mkdir -p "$HOME/Documents/Claude/Scheduled/github-cli-health-check"
```

Never save to the cowork workspace, a git repo, or `/tmp/` — those either leak to public remotes or vanish between runs.

### Report template

```markdown
# GitHub CLI Health Check — YYYY-MM-DD

## Summary Table

| Check | Status |
|-------|:------:|
| VM gh installation | ✅/❌ |
| Authentication | ✅/❌ |
| Repo Access | ✅/❌ |
| API Rate Limit | ✅/⚠️/❌ |
| Path (VM primary) | ✅ normal / ⚠️ fallback to Desktop Commander |

## Details
- Version: gh X.Y.Z (in VM)
- Account: <username>
- Scopes: <list>
- Recent repos: 5 pulled, N private / M public
- Rate limit: X / 5000, resets HH:MM UTC

## Notes
- Any issues or anomalies (especially if fallback to Desktop Commander was used — record why)
```

## AUTO-FIX LOOP (VM-first)

Fix-in-place before escalating. Max 3 attempts per step; always save the final report even on partial failure.

### Fix Step 1 — `gh` missing in VM

Detect arch and install. Try in order:

```bash
# a) apt (if sudo available — Debian/Ubuntu sandbox)
sudo apt-get update -q && sudo apt-get install -y gh

# b) tarball download (no sudo, no apt)
ARCH=$(uname -m); case "$ARCH" in
  aarch64|arm64) GHARCH=arm64 ;;
  x86_64)        GHARCH=amd64 ;;
esac
GHVER=2.89.0
curl -fsSL -o /tmp/gh.tgz "https://github.com/cli/cli/releases/download/v${GHVER}/gh_${GHVER}_linux_${GHARCH}.tar.gz"
tar -xzf /tmp/gh.tgz -C /tmp/
ln -sf "/tmp/gh_${GHVER}_linux_${GHARCH}/bin/gh" /usr/local/bin/gh 2>/dev/null || \
  export PATH="/tmp/gh_${GHVER}_linux_${GHARCH}/bin:$PATH"
```

### Fix Step 2 — Missing or invalid token

1. Check env: `env | grep -E '^(GH_TOKEN|GITHUB_TOKEN)='`. If set but invalid → surface "token expired; regenerate on github.com and update the VM env vars".
2. If neither set → record the fix-it step in the report:
   > `GH_TOKEN` not in VM environment. Set it via the host's agent/Cowork environment-variable settings with a PAT scoped appropriately for the checks you want, then restart the session.
3. Attempt unauthenticated rate-limit check as partial data: `curl -s https://api.github.com/rate_limit` (returns 60/hr, unauthenticated).

### Fix Step 3 — Network to github.com blocked

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 8 https://api.github.com/
```
If HTTP 000 / instant reject → the sandbox proxy is blocking GitHub. Record the anomaly: "VM sandbox proxy blocks api.github.com; request allowlisting from the platform." Then fall through to the emergency Desktop Commander path so the check still produces a report.

### Emergency fallback — Desktop Commander

Only if all three VM fixes failed. Run the same commands via `mcp__Desktop_Commander__start_process` against the host machine's `gh` (typically `/opt/homebrew/bin/gh` on macOS, `/usr/bin/gh` on Linux). In the report set "Path" to `⚠️ fallback` and explain which VM fix(es) failed so the infrastructure gap is visible.

## Autonomy rules

- Install `gh` in the VM (apt or tarball): ✅ always allowed — it's a required dependency
- Set env vars in the VM: ❌ cannot — user must set them via host settings; the skill reports the gap
- Run `gh` read-only commands (auth status, repo list, rate limit): ✅ always allowed
- Save report to `~/Claude/Scheduled/github-cli-health-check/`: ✅ always allowed
- Update this SKILL.md based on new lessons learned: ✅ always allowed
- Modify any GitHub repo / config / push code: ❌ never without explicit user confirmation
- Echo private repo names or token values back to the user: ❌ avoid unless asked

## Learned Fixes

- **VM `gh` is the required primary path.** Desktop Commander is fallback only and each use must be flagged as an anomaly so the infra gap is visible.
- **Reports always save to `~/Claude/Scheduled/github-cli-health-check/`** (or `~/Documents/Claude/Scheduled/...` if that's where the host's Claude workspace lives). Single source of truth, outside any git repo.
- **Auto-install `gh` in the VM** via apt first, tarball second, before escalating.
- **Token belongs in the VM env** (`GH_TOKEN`). If missing, report the fix-it step clearly; don't silently fall back.
- **Sandbox proxy blocking github.com is an infra gap, not a design.** Raise it, don't paper over it.
- **Never log the token value** — `gh auth status` masks it; don't un-mask it.
- **VM `api.github.com` block is a policy bug, not transient.** Tracked in https://github.com/anthropics/claude-code/issues/37970 — don't re-diagnose; link the issue in the report and fall back to Desktop Commander until upstream closes it.
