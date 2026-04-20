# github-cli-health-check

Daily health check plugin for the GitHub CLI (`gh`). Verifies installation,
authentication, repo access, and API rate limit. Ships as a **dual-path
setup** — the two paths are redundant on purpose so a failure on either side
still produces a report.

## The two paths

| Path                                           | Where it runs                              | When it runs                            |
|------------------------------------------------|--------------------------------------------|------------------------------------------|
| **Routine** (`routines/`)                      | Anthropic Claude Code cloud infrastructure | Scheduled via `/schedule` or the web UI |
| **Cowork scheduled task** (`skills/`)          | User's Mac, via Desktop Commander          | Scheduled via Cowork's scheduled-tasks   |

Why both? The Cowork sandbox VM currently blocks `api.github.com`
([claude-code#37970](https://github.com/anthropics/claude-code/issues/37970))
— so the Cowork path has to route through Desktop Commander to reach the
Mac's `gh`. The Routine path dodges the allowlist entirely by running on
cloud infrastructure that has native GitHub access. Running both makes the
daily check resilient to either runtime being down.

## Setup

### Routine (cloud path)

See [`routines/README.md`](routines/README.md) for step-by-step registration
via `claude.ai/code/routines` or the `/schedule` CLI command. Requires
Claude Code v2.1.111 or newer. Uses the beta header
`experimental-cc-routine-2026-04-01` (handled by the product, not by you).

The Routine's prompt body is [`routines/prompt.md`](routines/prompt.md); its
cloud-environment bootstrap script is [`routines/setup.sh`](routines/setup.sh).

### Cowork scheduled task (Mac path)

The skill at `skills/github-cli-health-check/SKILL.md` is what the Cowork
scheduled task loads. It routes `gh` through Desktop Commander to the Mac's
`gh` (at `/opt/homebrew/bin/gh`, authenticated via the Mac keyring), then
writes a markdown report to `~/Claude/Scheduled/github-cli-health-check/`
(or `~/Documents/Claude/Scheduled/...` depending on where your Claude
workspace lives).

No additional setup — install the plugin, register the scheduled task, done.

## Usage

Trigger either path by saying any of:
- "Run a GitHub CLI health check"
- "Check if gh is working"
- "Is GitHub authenticated?"
- "GitHub health check"

Or let the schedules do their thing. Recommended cadence: Routine at 08:00
local, Cowork task at 10:00 local — two hours apart so the reports don't
land on top of each other.

## Output

Each path produces the same markdown report structure — a summary table
(Runtime / gh / Auth / Repos / Rate limit) plus detail sections for account,
recent repos, and rate-limit buckets. The only difference is the title line
tags which runtime produced it: `(Routine / cloud)` vs `(Cowork / DC)`.

## When #37970 closes

The Cowork VM Bash path becomes viable again. You'll have three working
paths — keep the Routine as primary (it's the lowest overhead and doesn't
require the Mac to be awake), keep the Cowork+DC task as the secondary
Mac-side check, and add the VM Bash path as a quick sanity check from
interactive sessions. Nothing in this plugin needs a breaking change when
that happens — the SKILL.md already has a slot for it.
