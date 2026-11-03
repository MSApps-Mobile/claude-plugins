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

These rules are enforced by `tests/hygiene-keeps-logins.test.sh` (macOS only; fixture HOME, touches nothing
real): known-positive caches are planned, known-negative login paths are never listed and `apply` refuses a
hand-written plan naming them, and a `SingletonLock` profile is kept whole. Run it before loosening any rule above.

## Worktrees may be the only copy of something

Agents create linked worktrees (`git worktree add`) per task. On the reference machine 774 of them
held most of the 233 GB under `~/code` (up to 1 GB each); 500 had not been touched in a week. But a dirty worktree or one with unpushed commits
can be the only copy of real work, and no board signal says which. Removal therefore requires ALL of:

1. untouched for `HYG_WT_AGE_DAYS` — no regular file inside (outside `.git`) newer than the age, not
   just the directory mtime (editing a nested file would otherwise leave the top-level mtime old);
2. no process has its cwd inside (`lsof -d cwd`) — a live session may be parked there;
3. `.git` is a FILE (a linked worktree) and `git rev-parse --git-dir` differs from `--git-common-dir`
   (a submodule also has a `.git` file). A `.git` directory means a full clone, which is left alone —
   the enumerator prunes it and never lists it; the `session-dirs` pass below owns top-level clones under
   `HYG_SESSION_ROOT`. The common idiom `[ -d .git ]` is false for a worktree
   and is exactly the wrong test here;
4. `git status --porcelain` is empty — no modified, staged or untracked files;
5. HEAD is contained in a remote-tracking ref (`git branch -r --contains HEAD`), OR equals the head
   SHA of a merged pull request (`gh pr list --state merged --json headRefName,headRefOid`). The
   second branch exists because squash merges land content without making the branch commit an
   ancestor of `main`. OR the branch has a merged PR (same `headRefName`) and EVERY commit reachable
   from HEAD but from no remote ref (`git log HEAD --not --remotes`) has a subject equal to one of the
   PR's commit headlines (`gh pr view --json commits`), or starting with one that gh truncated with
   "…" (prefix ≥ 20 chars). Pipeline sessions rebase or force-push after the worktree's last commit,
   so the exact-SHA test alone kept 65 merged branches (21.9 GB) on the reference machine. One
   unmatched subject (work that landed under another title, or never landed) ⇒ KEPT. If `gh` is
   missing or fails, the merged-PR file is empty and the worktree is KEPT.

Scope: a direct child of `HYG_WT_ROOT` matching `HYG_WT_GLOB`, or a worktree at most `HYG_WT_DEPTH`
levels deep under a top-level dir named in `HYG_WT_NESTED` (default `wt _worktrees`: phase sessions create
`wt/{sup,ref,pipe}-*/...`, 163 GB in 842 dirs the direct-child scan never saw; other agents create
`_worktrees/<card>/`, 21 GB in 62 worktrees, card uO9PFYg8). A person's own
`~/code/project/feature` worktree is out of scope. `tests/hygiene-worktrees.test.sh` covers these rules
with fixture repos and a stubbed `gh`.

Removal uses `git worktree remove <path>` without `--force` (git refuses a dirty tree on its own as a
second line of defence) followed by `git worktree prune` in the main repository.

The first real run on the reference machine removed 420 worktrees / 133 GB and kept 80 — every kept
one was dirty, unpushed, in use, or a full clone.

## Session folders and full clones under `~/code/wt`

`session-dirs` evaluates every folder directly under `HYG_SESSION_ROOT` except a linked worktree, so a
**full clone parked there can be deleted**, after only `HYG_SESSION_AGE_HOURS` (24) idle. It is removed when
nobody's cwd is inside it, the routines registry does not call it alive, and it and every repo nested in it
pass `git_safe`: status empty including untracked files, no flagged index entries, no stash, every local ref
on a remote or in GitHub's default branch, no linked worktree outside the folder, no repo config outside the allow-list, no submodules, no `core.worktree` pointing elsewhere, no bare repo or separate git-dir.

A registry that cannot be read means every session is alive: no `jq`, bad JSON, a 0-byte file, or any shape
other than one array whose entries all carry a string `.session`. A missing registry means none is alive.

