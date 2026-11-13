# mac-agent-hygiene — notes for agents working on this plugin

## Architecture

- `scripts/hygiene.sh` is the only place that decides what is removable. `check_item <category> <path>`
  is called by `plan` (labels candidates) and again by `apply` (re-validates every path in the plan
  file before removing). Do not add a second code path that deletes.
- `server/index.js` frames stdio JSON-RPC for MCP with no dependencies. It keeps plans in memory for
  30 minutes keyed by a hash of the remove-set; `hygiene_apply` requires a live `plan_id` and
  `confirm: true`, writes the remove-set to a 0600 temp file and calls `hygiene.sh apply`.
- `scripts/install-launchd.sh` copies `hygiene.sh` to `~/.local/share/mac-agent-hygiene/` (stable path;
  the plugin cache path moves on every update), renders `launchagent.plist.template` by bash
  substitution (no sed — `&`/`#` in `$HOME` are safe), then `bootout` + `bootstrap` (retried) and
  verifies the loaded job path. It adopts (unloads) the hand-rolled predecessor `com.opsagents.dev-cache-cleanup` if present.

## Invariants (do not relax)

- Browser profiles: cache-subfolder allowlist only; profile with `SingletonLock` or open files skipped.
- Worktrees: linked (`[ -f .git ]` AND git-dir ≠ common-dir), in scope (direct child matching
  `HYG_WT_GLOB`, or ≤ `HYG_WT_DEPTH` deep under a `HYG_WT_NESTED` dir), untouched > age, nobody's cwd,
  clean, and pushed / merged-PR head / merged PR on the same branch whose commits cover every local-only
  commit subject. `gh` failure ⇒ keep. Never `--force`. macOS `/bin/bash` is 3.2: no `declare -A`;
  per-repo gh results are cache files in `$TMPD`.
- DerivedData skipped while Xcode builds. Never sudo. Paths outside `$HOME` refused at apply.
- One `git_safe dir bound allow_parent_branch` judges every repo (worktrees pass `0`): repo config with ANY key outside
  the `CFG_ALLOW_RE` allow-list (never a deny-list: uploadpack+partial clone and showSignature+gpg.program ran a program
  during `plan`), submodules, dirty, a full clone's stash / unpushed branch / registered worktree outside `bound` ⇒ keep.
- Session dirs (every `~/code/wt/*` except a linked worktree; a top-level full clone is one too): kept whole if the clone
  or ANY nested repo fails the worktree test, there is no repo at all (`no-nested-repo`), the session is alive in `HYG_SESSIONS_JSON`, or anything was touched < 24 h.
  A plain folder is also kept whole if ANY regular file lives outside its nested repos (`loose-files-outside-repos`; `__pycache__` / `.DS_Store` excepted).
  A full clone additionally fails (KEEP) when any of its registered linked worktrees resolves outside the folder (their
  git data lives in the clone's `.git`), when any local ref outside `refs/remotes` (branch, tag, notes, ...) points at a
  commit no remote ref contains, or when `worktree list`/`for-each-ref` fails. `status` runs with
  `--untracked-files=all`, so a repo's `status.showUntrackedFiles=no` cannot hide untracked files.
  Any repo (clone, nested, linked worktree) also fails when the index flags a file assume-unchanged or skip-worktree
  (`ls-files -v` lowercase or `S`: status cannot see edits to it, and a sparse checkout counts), or when its physical
  `rev-parse --show-toplevel` is not the repo folder itself (`core.worktree` elsewhere: the folder's own files are checked nowhere).
  "Held by a parent-repo branch" counts only with `HYG_SESSION_PARENT_BRANCH_OK=1` (default 0): it loosens "unpushed ⇒ KEPT" and needs an explicit ruling to turn on.
- Worktrees honour the registry like every pass (`session-alive-in-registry`, on the worktree and its top-level session
  folder). A path is removed only if `real_under_scope` says it is physical under its root (no symlink leaf or component),
  checked in plan, in apply, and again right before the removal. lsof comes from `$LSOF` (`HYG_LSOF`, else
  `/usr/sbin/lsof` or `/usr/bin/lsof`); none, a non-zero exit (even after some rows), or no cwd printed ⇒ blind ⇒ every folder counts as occupied.
- Build artifacts (`node_modules .next dist build .turbo coverage` inside `~/code/wt/<session>`): only when the session
  is idle 24 h, nobody's cwd, not alive in the registry, the dir holds no `.git`, bare repo or separate git-dir (any `HEAD`
  file or symlink), it lies inside the work tree git resolves (not a `core.worktree` elsewhere), that work tree's top level is the session
  folder or below it (a repo above, e.g. a dotfiles `~/.git`, keeps it: `repo-above-session-folder`), and git IGNORES it with no tracked file
  (no repo: node_modules/.next/.turbo beside package.json only; a `.git` entry at ANY level up to the session folder that
  git cannot read keeps it: `git-cannot-read-repo`). An unreadable registry ⇒ every session alive.
- `GITS` pins `log.showSignature=false` as a second layer behind the allow-list.
- Gradle: never the newest two versions or one a running process names. iOS: never the newest DeviceSupport,
  never a simulator whose runtime is installed, never `Xcode/Archives`. Android AVDs / SDK images: report only.
- `run` holds a mkdir lock so a 4-hourly run never overlaps a slow one (stale after 6 h; a takeover re-creates it so
  its mtime restarts). The lock is released with `rmdir`, never `rm -rf`; a non-empty or non-directory `HYG_LOCK` is refused,
  and so is one another user owns. Default path is per user: `${TMPDIR:-/tmp}/mac-agent-hygiene-<uid>.lock`.
- System binaries by absolute path; explicit PATH in the plist; `mktemp` with a `${TMPDIR:-/tmp}` template.
- Paths compared as fixed strings (never a grep pattern); `.`/`..` components refused at the apply gate; every
  category checks `dirname`/`basename`, not a glob across `/`. Environment > config file > defaults.

## Testing

```bash
bash -n scripts/*.sh && node --check server/index.js
bash tests/hygiene-worktrees.test.sh        # fixture git repos + stubbed gh; runs on Linux too
bash tests/hygiene-wt-scan-roots.test.sh    # default scope incl. ~/code/_worktrees, keep rules, status count
bash tests/hygiene-port-combined.test.sh    # worktrees + session-dirs at their defaults never disagree destructively
bash tests/hygiene-keeps-logins.test.sh && bash tests/hygiene-dev-caches.test.sh && bash tests/hygiene-wt-artifacts.test.sh && bash tests/hygiene-git-safe-keep.test.sh && bash tests/hygiene-wt-safety.test.sh   # macOS fixtures, throwaway HOME
bash tests/hygiene-git-exec-guard.test.sh   # log.showSignature + gpg.program never run during plan
bash tests/hygiene-session-safety.test.sh   # loose files / core.worktree keep a session; per-user, owned run lock
bash tests/hygiene-wt-ancestor-repo.test.sh # a ~/.git or ~/code/.git never answers for a session folder's build/ dist/
bash scripts/hygiene.sh status
bash scripts/hygiene.sh plan | awk -F'\t' '{print $1, $2, $4}' | sort | uniq -c
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | node server/index.js
```

## Known issues

- The SingletonLock check is existence-only; a stale lock from a crashed browser makes that profile
  skip forever (safe, silent). Classifying stale locks is a possible follow-up — never by deleting the lock.
- Merged-PR detection is GitHub-only (`gh`). Other forges fall back to pushed-only.
