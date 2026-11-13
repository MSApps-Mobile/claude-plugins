# github-cli-health-check

On-demand health check plugin for the GitHub CLI (`gh`). Verifies
installation, authentication, repo access, and API rate limit. Ships as a
**dual-path setup** — two redundant manual paths so a failure on one side
is still caught by the other.

## The two paths

| Path                                 | Where it runs                              | How you invoke it                                   |
|--------------------------------------|--------------------------------------------|-----------------------------------------------------|
| **Routine** (`routines/`)            | Anthropic Claude Code cloud infrastructure | "Run now" in the web UI, `/schedule run`, or `/fire` API |
| **Cowork task** (`skills/`)          | User's Mac, via Desktop Commander          | Manual run of the `github-cli-health-check` task, or just asking for a health check |

Both paths are **manual-only** — there is no daily schedule on either side.
Trigger whichever is convenient when you want to check GitHub health.

Why both? The Cowork sandbox VM currently blocks `api.github.com`
([claude-code#37970](https://github.com/anthropics/claude-code/issues/37970))
— so the Cowork path has to route through Desktop Commander to reach the
Mac's `gh`. The Routine path dodges the allowlist entirely by running on
cloud infrastructure that has native GitHub access. Running both when one
path looks off is how you rule out a single-runtime glitch.

> **Scope of the block:** only `api.github.com` (REST + GraphQL) is blocked.
> Plain `git` over HTTPS to `github.com` is on the allowlist, so `git clone`,
> `git fetch`, `git pull`, and **`git push`** all work directly from the
> Cowork VM Bash tool. Only `gh` / API calls need the DC detour.

## Setup

### Routine (cloud path)

See [`routines/README.md`](routines/README.md) for step-by-step registration
via `claude.ai/code/routines` or the `/schedule` CLI command. Requires
Claude Code v2.1.111 or newer. Uses the beta header
`experimental-cc-routine-2026-04-01` (handled by the product, not by you).

The Routine's prompt body is [`routines/prompt.md`](routines/prompt.md); its
cloud-environment bootstrap script is [`routines/setup.sh`](routines/setup.sh).

### Cowork task (Mac path)

The skill at `skills/github-cli-health-check/SKILL.md` is what the Cowork
manual task loads. It routes `gh` through Desktop Commander to the Mac's
`gh` (at `/opt/homebrew/bin/gh`, authenticated via the Mac keyring), then
writes a markdown report to `~/Claude/Scheduled/github-cli-health-check/`
(or `~/Documents/Claude/Scheduled/...` depending on where your Claude
workspace lives).

No additional setup — install the plugin, register the task as manual-only
(no cron), done. You can also just invoke the skill directly in any Cowork
session by asking for a GitHub health check; the scheduled-task registration
is optional and only exists so the task name shows up in the sidebar.

## Usage

Trigger either path by saying any of:
- "Run a GitHub CLI health check"
- "Check if gh is working"
- "Is GitHub authenticated?"
- "GitHub health check"

There is no automatic schedule. Both paths run only when you explicitly
trigger them.

## Output

Each path produces the same markdown report structure — a summary table
(Runtime / gh / Auth / Repos / Rate limit) plus detail sections for account,
recent repos, and rate-limit buckets. The only difference is the title line
tags which runtime produced it: `(Routine / cloud)` vs `(Cowork / DC)`.

## When #37970 closes

The Cowork VM Bash path becomes viable again. You'll have three working
manual paths — the Routine, Cowork+DC, and VM Bash — with the same
redundancy-on-demand story. Nothing in this plugin needs a breaking change
when that happens; SKILL.md already has a slot for the VM Bash branch.
