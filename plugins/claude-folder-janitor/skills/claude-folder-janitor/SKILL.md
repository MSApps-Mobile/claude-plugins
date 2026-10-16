---
name: claude-folder-janitor
description: This skill should be used when the user asks to "clean up ~/.claude", "my .claude folder is huge", "delete old Claude transcripts", "remove orphaned projects", "free space in .claude", "run the janitor", or when ~/.claude/projects or ~/.claude/session-env has grown large. Lists provably-safe clutter in ~/.claude with size and reason, and deletes it only on an explicit apply.
version: 0.1.0
---

# Claude Folder Janitor

## Purpose and boundaries

`~/.claude/` grows quietly. Most of it is session transcripts in `projects/`, and many of those belong to
folders that no longer exist (deleted git worktrees, scratch directories). Claude Code also leaves empty
`session-env/` folders and old `.claude.json` backups behind. This skill removes only those, and only
after showing the list.

## When to use

- The user asks to clean, shrink or tidy `~/.claude`, or to remove old or orphaned transcripts.
- A disk check shows `~/.claude/projects` or `~/.claude/session-env` taking real space.

## Procedure: plan, confirm, apply, verify

1. **Dry run first, always.** Run `/janitor` (or `bash "${CLAUDE_PLUGIN_ROOT}/scripts/janitor.sh"`).
   Nothing is deleted. Each line is `rule<TAB>KB<TAB>path<TAB>reason`, then one `summary` line.
2. **Show the user the list** grouped by rule, with sizes and the reclaimable total.
3. **Apply only after the user confirms.** `/janitor apply` re-derives the same list and deletes exactly
   those paths, then prints removed, failed, KB freed and elapsed seconds.
4. **Verify.** Report the summary line. If `failed` is not 0, show the stderr lines; a second dry run
   should list nothing that was just removed.

## What is eligible (four rules, nothing else)

| Rule | Path | Eligible when |
|---|---|---|
| `backup` | `~/.claude/backups/.claude.json.backup.*` | not among the newest `JANITOR_KEEP_BACKUPS` (default 1) |
| `session-env` | `~/.claude/session-env/<id>/` | empty and untouched for `JANITOR_MIN_AGE_DAYS` (default 7) |
| `changelog` | `~/.claude/cache/changelog.md` | its newest entry is more than one release behind `claude --version` (Claude Code fetches it again when needed) |
| `orphan` | `~/.claude/projects/<encoded-path>/` | the `cwd` recorded in its transcripts does not exist, **and** no existing folder encodes to its name, **and** nothing in it changed for `JANITOR_MIN_AGE_DAYS` |

The orphan rule needs both checks because a project folder name replaces every non-alphanumeric character
with `-`, so `/a/b-c` and `/a/b/c` encode the same. The janitor walks the disk following every folder
whose encoding matches; if any exists, the project is kept.

## Never touched

`skills/`, `plugins/`, `scheduled-tasks/`, `CLAUDE.md`, `settings*.json`, `history.jsonl`, and anything
outside `~/.claude`. Every candidate is checked against this before it is listed and again before it is
removed; a path that fails is reported on stderr and skipped.

## Settings (environment variables)

- `JANITOR_CLAUDE_DIR` — folder to clean (default `~/.claude`)
- `JANITOR_KEEP_BACKUPS` — backups to keep (default `1`)
- `JANITOR_MIN_AGE_DAYS` — age threshold for `session-env` and `orphan` (default `7`)
- `JANITOR_CLAUDE_VERSION` — overrides `claude --version` for the changelog rule

## Not in this version

No Notion log, no schedule, no trash folder with a restore window, no transcript compression. Deletion is
permanent, which is why the dry run comes first.
