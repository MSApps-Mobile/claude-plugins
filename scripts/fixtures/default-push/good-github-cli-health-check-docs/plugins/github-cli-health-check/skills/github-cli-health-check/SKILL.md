---
name: github-cli-health-check
description: >
  Run a GitHub CLI (gh) health check — verify installation, authentication,
  list repos, and check API rate limit. Runtime-aware: on the cloud Routine
  path it uses native `gh`; in Cowork it routes through Desktop Commander to
  the host Mac's `gh`; locally it uses whichever `gh` is on PATH.
  Use this skill when the user says "GitHub health check", "check gh CLI",
  "is GitHub working", "gh auth check", "check my GitHub", "GitHub CLI
  health check", "test gh", "verify GitHub access", or any request to verify
  that the GitHub CLI is authenticated and operational. Also triggered by a
  scheduled task named "github-cli-health-check".
metadata:
  version: "3.0.0"
  updated: "2026-04-20"
---

This skill runs on-demand (no automatic schedule). Execute every step
autonomously regardless — do not ask questions, and always produce the
markdown report even if checks fail. Read-only only: never mutate GitHub
state, never echo the raw token.

## Two live paths — pick at runtime

This skill runs in one of three contexts. Detect which you're in and use the
matching execution path. **Both paths are manual-only and redundant** — run
whichever is convenient; run both if the first looks off.

| Context                                   | Execution path             | How to detect                                                            |
|-------------------------------------------|----------------------------|--------------------------------------------------------------------------|
| Routine (Claude Code cloud, on-demand)    | Native `gh` in the cloud   | Running from a Routine session; `gh` on PATH; cloud-provided `GITHUB_TOKEN`. |
| Cowork task (Mac, on-demand)              | Desktop Commander → Mac gh | `mcp__Desktop_Commander__start_process` is available.                    |
| Interactive local session                 | Whichever `gh` works       | User is present; try VM Bash first, fall back to DC if proxy blocks it.  |

Routines live under `plugins/github-cli-health-check/routines/` in this repo —
see `routines/README.md` for registration. The Routine has its own prompt
file (`routines/prompt.md`); this SKILL.md is what the Cowork scheduled task
and interactive sessions load.

## Known infrastructure block (tracked upstream)

The Cowork sandbox proxy blocks `api.github.com` (and
`raw.githubusercontent.com`, `release-assets.githubusercontent.com`,
`codeload.github.com`). Signature: `403 X-Proxy-Error: blocked-by-allowlist`.
Project-level `sandbox.network.allowedDomains` has no effect; `sudo` is
broken; there is no VM-side install that makes `gh` work in Cowork today.

**But `git` itself works from the VM.** Plain `git` over HTTPS to
`github.com` is on the allowlist, so `git clone`, `git fetch`, `git pull`,
and **`git push`** all succeed directly from the Cowork VM. Only
`api.github.com` (REST + GraphQL) is blocked. Practical rule:

- ✅ VM Bash is fine for: `git add`, `git commit`, `git push`, cloning,
  fetching, tagging — anything that talks only to `github.com`.
- ❌ VM Bash fails for: `gh auth`, `gh repo list`, `gh pr create`,
  `gh api`, `gh issue`, any MCP/plugin that hits GitHub's REST API.

So don't bounce through Desktop Commander for pushes — just push from the
VM. Only route through DC when you actually need `gh` / REST / GraphQL.

Tracked upstream: https://github.com/anthropics/claude-code/issues/37970

Until #37970 closes, do **not** spend time re-probing the allowlist or
reinstalling `gh` from inside the Cowork VM. Use Desktop Commander for the
Cowork path; use the Routine for the cloud path. When #37970 closes, add
the VM Bash path back as a third option and keep the other two as fallbacks.

## Execution path A — Routine / cloud (primary, when applicable)

Only runs this way when invoked by the cloud Routine. The Routine has its own
prompt at `routines/prompt.md` — this SKILL.md isn't normally loaded in that
context, but if it is, mirror the Routine's steps: `gh auth status`,
`gh repo list --limit 5 --json …`, `gh api rate_limit`, print report.

