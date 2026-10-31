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
- Worktrees: linked (`[ -f .git ]`), untouched > age, nobody's cwd, clean, pushed or merged-PR head.
  `gh` failure ⇒ keep. Never `--force`.
- DerivedData skipped while Xcode builds. Never sudo. Paths outside `$HOME` refused at apply.
- Session dirs (every `~/code/wt/*` except a linked worktree; a top-level full clone is one too): kept whole if the clone
  or ANY nested repo fails the worktree test, the session is alive in `HYG_SESSIONS_JSON`, or anything was touched < 24 h.
  A full clone additionally fails (KEEP) when any of its registered linked worktrees resolves outside the folder (their
  git data lives in the clone's `.git`), when any local ref outside `refs/remotes` (branch, tag, notes, ...) points at a
  commit no remote ref contains, or when `worktree list`/`for-each-ref` fails. `status` runs with
  `--untracked-files=all`, so a repo's `status.showUntrackedFiles=no` cannot hide untracked files.
- Build artifacts (`node_modules .next dist build .turbo coverage` inside `~/code/wt/<session>`): only when the session
  is idle 24 h, nobody's cwd, not alive in the registry, the dir holds no `.git`, and git IGNORES it with no tracked file
  (no repo: node_modules/.next/.turbo beside package.json only). An unreadable registry ⇒ every session alive.
- Gradle: never the newest two versions or one a running process names. iOS: never the newest DeviceSupport,
  never a simulator whose runtime is installed, never `Xcode/Archives`. Android AVDs / SDK images: report only.
- `run` holds a mkdir lock so a 4-hourly run never overlaps a slow one (stale after 6 h).
- System binaries by absolute path; explicit PATH in the plist; `mktemp` with a `${TMPDIR:-/tmp}` template.
- Paths compared as fixed strings (never a grep pattern); `.`/`..` components refused at the apply gate; every
  category checks `dirname`/`basename`, not a glob across `/`. Environment > config file > defaults.

## Testing

```bash
bash -n scripts/*.sh && node --check server/index.js
bash tests/hygiene-keeps-logins.test.sh && bash tests/hygiene-dev-caches.test.sh && bash tests/hygiene-wt-artifacts.test.sh && bash tests/hygiene-git-safe-keep.test.sh   # macOS fixtures, throwaway HOME
bash scripts/hygiene.sh status
bash scripts/hygiene.sh plan | awk -F'\t' '{print $1, $2, $4}' | sort | uniq -c
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | node server/index.js
```

## Known issues

- The SingletonLock check is existence-only; a stale lock from a crashed browser makes that profile
  skip forever (safe, silent). Classifying stale locks is a possible follow-up — never by deleting the lock.
- Merged-PR detection is GitHub-only (`gh`). Other forges fall back to pushed-only.
