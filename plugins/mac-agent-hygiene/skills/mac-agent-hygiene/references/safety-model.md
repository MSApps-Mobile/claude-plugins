# Safety model — the measurements behind each rule

Every rule in `scripts/hygiene.sh` exists because of something measured on a real agent Mac. This
file keeps the reasons next to the rules so nobody loosens one without knowing what it cost.

## Browser profiles are logins, not caches

`~/.cache/playwright-*` directories are persistent Chromium profiles used by agents to drive
authenticated sites. On the reference machine, 48 of them held 7.2 GB — 3.6 GB of that was
Chromium's own regenerable caches, the rest was session state. Deleting a profile logs the agent out
of that site, and re-login is a human action (passkeys, 2FA, bot checks). So:

- Only the fixed allowlist of cache subfolders is ever removed. `Cookies`, `Local Storage`,
  `IndexedDB`, `Login Data`, `Local State`, `Preferences`, `Session Storage` and `Network` are never
  listed as candidates, in plan or in apply.
- A profile whose `SingletonLock` symlink exists, or that has files open (`lsof +D`), is skipped as a
  whole. The lock test is existence-only on purpose: a stale lock from a crashed browser makes the
  routine skip that profile forever — a silent no-op, not data loss. Never delete the lock to "fix"
  it; clearing a lock a live sibling holds kills that session's in-flight work.

## Worktrees may be the only copy of something

Agents create linked worktrees (`git worktree add`) per task. On the reference machine 774 of them
held most of the 233 GB under `~/code` (up to 1 GB each); 500 had not been touched in a week. But a dirty worktree or one with unpushed commits
can be the only copy of real work, and no board signal says which. Removal therefore requires ALL of:

1. untouched for `HYG_WT_AGE_DAYS` — no regular file inside (outside `.git`) newer than the age, not
   just the directory mtime (editing a nested file would otherwise leave the top-level mtime old);
2. no process has its cwd inside (`lsof -d cwd`) — a live session may be parked there;
3. `.git` is a FILE (a linked worktree). A `.git` directory means a full clone, which is left alone.
   The common idiom `[ -d .git ]` is false for a worktree and is exactly the wrong test here;
4. `git status --porcelain` is empty — no modified, staged or untracked files;
5. HEAD is contained in a remote-tracking ref (`git branch -r --contains HEAD`), OR equals the head
   SHA of a merged pull request (`gh pr list --state merged --json headRefName,headRefOid`). The
   second branch exists because squash merges land content without making the branch commit an
   ancestor of `main`. If `gh` is missing or fails, the merged-PR file is empty and the worktree is
   KEPT.

Removal uses `git worktree remove <path>` without `--force` (git refuses a dirty tree on its own as a
second line of defence) followed by `git worktree prune` in the main repository.

The first real run on the reference machine removed 420 worktrees / 133 GB and kept 80 — every kept
one was dirty, unpushed, in use, or a full clone.

## Paths are compared as strings, never as patterns

A worktree named `wt-[x` once slipped past a cwd check that used the path as a `grep` pattern (the `[`
made the expression invalid, grep exited 2, and the gate was silently skipped). The cwd set is now
read once per run and compared with `=` / a quoted `case` prefix. The apply gate also refuses any
path with a `.` or `..` component before any category check runs, and each category checks
`dirname`/`basename` equality rather than a glob that `*` could stretch across `/`.

## launchd does not give you a PATH

A script that works in Terminal fails under launchd because launchd's job PATH lacks Homebrew and
may lack `/usr/sbin`. Measured failures: bare `ioreg`, `lsof`, `gh` "command not found" only when
scheduled. Hence the plist carries an explicit `PATH` and the scripts call `/usr/sbin/lsof`,
`/usr/bin/find`, `/bin/launchctl` and friends by absolute path, and the installer detects the
Homebrew bin that holds `gh` at install time and bakes it into the rendered plist. The plist points at
a stable copy of the script under `~/.local/share/mac-agent-hygiene/`, never into the plugin cache,
whose path carries a version hash and moves on every plugin update.

Reinstall means `launchctl bootout` + `launchctl bootstrap`. `launchctl kickstart` alone runs the
OLD job definition. The installer verifies the loaded job's path equals the plist it just wrote.

## `mktemp` on macOS ignores an overridden `TMPDIR` unless you give it a template

A bare `mktemp` lands in the system temp dir even when `TMPDIR` is set; only
`mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` honours the override. The scripts use the template form and
`trap` the cleanup, so a test harness can redirect temp files and prove nothing leaks.

## Xcode DerivedData during a build

DerivedData is pure build output and safe to delete — except while a build is writing to it, which
produces confusing compiler errors. The routine checks `pgrep -x xcodebuild|Xcode|XCBBuildService`
and skips the whole category while any is running. iOS Simulator images and `iOS DeviceSupport` are
NOT touched: simulators hold app data and DeviceSupport belongs to the currently paired phone.

## Why plan → confirm → apply, and why the same function decides twice

A dry run that uses one code path and an apply that uses another is how "safe" cleanups delete the
wrong thing. Here `check_item category path` is the only judge; `plan` calls it to label candidates,
`apply` calls it again on every path in the plan file before `rm`/`worktree remove`. Anything that
changed in between — a worktree that got a new commit, a profile that opened — is reported as
`refused` with the reason. Plans expire after 30 minutes so a stale plan cannot be replayed.

## Session transcripts

`~/.claude/projects` grows with every session (13.5 GB on the reference machine). Claude Code prunes
it itself using `cleanupPeriodDays` in `~/.claude/settings.json`. The routine only reports the
setting; editing a user's settings file from a cleanup script is out of scope.
