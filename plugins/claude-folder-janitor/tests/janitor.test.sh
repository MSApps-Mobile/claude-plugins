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

# protected — all old, none may ever be listed
mkdir -p "$C/skills/a" "$C/plugins/b" "$C/scheduled-tasks/c"
for f in CLAUDE.md settings.json settings.local.json history.jsonl skills/a/SKILL.md plugins/b/p.json scheduled-tasks/c/t.md; do
  echo x > "$C/$f"; old "$C/$f"
done

export JANITOR_CLAUDE_DIR="$C" JANITOR_CLAUDE_VERSION="2.1.203" JANITOR_MIN_AGE_DAYS=7
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
