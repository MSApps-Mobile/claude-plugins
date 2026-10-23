#!/bin/bash
# Fixture test for janitor.sh — builds a fake ~/.claude with one positive and one negative per rule,
# plus every protected path, aged far past the threshold. Then:
#   1. dry run lists exactly the expected candidates and deletes nothing
#   2. apply removes exactly those, and every protected / negative path survives
# Run: bash plugins/claude-folder-janitor/tests/janitor.test.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
JANITOR="$HERE/../scripts/janitor.sh"
ROOT="$(cd "$(mktemp -d)" && pwd -P)"   # /var → /private/var on macOS; janitor reports resolved paths
trap 'rm -rf "$ROOT"' EXIT
C="$ROOT/claude"
FAIL=0
ok()   { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAIL=1; }
old()  { touch -t 202001010000 "$@"; }

# rule 1 — three backups, newest kept
mkdir -p "$C/backups"
for i in 1 2 3; do echo '{}' > "$C/backups/.claude.json.backup.17000000000$i"; done
touch -t 202001010001 "$C/backups/.claude.json.backup.170000000001"
touch -t 202001010002 "$C/backups/.claude.json.backup.170000000002"
touch -t 202001010003 "$C/backups/.claude.json.backup.170000000003"

# rule 2 — empty+old (remove), empty+fresh (keep), non-empty+old (keep)
mkdir -p "$C/session-env/empty-old" "$C/session-env/empty-fresh" "$C/session-env/full-old"
echo x > "$C/session-env/full-old/env"
old "$C/session-env/full-old/env" "$C/session-env/full-old" "$C/session-env/empty-old"

# rule 3 — changelog three patch releases behind the (pinned) installed version
mkdir -p "$C/cache"
printf '# Changelog\n\n## 2.1.200\n- x\n' > "$C/cache/changelog.md"

# rule 4 — projects
LIVE="$ROOT/live-project"; mkdir -p "$LIVE"
GONE="$ROOT/deleted-worktree"
enc() { local s="$1"; printf '%s' "${s//[^A-Za-z0-9]/-}"; }
mkdir -p "$C/projects/$(enc "$GONE")" "$C/projects/$(enc "$LIVE")" "$C/projects/$(enc "$ROOT/gone-but-fresh")" \
         "$C/projects/$(enc "$LIVE")-nocwd" "$C/projects/not-an-encoding"
printf '{"cwd":"%s"}\n' "$GONE" > "$C/projects/$(enc "$GONE")/s.jsonl"
printf '{"cwd":"%s"}\n' "$LIVE" > "$C/projects/$(enc "$LIVE")/s.jsonl"
printf '{"cwd":"%s"}\n' "$ROOT/gone-but-fresh" > "$C/projects/$(enc "$ROOT/gone-but-fresh")/s.jsonl"
mkdir -p "$LIVE-nocwd"   # exists on disk, transcripts carry no cwd → found by the encoded-name walk
echo '{}' > "$C/projects/$(enc "$LIVE")-nocwd/s.jsonl"
echo '{}' > "$C/projects/not-an-encoding/s.jsonl"
old "$C/projects/$(enc "$GONE")/s.jsonl" "$C/projects/$(enc "$GONE")" \
    "$C/projects/$(enc "$LIVE")/s.jsonl" "$C/projects/$(enc "$LIVE")" \
    "$C/projects/$(enc "$LIVE")-nocwd/s.jsonl" "$C/projects/$(enc "$LIVE")-nocwd" \
    "$C/projects/not-an-encoding/s.jsonl" "$C/projects/not-an-encoding"

# rule 4, safety — projects whose "no longer exists" cannot be trusted must never be listed:
#   a) the cwd sits under a mount root (/Volumes, /mnt, /media; overridden here) whose mount is missing
#   b) the nearest existing parent of the cwd cannot be searched, so existence cannot be determined
#   c) the mount folder EXISTS but is an empty leftover on the root disk (an unmounted static mount such as
#      Linux /mnt/data, or a stale /Volumes/X): it sits on the same device as its mount root, so the volume
#      is not mounted and the project's absence proves nothing
MNT="$ROOT/Volumes"   # stands in for /Volumes; NotMounted is deliberately absent
UNMOUNTED="$MNT/NotMounted/proj"
STALE="$MNT/StaleMount/proj"; mkdir -p "$MNT/StaleMount"   # exists, empty, same device as $MNT
LOCKED="$ROOT/locked"; LOCKED_CWD="$LOCKED/proj"
mkdir -p "$C/projects/$(enc "$UNMOUNTED")" "$C/projects/$(enc "$STALE")" "$C/projects/$(enc "$LOCKED_CWD")"
printf '{"cwd":"%s"}\n' "$UNMOUNTED" > "$C/projects/$(enc "$UNMOUNTED")/s.jsonl"
printf '{"cwd":"%s"}\n' "$STALE" > "$C/projects/$(enc "$STALE")/s.jsonl"
printf '{"cwd":"%s"}\n' "$LOCKED_CWD" > "$C/projects/$(enc "$LOCKED_CWD")/s.jsonl"
old "$C/projects/$(enc "$UNMOUNTED")/s.jsonl" "$C/projects/$(enc "$UNMOUNTED")" \
    "$C/projects/$(enc "$STALE")/s.jsonl" "$C/projects/$(enc "$STALE")" \
    "$C/projects/$(enc "$LOCKED_CWD")/s.jsonl" "$C/projects/$(enc "$LOCKED_CWD")"
