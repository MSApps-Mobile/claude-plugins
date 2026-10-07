# mac-agent-hygiene

**Keeps a Mac that runs Claude Code agents from filling its disk.** A daily LaunchAgent plus an MCP
server that clear regenerable caches and reap stale git worktrees — after a dry run, with per-item
reasons, and only for things that are already somewhere else.

Home page: https://claudeservices.ai/plugins#mac-agent-hygiene

## What It Does

On one 926 GB Mac running Claude Code agents, free space had fallen to 16 GB. Downloads, Documents
and Desktop together held 2 GB. The space was in:

| Where | Size | What it was |
|---|---|---|
| `~/code/*wt-*` | ~230 GB | 774 linked git worktrees agents created per task and never removed |
| `~/.claude/plugins/cache/temp_git_*` | 34 GB | 937 leftover clones from plugin installs |
| `~/.cache/playwright-*` | 7 GB | agent browser profiles — half of it Chromium's regenerable caches |
| `~/Library/Developer/Xcode/DerivedData` | 6 GB | build output |
| `~/.claude/projects` | 13 GB | session transcripts (Claude Code prunes these itself) |

This plugin turns the fix into a routine any Mac can install:

- **`hygiene_status`** — read-only snapshot.
- **`hygiene_plan`** — dry run: every candidate with `remove` / `keep`, size and reason.
- **`hygiene_apply`** — removes only the planned items, re-checking each one at apply time; needs the
  `plan_id` and `confirm: true`.
- **`hygiene_schedule`** — install / inspect / remove the daily LaunchAgent (`com.msapps.mac-agent-hygiene`,
  04:30 by default).

A worktree is removed only when it is untouched for 7 days, clean, nobody's current directory, and
its HEAD is pushed (or is the head of a merged pull request). Browser profiles are logins: only their
cache subfolders go; cookies and local storage stay. DerivedData is skipped while Xcode builds. The
full reasoning is in `skills/mac-agent-hygiene/references/safety-model.md`.

First real run on the reference machine: 420 worktrees removed (133 GB), 80 kept because they were
dirty, unpushed or in use; disk went from 16 GB free to 219 GB free.

## Prerequisites

- macOS (Apple Silicon or Intel), Node.js 18+ (for the MCP server; the scripts themselves are bash).
- Optional: GitHub CLI `gh`, authenticated — enables the merged-PR check for squash-merged worktrees.
  Without it the routine keeps any worktree whose HEAD is not on a remote ref.
- No `sudo`. Nothing is installed outside `~/Library/LaunchAgents`, `~/Library/Logs` and
  `~/.local/state/mac-agent-hygiene`.

## Setup

### 1. Install the plugin

Claude Code:

```
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install mac-agent-hygiene@msapps-plugins
```

Cowork: **Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`** → search
*mac-agent-hygiene* → Install.

### 2. Look before you clean

Ask Claude: *"hygiene status"* — then *"plan a cleanup"*. Read the `keep` reasons; they are the
routine protecting work in progress.

### 3. Apply, then schedule

*"apply the plan"* removes the planned items. *"install the hygiene agent"* schedules the daily run.
The log is `~/Library/Logs/mac-agent-hygiene.log`.

### Optional configuration

`~/.config/mac-agent-hygiene/config.env`:

```bash
HYG_WT_ROOT="$HOME/code"      # where agent worktrees live
HYG_WT_GLOB="*wt-*"           # how they are named
HYG_WT_AGE_DAYS=7
HYG_MODEL_CACHES="$HOME/.cache/whisper $HOME/.cache/codex-runtimes"
```

### Without the MCP server

```bash
bash scripts/hygiene.sh status
bash scripts/hygiene.sh plan            # dry run, TSV: category action kb reason path
bash scripts/hygiene.sh run             # plan + apply (what the LaunchAgent runs)
bash scripts/install-launchd.sh install # or: status | uninstall
```

## Skills

| Skill | Purpose |
|---|---|
| `mac-agent-hygiene` | The plan → confirm → apply routine, what is and is not removed, configuration, how to read a result |

## Architecture

```
mac-agent-hygiene/
├── .claude-plugin/plugin.json
├── .mcp.json                      # node ${CLAUDE_PLUGIN_ROOT}/server/index.js (stdio)
├── server/index.js                # zero-dependency MCP server: 4 tools, plan→confirm gate
├── scripts/
│   ├── hygiene.sh                 # status | plan | apply <planfile> | run — ONE eligibility function
│   ├── install-launchd.sh         # install | status | uninstall the daily agent
│   └── launchagent.plist.template # rendered from $HOME + detected Homebrew path
├── skills/mac-agent-hygiene/
│   ├── SKILL.md
│   └── references/safety-model.md
├── commands/hygiene-status.md     # /hygiene-status
├── CLAUDE.md · CONNECTORS.md · README.md
```

## Execution Model

**Impact Level:** Medium (deletes regenerable caches and clean, pushed worktrees under `$HOME`)
**Plan:** `hygiene_plan` lists every candidate with remove/keep, size and reason — a dry run, nothing deleted.
**Act:** `hygiene_apply` (plan_id + confirm) re-checks each item and removes only those that still qualify.
**Verify:** per-item outcome (removed / refused + reason), MB freed and `df` after; every run appends to `~/Library/Logs/mac-agent-hygiene.log`.

## SOSA

- **Supervised** — every removal is planned first with a reason; apply needs the plan id and an
  explicit confirm; the scheduled run only touches regenerable caches and clean, pushed, week-old
  worktrees.
- **Orchestrated** — status → plan → re-check → apply → log, in that order, always.
- **Secured** — local filesystem only; the one network call is an optional read-only `gh` query;
  never sudo, never login state, never dirty or unpushed work, paths outside `$HOME` refused.
- **Agents** — R=mac-hygiene · T=bash, launchd, git, gh(read) · M=30-minute plan cache + append-only
  log · P=status-plan-confirm-apply.

## Author

MSApps — https://claudeservices.ai · led by a Claude Certified Architect.
MSApps is Certified in the Claude Partner Network ([claude.com/partners](https://claude.com/partners)).

Related: [`mac-disk-cleaner`](../mac-disk-cleaner) for interactive, one-off disk exploration on any Mac.
Preparing for a Claude certification? The Cert Trainer by OpsAgents AI: https://architect.opsagents.agency

## License

MIT