`build-artifacts` removes `node_modules`, `.next`, `dist`, `build`, `.turbo`, `coverage` from a session folder
idle `HYG_ARTIFACT_IDLE_HOURS`: inside a repo only when git-ignored with no tracked file; outside a repo only
`node_modules`, `.next` or `.turbo` beside a `package.json`. A dir holding any repo is kept.

**What these guards do not read, and which goes with the `rm -rf`:**

- ignored files in a clone, such as a local `.env`; keep anything you need outside `~/code/wt`;
- loose files in a plain session folder, outside any repo;
- commits only the reflog holds;
- commits held only by a stale remote-tracking ref: `branch -r --contains` reads local refs and never asks the remote;
- objects another clone borrows through alternates (`git clone --shared`): the borrower must re-fetch them.

## Paths are compared as strings, never as patterns

A worktree named `wt-[x` once slipped past a cwd check that used the path as a `grep` pattern (the `[`
made the expression invalid, grep exited 2, and the gate was silently skipped). The cwd set is now
read once per run and compared with `=` / a quoted `case` prefix. The apply gate also refuses any
path with a `.` or `..` component before any category check runs, and each category checks
`dirname`/`basename` equality rather than a glob that `*` could stretch across `/`.

## Session folders are judged by every repo inside them

`~/code/wt/<session>/` folders are created by pipeline and research sessions; once idle they hold
clones and worktrees nobody returns to. The `session-dirs` category removes the WHOLE folder with
`rm -rf`, so it needs evidence for everything in it:

1. no regular file (outside `.git`, `node_modules`, `.venv`, `Pods`) touched for `HYG_SESSION_AGE_HOURS`, and
   nobody's cwd inside;
2. no `HEAD` file outside a `.git` path (a bare repo or separate git-dir would go unchecked);
3. at least ONE nested repo. A folder with no git repo is research notes or review output, not a
   checkout: it is kept (`no-nested-repo`). Measured 2026-11-03: the earlier rule removed 150 such
   folders in one run on the reference Mac;
4. every nested repo passes `git_safe` with the folder as the deletion boundary: repo config outside the
   allow-list (see below) or submodules ⇒ kept unread; dirty ⇒ kept; a full
   clone with a stash or a local branch no remote ref (or the GitHub default branch) holds ⇒ kept; a full
   clone with a registered worktree (`.git/worktrees/*/gitdir`) that resolves OUTSIDE the folder and still
   exists, or is locked ⇒ kept (`clone-has-live-worktree-outside`: rm of the clone would orphan it —
   no HEAD, no index, no objects);
5. HEAD on a remote ref, in the GitHub default branch, or a merged PR (same tests as worktrees).

"A local branch of the parent repo holds this worktree's HEAD" (`branch-kept-in-parent-repo`) is
**gated** behind `HYG_SESSION_PARENT_BRANCH_OK=1`, default 0. It loosens rule 5 of the worktree model
("unpushed ⇒ KEPT"); the worktrees category never uses it. Turning it on by default is a separate,
explicit ruling.

`tests/hygiene-dev-caches.test.sh` holds the fixtures (no-repo folder kept, clone with an outside worktree
kept and that worktree still working, the gate off and on), and `tests/hygiene-port-combined.test.sh`
proves the worktrees pass and `session-dirs` never disagree in the destructive direction at their defaults.

## Repo config is an allow-list, not a deny-list (card w1t7IqUt)

Every repo here was made or cloned by an agent, and git reads its `.git/config` on every call `plan` and
`apply` make. At 923f715 two routes ran a program during a read-only `plan`, in a throwaway HOME with a canary
script, while the old deny-list of command-running keys passed the repo:

- `remote.origin.uploadpack` + `extensions.partialclone` + `remote.origin.promisor` with a locally missing
  object: git lazy-fetches and spawns the uploadpack program (`git status` hit it);
- `log.showSignature` + `gpg.program` with a local-only commit that carries a `gpgsig` header: the
  merged-PR subject check runs `git log` and git spawns the gpg program.