#   d) the recorded cwd reaches an empty stale mount folder through a SYMLINK (~/ext -> /Volumes/Stale, cwd
#      ~/ext/proj): the text of the cwd is not under a mount root, but the place it really leads to is
#   e) memory-only projects (a memory/ folder, no transcript, so no recorded cwd) under that same symlink and
#      under an unreadable parent: with no cwd there is nothing to prove "gone" with, so they are kept
ALIAS="$ROOT/ext"; mkdir -p "$MNT/StaleAlias"; ln -s "$MNT/StaleAlias" "$ALIAS"   # empty, same device as $MNT
ALIAS_CWD="$ALIAS/proj"
MEM_ALIAS="$ALIAS/memproj"; MEM_LOCKED="$LOCKED/memproj"
mkdir -p "$C/projects/$(enc "$ALIAS_CWD")" "$C/projects/$(enc "$MEM_ALIAS")/memory" "$C/projects/$(enc "$MEM_LOCKED")/memory"
printf '{"cwd":"%s"}\n' "$ALIAS_CWD" > "$C/projects/$(enc "$ALIAS_CWD")/s.jsonl"
echo '# memory' > "$C/projects/$(enc "$MEM_ALIAS")/memory/MEMORY.md"
echo '# memory' > "$C/projects/$(enc "$MEM_LOCKED")/memory/MEMORY.md"
old "$C/projects/$(enc "$ALIAS_CWD")/s.jsonl" "$C/projects/$(enc "$ALIAS_CWD")" \
    "$C/projects/$(enc "$MEM_ALIAS")/memory/MEMORY.md" "$C/projects/$(enc "$MEM_ALIAS")/memory" "$C/projects/$(enc "$MEM_ALIAS")" \
    "$C/projects/$(enc "$MEM_LOCKED")/memory/MEMORY.md" "$C/projects/$(enc "$MEM_LOCKED")/memory" "$C/projects/$(enc "$MEM_LOCKED")"
mkdir -p "$LOCKED"; chmod 000 "$LOCKED"
trap 'chmod 755 "$LOCKED" 2>/dev/null; rm -rf "$ROOT"' EXIT

# protected — all old, none may ever be listed
mkdir -p "$C/skills/a" "$C/plugins/b" "$C/scheduled-tasks/c"
for f in CLAUDE.md settings.json settings.local.json history.jsonl skills/a/SKILL.md plugins/b/p.json scheduled-tasks/c/t.md; do
  echo x > "$C/$f"; old "$C/$f"
done

# JANITOR_MOUNT_ROOTS / JANITOR_DISK_REFS keep the fixture deterministic on macOS and Linux CI: no real
# /Volumes is needed, and the temp dir counts as "the same disk" even when /tmp is its own tmpfs.
export JANITOR_CLAUDE_DIR="$C" JANITOR_CLAUDE_VERSION="2.1.203" JANITOR_MIN_AGE_DAYS=7 \
       JANITOR_MOUNT_ROOTS="$MNT" JANITOR_DISK_REFS="$ROOT"
EXPECTED="backup	$C/backups/.claude.json.backup.170000000001
backup	$C/backups/.claude.json.backup.170000000002
changelog	$C/cache/changelog.md
orphan	$C/projects/$(enc "$GONE")
session-env	$C/session-env/empty-old"

echo "dry run"
OUT="$("$JANITOR" 2>/dev/null)"
GOT="$(printf '%s\n' "$OUT" | grep -v '^summary' | cut -f1,3 | LC_ALL=C sort)"
if [ "$GOT" = "$(printf '%s\n' "$EXPECTED" | LC_ALL=C sort)" ]; then ok "lists exactly the 5 expected candidates"
else fail "candidate mismatch"; echo "--- expected"; printf '%s\n' "$EXPECTED"; echo "--- got"; printf '%s\n' "$GOT"; fi
printf '%s\n' "$OUT" | grep -q $'^summary\tmode=dry-run\tcandidates=5\tremoved=0' && ok "summary: 5 candidates, 0 removed" || fail "dry-run summary"
[ -e "$C/backups/.claude.json.backup.170000000001" ] && [ -d "$C/session-env/empty-old" ] && [ -f "$C/cache/changelog.md" ] \
  && ok "dry run deleted nothing" || fail "dry run deleted something"

