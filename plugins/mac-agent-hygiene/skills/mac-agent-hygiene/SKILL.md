---
name: mac-agent-hygiene
description: This skill should be used when the user asks to "clean up the Mac", "the disk is full", "free disk space", "why is my Mac full", "stale worktrees", "remove old worktrees", "install the hygiene agent", "schedule a cleanup every few hours", "schedule a daily cleanup", "hygiene status", "what is eating my disk", "clean Gradle / Xcode / iOS simulators / Android caches", "clean up old agent session folders", or when a Mac that runs Claude Code agents is slow, swapping, or has little free space. Provides the plan → confirm → apply routine behind the mac-agent-hygiene MCP tools and the LaunchAgent that runs every 4 hours.
version: 0.2.0
---

# Mac Agent Hygiene

A Mac that runs Claude Code agents all day fills its disk in places no cleanup app looks: linked git
worktrees that nobody removed, leftover plugin-install clones, browser-profile caches, Xcode build
output. On one 926 GB machine these were 200+ GB while Downloads and Documents together held 2 GB.
This skill, the bundled MCP server and the scheduled LaunchAgent exist so that never happens again on
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
   `com.msapps.mac-agent-hygiene` (default every 4 hours and at login; `every_hours` changes it,
   `hour`/`minute` switches to once a day); a lock stops a slow run from overlapping the next. It copies `hygiene.sh` to
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
| `worktrees` | a linked worktree under any `HYG_WT_ROOTS` `dir:glob` pair (default `~/code:*wt-*` and `~/code/wt:*`) that is untouched > `HYG_WT_AGE_DAYS` (7), is nobody's cwd, has an empty `git status --porcelain`, and whose HEAD is on a remote-tracking ref, equals the head of a merged PR (`gh pr list --state merged`), is already in the GitHub default branch (`gh api repos/R/compare/SHA...main` is ahead/identical — stale remote refs), or is held by a local branch of the parent repo (the branch and its commits stay there after the worktree goes) | dirty, unpushed, unmerged, in-use, recently touched, or a full clone (`.git` is a directory, not a file) |
| `session-dirs` | EVERY folder directly under `HYG_SESSION_ROOT` (`~/code/wt`) except a linked worktree — plain session folders and top-level full clones — with no file touched for `HYG_SESSION_AGE_HOURS` (24), nobody's cwd, the session not alive in `HYG_SESSIONS_JSON` (`~/.local/state/opsagents-routines/sessions.json`), and the folder's own clone plus EVERY nested repo / worktree clean and pushed (the worktree test; a full clone's local branches each pass when a remote-tracking ref or the GitHub default branch holds their tip); parent repos' worktree metadata is pruned after | the whole folder, if any one repo is dirty, unpushed or unreadable, or the registry is unreadable |
| `build-artifacts` | `node_modules`, `.next`, `dist`, `build`, `.turbo`, `coverage` inside any `~/code/wt/<session>` folder (to `HYG_ARTIFACT_DEPTH` 6) when the session folder is idle `HYG_ARTIFACT_IDLE_HOURS` (24), nobody's cwd is inside, the session is not alive in the registry, the dir holds no `.git`, and git ignores it with no tracked file (outside a repo: node_modules/.next/.turbo beside a `package.json`) | tracked or un-ignored dirs, `dist`/`build`/`coverage` outside a repo, any dir holding a repo; the repo, its work and its branches are never touched |
| `gradle` | `~/.gradle/wrapper/dists/*` and `~/.gradle/daemon/*` versions older than `HYG_GRADLE_AGE_DAYS` (30) | the newest two of each, and any version a running Gradle process names |
| `ios` | `~/Library/Developer/Xcode/iOS DeviceSupport/*` older than `HYG_DEVICE_SUPPORT_AGE_DAYS` (90) (Xcode re-copies it when the device connects); simulators whose runtime is gone (`xcrun simctl delete`) | the newest DeviceSupport; every simulator whose runtime is installed; everything while Xcode builds or Simulator runs; `Xcode/Archives` is never a candidate |
| `android` | `~/.android/cache/*` older than `HYG_ANDROID_CACHE_AGE_DAYS` (7) | AVDs (`~/.android/avd`) and SDK system images / build-tools — user data, sized by `hygiene_status`, never removed |
| `pkg-caches` | `~/Library/Caches/CocoaPods` with no file newer than `HYG_PKG_CACHE_AGE_DAYS` (30) | a cache used this month |

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
HYG_WT_MERGED_PR_CHECK=1      # 0 = no gh calls (no merged-PR or default-branch check)
HYG_GH_SHA_CHECK_MAX=500      # gh compare calls per run; over the cap ⇒ keep
HYG_WT_ROOTS="$HOME/code:*wt-* $HOME/code/wt:*"   # extra worktree roots, dir:glob pairs
HYG_SESSION_ROOT="$HOME/code/wt"; HYG_SESSION_AGE_HOURS=24
HYG_GRADLE_AGE_DAYS=30; HYG_DEVICE_SUPPORT_AGE_DAYS=90; HYG_ANDROID_CACHE_AGE_DAYS=7
HYG_PKG_CACHES="$HOME/Library/Caches/CocoaPods"; HYG_PKG_CACHE_AGE_DAYS=30
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
  more than a few hours. Check `~/Library/Logs/mac-agent-hygiene.log` for an `apply done` line every
  4 hours (or `scheduled run skipped: previous run still holds …` while a long run is still going).
- Big Android AVDs, SDK images and iOS simulators are reported, not removed: deleting them costs the
  owner a re-download and their emulator state. Name them with their size and let the owner decide.
- Disk free after a run is the only number that matters; `df -h /` is printed in every apply summary.

## Additional Resources

### Reference Files

- **`references/safety-model.md`** — why each rule exists, with the measurements behind it (the
  playwright-profile login trap, the launchd PATH trap, the `mktemp`/`TMPDIR` trap, the
  worktree `.git`-is-a-file test, and the SingletonLock age rule).

### Scripts

- **`scripts/hygiene.sh`** — `status | plan | apply <planfile> | run`
- **`scripts/install-launchd.sh`** — `install [--every-hours N | --hour H --minute M] | status | uninstall`
- **`scripts/launchagent.plist.template`** — rendered by the installer
- **`server/index.js`** — the MCP server (zero dependencies, stdio)

Related plugin in the same marketplace: `mac-disk-cleaner` (interactive disk exploration and
one-off cache cleaning for any Mac). This plugin is the scheduled, agent-aware routine.