Skip to path B/C below if not in a Routine.

## Execution path B — Cowork scheduled task (fallback via Desktop Commander)

All `gh` commands run via `mcp__Desktop_Commander__start_process` against the
user's Mac. `gh` is at `/opt/homebrew/bin/gh`, authenticated through the Mac
keyring. Do **not** try sandbox Bash — the proxy blocks `api.github.com`.

### Steps (via Desktop Commander)

```bash
/opt/homebrew/bin/gh --version
/opt/homebrew/bin/gh auth status
/opt/homebrew/bin/gh repo list --limit 5 --json name,visibility,description,updatedAt,primaryLanguage
/opt/homebrew/bin/gh api rate_limit
```

### Save the report

Via Desktop Commander (this is the host filesystem):

```bash
mkdir -p "$HOME/Claude/Scheduled/github-cli-health-check" 2>/dev/null || \
mkdir -p "$HOME/Documents/Claude/Scheduled/github-cli-health-check"
```

Write the report as `github-health-check-YYYY-MM-DD.md` in whichever of those
directories exists. Never save inside a git repo and never to the Cowork
workspace — it vanishes between sessions and leaks to public remotes.

## Execution path C — Interactive local session

User is present. Try the VM path first for transparency; if it returns
`403 blocked-by-allowlist`, note it and fall through to Desktop Commander.
Same four `gh` commands, same report format. Write the report wherever the
user is working — the workspace directory is fine here.

## Report template (identical across all paths, only the header tag changes)

```markdown
# GitHub CLI Health Check — YYYY-MM-DD (Cowork / DC)

## Summary Table

| Check            | Status |
|------------------|:------:|
| Runtime          | ✅ / ⚠️ |
| gh installed     | ✅ / ❌ |
| Authentication   | ✅ / ❌ |
| Repo Access      | ✅ / ❌ |
| API Rate Limit   | ✅ / ⚠️ / ❌ |

## Details

### Runtime
- Path used: Routine / Cowork+DC / Local
- gh version: X.Y.Z at /path/to/gh

### Authentication
- Account: <username>
- Host: github.com
- Scopes: <list>
- Token source: Mac keyring / GH_TOKEN env / OAuth

### Recent Repos (last 5)
| Repo | Visibility | Language | Updated |
|------|-----------|----------|---------|

### API Rate Limit
- Core: X remaining of 5000, resets HH:MM UTC
- GraphQL / Search / Code search summaries

## Notes
- Cross-reference: today's Routine report at claude.ai/code/routines
- Upstream: https://github.com/anthropics/claude-code/issues/37970
- Anomalies, token scope changes, or anything a future agent needs to know
```

## Autonomy rules

- ✅ Read-only `gh` commands (auth status, repo list, rate limit)
- ✅ Write the report to the host's scheduled-reports folder (path B)
- ✅ Update this SKILL.md when a new lesson is learned
- ❌ Any mutation of GitHub state (push, PR, issue, release, token rotate)
- ❌ Echo the raw token value anywhere
- ❌ Save reports inside a git repo or inside the Cowork workspace

## Learned fixes

- **Dual-path is the design, not a workaround.** Routine + Cowork+DC together
  catch single-path failures. The skill version reflects this: v3.0.0 made
  Routine a peer of the Cowork path rather than an emergency fallback.
- **The Cowork VM Bash path is structurally dead** until #37970 closes. Don't
  re-diagnose every run — link the issue and move on.
- **Reports live outside git.** `$HOME/Claude/Scheduled/github-cli-health-check/`
  or `$HOME/Documents/Claude/Scheduled/...` on the Mac. Never the workspace.
- **Mac `gh` is at `/opt/homebrew/bin/gh`**, auth via keyring. No env vars
  needed from Desktop Commander; the keyring provides the token.
- **Cloud `gh`** gets `GITHUB_TOKEN` from the Claude GitHub App and the
  Routine's `setup.sh` re-exports it as `GH_TOKEN` so plain `gh` works.
- **Chrome MCP can fall back further** (unauthenticated rate_limit → 60/hr)
  if both `gh` paths die simultaneously. That's last-resort only.
