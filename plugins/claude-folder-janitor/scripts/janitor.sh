#!/bin/bash
# claude-folder-janitor — dry-run-first cleanup of provably-safe clutter in ~/.claude/.
#
#   janitor.sh            dry run: list every candidate with size and reason, delete nothing
#   janitor.sh apply      re-derive the same candidates and delete exactly those
#
# Four rules, nothing else:
#   backup      ~/.claude/backups/.claude.json.backup.*  — all but the N newest (JANITOR_KEEP_BACKUPS, default 1)
#   session-env ~/.claude/session-env/<id>/              — empty, and untouched for JANITOR_MIN_AGE_DAYS (default 7)
#   changelog   ~/.claude/cache/changelog.md             — newest entry more than one release behind the installed Claude Code
#   orphan      ~/.claude/projects/<encoded-path>/       — the project directory no longer exists on disk, and the
#                                                          transcripts are untouched for JANITOR_MIN_AGE_DAYS
#
# Never touched, whatever a rule says: skills/, plugins/, scheduled-tasks/, CLAUDE.md, settings*.json,
# history.jsonl, and anything outside JANITOR_CLAUDE_DIR. assert_safe() enforces that on every path
# before it is listed and again before it is removed.
#
# Output: one TAB-separated line per candidate — rule, KB, path, reason — then a summary line.
# Exit: 0 ok · 2 bad usage or missing ~/.claude.

set -u

MODE="${1:-dry-run}"
case "$MODE" in
  dry-run|--dry-run) MODE="dry-run" ;;
  apply) ;;
  *) echo "usage: janitor.sh [apply]" >&2; exit 2 ;;
esac

CLAUDE_DIR="${JANITOR_CLAUDE_DIR:-$HOME/.claude}"
KEEP_BACKUPS="${JANITOR_KEEP_BACKUPS:-1}"
MIN_AGE_DAYS="${JANITOR_MIN_AGE_DAYS:-7}"

if [ ! -d "$CLAUDE_DIR" ]; then
  echo "janitor: $CLAUDE_DIR does not exist — nothing to do" >&2
  exit 2
fi
CLAUDE_DIR="$(cd "$CLAUDE_DIR" && pwd -P)"

START=$(date +%s)
CANDIDATES=()   # "rule<TAB>path<TAB>reason"

# ── safety ──────────────────────────────────────────────────────────────────
# A candidate must resolve inside CLAUDE_DIR, under one of the four rule roots, and must not be (or
# contain) a protected name. Returns non-zero instead of exiting so a single bad path is skipped,
# not fatal.
assert_safe() {
  local p="$1" real rel
  real="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)/$(basename "$p")" || return 1
  case "$real" in
    "$CLAUDE_DIR"/*) ;;
    *) return 1 ;;
  esac
  rel="${real#"$CLAUDE_DIR"/}"
  case "$rel" in
    backups/.claude.json.backup.*|session-env/*|cache/changelog.md|projects/*) ;;
    *) return 1 ;;
  esac
  case "/$rel/" in
    */skills/*|*/plugins/*|*/scheduled-tasks/*|*/CLAUDE.md/*|*/settings*.json/*|*/history.jsonl/*) return 1 ;;
  esac
  return 0
}

add() {  # rule path reason
  if assert_safe "$2"; then
    CANDIDATES+=("$1	$2	$3")
  else
    echo "janitor: refused unsafe path $2 (rule $1)" >&2
  fi
}

# "true" when nothing under $1 was modified in the last MIN_AGE_DAYS days.
# (find includes $1 itself, so this also covers an empty directory.)
untouched() {
  [ -z "$(find "$1" -mtime "-${MIN_AGE_DAYS}" -print 2>/dev/null | head -1)" ]
}

# ── rule 1: stale ~/.claude.json backups ────────────────────────────────────
rule_backups() {
  local dir="$CLAUDE_DIR/backups" n=0 f
  [ -d "$dir" ] || return 0
  # newest first by mtime; -A because every backup is a dotfile and plain ls hides them
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if [ "$n" -gt "$KEEP_BACKUPS" ]; then
      add backup "$dir/$f" "older than the $KEEP_BACKUPS newest .claude.json backup(s)"
    fi
  done < <(ls -1At "$dir" 2>/dev/null | grep '^\.claude\.json\.backup\.')
}

# ── rule 2: empty session-env dirs ─────────────────────────────────────────
rule_session_env() {
  local dir="$CLAUDE_DIR/session-env" d
  [ -d "$dir" ] || return 0
  for d in "$dir"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    [ -z "$(ls -A "$d" 2>/dev/null)" ] || continue
    untouched "$d" || continue
    add session-env "$d" "empty and untouched for ${MIN_AGE_DAYS}+ days"
  done
}

# ── rule 3: stale changelog cache ───────────────────────────────────────────
# Versions are x.y.z. "More than one release behind" = a different major.minor, or a patch gap > 1.
releases_behind() {  # cached installed → prints the gap, or -1 when cached is not behind
  local c="$1" i="$2" c1 c2 c3 i1 i2 i3
  IFS=. read -r c1 c2 c3 <<<"$c"
  IFS=. read -r i1 i2 i3 <<<"$i"
  if [ "$c1" -lt "$i1" ] || { [ "$c1" -eq "$i1" ] && [ "$c2" -lt "$i2" ]; }; then echo 99; return; fi
  if [ "$c1" -eq "$i1" ] && [ "$c2" -eq "$i2" ] && [ "$c3" -lt "$i3" ]; then echo $((i3 - c3)); return; fi
  echo -1
}

rule_changelog() {
  local f="$CLAUDE_DIR/cache/changelog.md" cached installed gap
  [ -f "$f" ] || return 0
  cached="$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' "$f" | cut -c4-)"
  installed="${JANITOR_CLAUDE_VERSION:-$(claude --version 2>/dev/null | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+')}"
  if [ -z "$cached" ] || [ -z "$installed" ]; then
    echo "janitor: changelog rule skipped (cached='${cached:-?}' installed='${installed:-?}')" >&2
    return 0
  fi
  gap="$(releases_behind "$cached" "$installed")"
  if [ "$gap" -gt 1 ]; then
    add changelog "$f" "cached changelog is $cached, installed Claude Code is $installed (regenerated on demand)"
  fi
}

# ── rule 4: orphaned project transcripts ────────────────────────────────────
# Claude Code names a project dir by replacing every non-alphanumeric character of its path with "-",
# which cannot be decoded unambiguously (/a/b-c and /a/b/c encode the same). So a project is an orphan
# only when BOTH say so:
#   1. the cwd recorded inside its transcripts (if any) does not exist, and
#   2. no existing directory on disk encodes to its name (a walk from / that follows every child whose
#      encoding is a prefix of the remaining name).
# Pure bash (no fork per child): the walk below runs this once per directory entry it visits.
encode() { local s="$1"; printf '%s' "${s//[^A-Za-z0-9]/-}"; }

path_exists_for() {  # dir remaining-encoded-name → 0 if some existing dir under $1 encodes to it
  local d="$1" rest="$2" c b e
  for c in "$d"/*/ "$d"/.*/; do
    c="${c%/}"
    b="${c##*/}"
    case "$b" in .|..|'*'|'.*') continue ;; esac
    [ -d "$c" ] || continue
    e="-${b//[^A-Za-z0-9]/-}"
    if [ "$rest" = "$e" ]; then return 0; fi
    case "$rest" in
      "$e"-*) path_exists_for "$c" "${rest#"$e"}" && return 0 ;;
    esac
  done
  return 1
}