echo "unmounted volume / stale mount folder / unreadable parent"
printf '%s\n' "$GOT" | grep -qF -- "$(enc "$UNMOUNTED")" && fail "project on an unmounted volume was listed as an orphan" || ok "unmounted-volume project is not an orphan"
printf '%s\n' "$GOT" | grep -qF -- "$(enc "$STALE")" && fail "project under an empty stale mount folder (same device as its mount root) was listed as an orphan" || ok "stale-empty-mount-folder project is not an orphan"
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' "$GOT" | grep -qF -- "$(enc "$LOCKED_CWD")" && fail "project under an unreadable parent was listed" || ok "unreadable-parent project is not an orphan"
else
  echo "  - skipped unreadable-parent check (running as root)"
fi

echo "symlink alias to a stale mount / memory-only projects"
printf '%s\n' "$GOT" | grep -qF -- "$(enc "$ALIAS_CWD")" && fail "project reached through a symlink to an empty stale mount folder was listed as an orphan" || ok "symlink-to-stale-mount project is not an orphan"
printf '%s\n' "$GOT" | grep -qF -- "$(enc "$MEM_ALIAS")" && fail "memory-only project (no recorded cwd) under the symlink was listed as an orphan" || ok "memory-only project under the symlink is not an orphan"
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' "$GOT" | grep -qF -- "$(enc "$MEM_LOCKED")" && fail "memory-only project (no recorded cwd) under an unreadable parent was listed as an orphan" || ok "memory-only project under an unreadable parent is not an orphan"
else
  echo "  - skipped memory-only unreadable-parent check (running as root)"
fi

echo "changelog tolerance"
JANITOR_CLAUDE_VERSION="2.1.201" "$JANITOR" 2>/dev/null | grep -q '^changelog' && fail "one release behind was flagged" || ok "one release behind is kept"
JANITOR_CLAUDE_VERSION="2.1.199" "$JANITOR" 2>/dev/null | grep -q '^changelog' && fail "a newer cache was flagged" || ok "a cache newer than the install is kept"

echo "apply"
OUT="$("$JANITOR" apply 2>/dev/null)"
printf '%s\n' "$OUT" | grep -q $'^summary\tmode=apply\tcandidates=5\tremoved=5\tfailed=0' && ok "removed 5, failed 0" || { fail "apply summary"; printf '%s\n' "$OUT" | tail -1; }
for gone in "$C/backups/.claude.json.backup.170000000001" "$C/backups/.claude.json.backup.170000000002" \
            "$C/cache/changelog.md" "$C/projects/$(enc "$GONE")" "$C/session-env/empty-old"; do
  [ -e "$gone" ] && fail "still present: $gone"
done
for kept in "$C/backups/.claude.json.backup.170000000003" "$C/session-env/empty-fresh" "$C/session-env/full-old/env" \
            "$C/projects/$(enc "$LIVE")/s.jsonl" "$C/projects/$(enc "$ROOT/gone-but-fresh")/s.jsonl" \
            "$C/projects/$(enc "$LIVE")-nocwd/s.jsonl" "$C/projects/not-an-encoding/s.jsonl" \
            "$C/projects/$(enc "$UNMOUNTED")/s.jsonl" "$C/projects/$(enc "$LOCKED_CWD")/s.jsonl" \
            "$C/projects/$(enc "$STALE")/s.jsonl" "$C/projects/$(enc "$ALIAS_CWD")/s.jsonl" \
            "$C/projects/$(enc "$MEM_ALIAS")/memory/MEMORY.md" "$C/projects/$(enc "$MEM_LOCKED")/memory/MEMORY.md" \
            "$C/CLAUDE.md" "$C/settings.json" "$C/settings.local.json" "$C/history.jsonl" \
            "$C/skills/a/SKILL.md" "$C/plugins/b/p.json" "$C/scheduled-tasks/c/t.md"; do
  [ -e "$kept" ] || fail "removed something it must keep: $kept"
done
[ "$FAIL" -eq 0 ] && ok "every negative and protected path survived"

echo "second apply is a no-op"
"$JANITOR" apply 2>/dev/null | grep -q $'^summary\tmode=apply\tcandidates=0' && ok "nothing left to remove" || fail "second apply found candidates"

echo "bad usage"
"$JANITOR" --force >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown argument exits 2" || fail "unknown argument did not exit 2"

[ "$FAIL" -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