`repo_config_unvetted` therefore lists the keys of `$GIT_COMMON_DIR/config` and `$GIT_DIR/config.worktree` and
KEEPS the repo, unread, unless every key matches `CFG_ALLOW_RE` (core.* basics, remote url/fetch, branch
tracking, user.*, a few non-executing pull/push/fetch settings). A config git cannot list is kept too. Anything
else, including `include`/`includeIf`, `filter.*`, `gpg.*`, `credential.*`, any `extensions.*` other than
`worktreeConfig`, a hooks path, is kept. The cost is fewer removals for repos with exotic config; that is the
right direction. `GITS` still overrides `core.fsmonitor`, hooks, pager and external diff as a second layer, and
`apply` removes through `GITS` as well. `tests/hygiene-wt-safety.test.sh` holds one canary fixture per route
(plan and apply) and a control showing a gh-style config is not blocked.

Not covered: the window between `apply`'s check and its removal. A config written in that window is read by
the `git worktree remove` that follows (it runs `status` on the worktree under `GITS` overrides). Nothing in
bash closes it without a lock on the repo; the exposure is the same user's own processes writing the same
folder, and the folder was idle for 24 h / 7 d a moment earlier.

## A path is removed only if it is physical under its root (card w1t7IqUt)

`worktrees` is rooted at `HYG_WT_ROOT`; `session-dirs` and `build-artifacts` at `HYG_SESSION_ROOT`. The path in
a plan line is text; a symlink put where it points (the leaf, or any component) would make `git worktree remove`
or `rm -rf` act on the link's target. Reproduced at the merged head: a symlink `wt/x -> /elsewhere/worktree`,
old and pointing at a clean pushed worktree, passed `check_worktree` (find does not follow it, `-C` does) and
was removed with its target. `real_under_scope` now requires `physical(path) == physical(root)/<relative path>`
in `check_item` (plan and apply) and again in `remove_item`, right before the removal; anything else is
`path-has-symlink-component` and kept. `tests/hygiene-wt-safety.test.sh` proves a file outside survives apply
for a symlinked worktree path, a symlinked component, a symlinked session folder and a symlinked artifact path.

Remaining race, disclosed: bash has no `openat`/`O_NOFOLLOW`. Between the last resolution and the
`git worktree remove` / `rm -rf` call a component can still be swapped. The window is a few milliseconds and
needs a writer in `~/code` at that moment; every candidate was idle for 24 h / 7 d. It is not closed.

## What the guards do not read

- Ignored files inside a nested clone or worktree (a local `.env`): `git status` does not list them, so they
  go with the folder or worktree.
- A missing registry (`HYG_SESSIONS_JSON` absent) counts as "no session alive": only cwd and the idle window bind.
  An unreadable registry counts as "all alive".
- A session with no registry row counts as dead. The routines registry has had no new row since 2026-10-29 (last
  `started_at` 2026-10-29T12:42), so for every session started since, the liveness guard adds nothing and only
  the process-cwd check and the idle window (24 h; 7 d for worktrees) protect it.
- Reflog-only commits and commits held only by a stale remote-tracking ref.

## Developer caches

- `gradle`: `~/.gradle/wrapper/dists/*` and `daemon/*` older than `HYG_GRADLE_AGE_DAYS`, never the newest two,
  never a version a running process names. Re-downloadable; an offline build is the cost.
- `ios`: `iOS DeviceSupport/*` older than `HYG_DEVICE_SUPPORT_AGE_DAYS`, never the newest (Xcode re-copies it on
  connect); simulators only when their runtime is gone (`simctl delete`). Skipped while Xcode or Simulator runs.
  `Xcode/Archives` is never a candidate.
- `android`: `~/.android/cache/*` only. AVDs and SDK images are user data — reported, never removed.
- `pkg-caches`: `~/Library/Caches/CocoaPods` with no file newer than `HYG_PKG_CACHE_AGE_DAYS`.

## The run lock

`run` takes `HYG_LOCK` with an atomic `mkdir`; a lock older than 6 h is a crashed run and is taken over by
`rmdir` + `mkdir`, so its mtime restarts (otherwise every run in the next hours would "take over" too and
run concurrently). The lock is released with `rmdir`, never `rm -rf`: `HYG_LOCK` can come from config, and a
directory with content, a file or a symlink at that path is refused untouched.

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