recorded_cwd() {  # first "cwd" found in the first lines of the project's transcripts
  local f c
  for f in "$1"/*.jsonl; do
    [ -f "$f" ] || continue
    c="$(head -n 50 "$f" 2>/dev/null | grep -m1 -o '"cwd":"[^"]*"' | sed 's/^"cwd":"//; s/"$//')"
    if [ -n "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  return 0
}

rule_orphans() {
  local dir="$CLAUDE_DIR/projects" p name cwd
  [ -d "$dir" ] || return 0
  for p in "$dir"/*/; do
    p="${p%/}"
    [ -d "$p" ] || continue
    name="$(basename "$p")"
    case "$name" in -*) ;; *) continue ;; esac   # not a path encoding we understand — keep it
    cwd="$(recorded_cwd "$p")"
    if [ -n "$cwd" ] && [ -d "$cwd" ]; then continue; fi
    if path_exists_for "" "$name"; then continue; fi
    untouched "$p" || continue
    add orphan "$p" "project path ${cwd:-(decoded from $name)} no longer exists; transcripts untouched ${MIN_AGE_DAYS}+ days"
  done
}

rule_backups
rule_session_env
rule_changelog
rule_orphans

# ── report / apply ──────────────────────────────────────────────────────────
TOTAL_KB=0
REMOVED=0
FAILED=0
for line in ${CANDIDATES[@]+"${CANDIDATES[@]}"}; do
  IFS='	' read -r rule path reason <<<"$line"
  kb=$(du -sk "$path" 2>/dev/null | cut -f1)
  kb=${kb:-0}
  printf '%s\t%s\t%s\t%s\n' "$rule" "$kb" "$path" "$reason"
  TOTAL_KB=$((TOTAL_KB + kb))
  if [ "$MODE" = "apply" ]; then
    if assert_safe "$path" && rm -rf -- "$path"; then
      REMOVED=$((REMOVED + 1))
    else
      FAILED=$((FAILED + 1))
      echo "janitor: could not remove $path" >&2
    fi
  fi
done

ELAPSED=$(( $(date +%s) - START ))
COUNT=${#CANDIDATES[@]}
if [ "$MODE" = "apply" ]; then
  printf 'summary\tmode=apply\tcandidates=%d\tremoved=%d\tfailed=%d\tfreed_kb=%d\telapsed_s=%d\n' \
    "$COUNT" "$REMOVED" "$FAILED" "$TOTAL_KB" "$ELAPSED"
else
  printf 'summary\tmode=dry-run\tcandidates=%d\tremoved=0\treclaimable_kb=%d\telapsed_s=%d\n' \
    "$COUNT" "$TOTAL_KB" "$ELAPSED"
fi
