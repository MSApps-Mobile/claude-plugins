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

## Never touched

`skills/`, `plugins/`, `scheduled-tasks/`, `CLAUDE.md`, `settings*.json`, `history.jsonl`, and anything
outside `~/.claude`. Each path is checked before it is listed and again before it is removed.

## Prerequisites

- macOS or Linux with bash 3.2+ (the macOS system bash works). No other dependencies.
- `claude` on `PATH` for the changelog rule. Without it, that rule is skipped and says so.

## Settings

Environment variables: `JANITOR_CLAUDE_DIR`, `JANITOR_KEEP_BACKUPS` (1), `JANITOR_MIN_AGE_DAYS` (7),
`JANITOR_CLAUDE_VERSION`.

## Tests

```bash
bash plugins/claude-folder-janitor/tests/janitor.test.sh
```

Builds a fake `~/.claude` with one eligible and one ineligible case per rule, plus every protected path,
all aged past the threshold. Checks that the dry run lists exactly the eligible five and deletes nothing,
that apply removes exactly those five, and that every protected and ineligible path survives.

## Install

```
/plugin install claude-folder-janitor@msapps-plugins
```

## License

MIT
