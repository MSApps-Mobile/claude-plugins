# claude-folder-janitor

**Dry-run-first cleanup of `~/.claude`.** Lists provably-safe clutter (old `.claude.json` backups, empty
`session-env` folders, a stale changelog cache, and transcripts of projects whose folders no longer exist)
with size and reason. Deletes only when you run `/janitor apply`.

## What It Does

On the machine this was built on, `~/.claude/projects` held transcripts for 815 project folders. 593 of
them pointed at folders that no longer existed (mostly deleted git worktrees). There were also 1,225 empty
`session-env` folders. The dry run listed 1,818 candidates (about 223 MB) in 32 seconds and deleted nothing.

| Command | What happens |
|---|---|
| `/janitor` | Dry run. One line per candidate: rule, KB, path, reason. Then a summary. |
| `/janitor apply` | Re-derives the same list and deletes exactly those paths. Reports removed, failed, KB freed, elapsed. |

## The four rules

| Rule | Eligible when |
|---|---|
| `backup` | a `~/.claude/backups/.claude.json.backup.*` file is not among the newest N (default 1) |
| `session-env` | a `~/.claude/session-env/<id>/` folder is empty and untouched for 7 days |
| `changelog` | `~/.claude/cache/changelog.md` is more than one release behind the installed Claude Code |
| `orphan` | a `~/.claude/projects/<path>/` folder's project no longer exists on disk and its transcripts are untouched for 7 days |

A project is an orphan only when the `cwd` recorded in its transcripts is missing **and** no existing
folder on disk encodes to its name. The name encoding is lossy (`/a/b-c` and `/a/b/c` look the same), so
the janitor checks every possible match before calling a project orphaned.

**Unclear means keep.** A missing folder on an unmounted disk looks exactly like a deleted one, so "missing"
is only believed when it is provable:

- the transcripts record a `cwd`. A project with none (a memory-only project, for example) is always kept:
  its folder name alone cannot say where it lived or whether that disk is mounted;
- the nearest existing parent folder, resolved to its real path (symlinks followed, so `~/ext -> /Volumes/X`
  counts as `/Volumes/X`), can be listed, is not empty (an empty folder may be an unmounted mount point
  such as Linux `/data`), and is on the same disk as `/` or `$HOME`; and
- neither the recorded `cwd` nor that real parent sits under a mount root (`/Volumes`, `/mnt`, `/media`)
  whose volume is not provably mounted. A volume counts as mounted only when its folder's device id is
  known and differs from the mount root's. An empty leftover folder (an unmounted `/mnt/data`, a stale
  `/Volumes/X`) sits on the root disk, so its projects are kept.

If any of this cannot be determined, the project is kept.

## Never touched

`skills/`, `plugins/`, `scheduled-tasks/`, `CLAUDE.md`, `settings*.json`, `history.jsonl`, and anything
outside `~/.claude`. Each path is checked before it is listed and again before it is removed.

## Prerequisites

- macOS or Linux with bash 3.2+ (the macOS system bash works). No other dependencies.
- `claude` on `PATH` for the changelog rule. Without it, that rule is skipped and says so.

## Settings

Environment variables: `JANITOR_CLAUDE_DIR`, `JANITOR_KEEP_BACKUPS` (1), `JANITOR_MIN_AGE_DAYS` (7),
`JANITOR_CLAUDE_VERSION`, plus two for the orphan rule's mount check:

- `JANITOR_MOUNT_ROOTS`: extra space-separated folders whose children are mount points. They are added to
  `/Volumes /mnt /media`, which always apply.
- `JANITOR_DISK_REFS` (`/ $HOME`): space-separated paths; a missing project counts as gone only when its
  nearest existing parent is on the same device as one of them. A blank value means the default.

## Tests

```bash
bash plugins/claude-folder-janitor/tests/janitor.test.sh
```

Builds a fake `~/.claude` with one eligible and one ineligible case per rule, plus every protected path,
all aged past the threshold. It also covers the keep cases: a missing mount, an empty stale mount folder on
the root disk, a symlink to such a folder, an unreadable parent, an empty parent, and memory-only projects
with no recorded `cwd`, plus a gone project on a really mounted volume that must still be listed. Checks that the dry run lists exactly the eligible five and deletes nothing,
that apply removes exactly those five, and that every protected and ineligible path survives.

## Install

```
/plugin install claude-folder-janitor@msapps-plugins
```

## License

MIT

