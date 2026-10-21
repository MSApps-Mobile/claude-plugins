---
name: mac-agent-hygiene
description: This skill should be used when the user asks to "clean up the Mac", "the disk is full", "free disk space", "why is my Mac full", "stale worktrees", "remove old worktrees", "install the hygiene agent", "schedule a daily cleanup", "hygiene status", "what is eating my disk", or when a Mac that runs Claude Code agents is slow, swapping, or has little free space. Provides the plan → confirm → apply routine behind the mac-agent-hygiene MCP tools and the daily LaunchAgent.
version: 0.1.0
---

# Mac Agent Hygiene

A Mac that runs Claude Code agents all day fills its disk in places no cleanup app looks: linked git
worktrees that nobody removed, leftover plugin-install clones, browser-profile caches, Xcode build
output. On one 926 GB machine these were 200+ GB while Downloads and Documents together held 2 GB.
This skill, the bundled MCP server and the daily LaunchAgent exist so that never happens again on
any Mac that installs the plugin.

## The routine

Run the four MCP tools in this order. Never skip the plan.

1. **`hygiene_status`** — read the snapshot: disk free, DerivedData size, leftover plugin clones,
   Playwright profiles (how many, how many locked / in use), worktrees total and stale, whether Xcode
   is building, whether the LaunchAgent is loaded, and the last log lines.
2. **`hygiene_plan`** — dry run. Every candidate comes back with `remove` or `keep`, its size, and a
   reason. Read the `keep` reasons as carefully as the `remove` ones: `dirty-uncommitted-work`,
   `unpushed-commits`, `a-process-is-inside`, `profile-in-use`, `xcode-building` are the routine
   working. The plan returns a `plan_id` valid for 30 minutes.
3. **`hygiene_apply`** with that `plan_id` and `confirm: true` — each item is re-checked at apply
   time by the same function that planned it; anything that changed since the plan is refused, not
   removed. Report removed / refused / MB freed from the result.
4. **`hygiene_schedule`** `action: "install"` once per Mac — installs the LaunchAgent
   `com.msapps.mac-agent-hygiene` (default 04:30 daily); it copies `hygiene.sh` to
   `~/.local/share/mac-agent-hygiene/` so the job survives plugin updates — re-run install after an
   update. `action: "status"` later. The scheduled run
   is exactly `plan` + `apply` with no human in the loop, which is why the eligibility rules below
   are conservative by construction.

Without the MCP server (plain shell): `bash scripts/hygiene.sh status | plan | run` and
`bash scripts/install-launchd.sh install | status | uninstall`.

## What gets removed, and what never does

| Category | Removed | Kept |
|---|---|---|
| `derived-data` | `~/Library/Developer/Xcode/DerivedData/*` | everything, while `xcodebuild`, Xcode or `XCBBuildService` is running |
| `plugin-clones` | `~/.claude/plugins/cache/temp_git_*` older than 24 h | younger clones (an install may still be using them) |
| `browser-caches` | inside each `~/.cache/playwright-*` profile, ONLY: `Default/Cache`, `Default/Code Cache`, `Default/GPUCache`, `Default/Service Worker/CacheStorage` + `ScriptCache`, Dawn / Graphite / shader caches, `BrowserMetrics*` | Cookies, Local Storage, IndexedDB, Login Data, Local State, Preferences, Session Storage, Network — the profile IS a login; any profile with a `SingletonLock` or open files is skipped whole |
| `model-caches` | the directories in `HYG_MODEL_CACHES` (default `~/.cache/whisper`, `~/.cache/codex-runtimes`), idle > `HYG_MODEL_CACHE_AGE_DAYS` (7) | when a process has them open or they were used this week |
| `worktrees` | a linked worktree under `HYG_WT_ROOT` (default `~/code`) matching `HYG_WT_GLOB` (default `*wt-*`) that is untouched > `HYG_WT_AGE_DAYS` (7), is nobody's cwd, has an empty `git status --porcelain`, and whose HEAD is on a remote-tracking ref or equals the head of a merged PR (`gh pr list --state merged`) | dirty, unpushed, unmerged, in-use, recently touched, or a full clone (`.git` is a directory, not a file) |

The decision lives in one shell function per category, used by `plan` and by `apply`. A `gh` failure
makes the merged-PR branch of the worktree check return empty, so the worktree is kept — the rail
fails toward keeping. Paths outside `$HOME` are refused at apply time regardless of category.

Things this skill never does: `sudo`; anything under `/System`, `/Library`, `~/Library/Application
Support`, keychains, Mail, `~/.ssh`; deleting a `SingletonLock`; killing a process; removing a
worktree with `--force`.

## Configuration

Optional file `~/.config/mac-agent-hygiene/config.env`, sourced by the script:

```bash
HYG_WT_ROOT="$HOME/code"      # where agent worktrees live
HYG_WT_GLOB="*wt-*"           # how they are named
HYG_WT_AGE_DAYS=7
HYG_MODEL_CACHES="$HOME/.cache/whisper $HOME/.cache/codex-runtimes"
HYG_MODEL_CACHE_AGE_DAYS=7    # model caches go when not MODIFIED this long (a read does not count)
HYG_WT_MERGED_PR_CHECK=1      # 0 = pushed-only (no gh call)
```

Environment variables win over the config file (an MCP `worktree_age_days` override applies to that
run only). "Untouched" means no regular file inside the worktree (outside `.git`) is newer than the
age. "Clean" is `git status --porcelain` empty, so gitignored files go with the worktree.

The browser-cache allowlist is fixed in code on purpose. The LaunchAgent carries an explicit `PATH`
(`/usr/bin:/bin:/usr/sbin:/sbin` plus the Homebrew bin that holds `gh`) because launchd does not
inherit the shell's; every system binary in the scripts is called by absolute path for the same
reason. Temp files use `mktemp` with a `${TMPDIR:-/tmp}` template.

## Reading the result honestly

- A `keep` is a measurement, not a failure. Report the top keep reasons so the user knows what is
  holding space on purpose (for example 80 dirty or unpushed worktrees).
- Session transcripts under `~/.claude/projects` are pruned by Claude Code itself via
  `cleanupPeriodDays` in `~/.claude/settings.json` (default 30). `hygiene_status` reports the current
  value; recommend 14 when the directory is large. Never edit that file from this skill.
- A cache that was removed will grow back; the point of the LaunchAgent is that it never grows for
  more than a day. Check `~/Library/Logs/mac-agent-hygiene.log` for the daily `apply done` line.
- Disk free after a run is the only number that matters; `df -h /` is printed in every apply summary.

## Additional Resources

### Reference Files

- **`references/safety-model.md`** — why each rule exists, with the measurements behind it (the
  playwright-profile login trap, the launchd PATH trap, the `mktemp`/`TMPDIR` trap, the
  worktree `.git`-is-a-file test, and the SingletonLock age rule).

### Scripts

- **`scripts/hygiene.sh`** — `status | plan | apply <planfile> | run`
- **`scripts/install-launchd.sh`** — `install [--hour H --minute M] | status | uninstall`
- **`scripts/launchagent.plist.template`** — rendered by the installer
- **`server/index.js`** — the MCP server (zero dependencies, stdio)

Related plugin in the same marketplace: `mac-disk-cleaner` (interactive disk exploration and
one-off cache cleaning for any Mac). This plugin is the scheduled, agent-aware routine.
