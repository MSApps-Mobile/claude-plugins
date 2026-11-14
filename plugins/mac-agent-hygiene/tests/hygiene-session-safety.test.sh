#!/bin/bash
# hygiene-session-safety.test.sh — card JQ96IKNK security rework (delete logic and the run lock), against
# the REAL scripts/hygiene.sh in a throwaway HOME (Linux and macOS):
#
#   KNOWN-NEGATIVE  a stale session folder whose only repo is clean + pushed but which ALSO holds loose
#                   files beside it (a prompt, notes in a subfolder, a script, a .tgz, JSON output) → keep
#                   (loose-files-outside-repos); a hand-written apply is refused and every file survives
#   KNOWN-POSITIVE  the same folder holding only .DS_Store and __pycache__ beside the repo → remove
#   KNOWN-NEGATIVE  a clean pushed clone whose core.worktree points at ANOTHER (clean) tree while its own
#                   folder holds untracked work → keep unread (status would judge the wrong tree); the
#                   work survives a hand-written apply
#   KNOWN-NEGATIVE  with HYG_LOCK unset the lock is per user: ${TMPDIR}/mac-agent-hygiene-<uid>.lock
#   KNOWN-NEGATIVE  an existing empty lock directory owned by another user is refused (rc 2), not taken over
#
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp /usr/bin/id; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-session-safety.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
export HYG_WT_ROOT="$CODE" HYG_WT_NESTED="wt" HYG_WT_DEPTH=3 HYG_SESSION_ROOT="$CODE/wt" HYG_SESSION_PARENT_BRANCH_OK=0
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_GRADLE_HOME="$HOME/gr-none"
export HYG_DEVICE_SUPPORT="$HOME/ds-none" HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/an-none" HYG_PKG_CACHES=""
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=0 HYG_GIT="$GITBIN" HYG_GH=""
unset HYG_LOCK

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
act(){ awk -F'\t' -v c="$1" -v p="$2" '$1==c && $5==p {print $2" "$4}' "$3"; }

ORIGIN="$FX/origin.git"; q init -q --bare "$ORIGIN"
# A session folder holding one clean, pushed full clone.
mksession(){ local s="$CODE/wt/$1"; mkdir -p "$s"; q clone -q "$ORIGIN" "$s/repo"
  echo "$1" > "$s/repo/f"; q -C "$s/repo" add f; q -C "$s/repo" commit -qm "$1"; q -C "$s/repo" push -q origin HEAD:refs/heads/"$1"; }

# --- loose files beside a clean pushed repo
mksession loose; L="$CODE/wt/loose"
echo "the prompt" > "$L/PROMPT.md"; mkdir -p "$L/notes"; echo '{"a":1}' > "$L/notes/result.json"
printf '#!/bin/sh\necho hi\n' > "$L/run.sh"; echo tgz > "$L/bundle.tgz"
mksession loose-deep; mkdir -p "$CODE/wt/loose-deep/out/a/b"; echo r > "$CODE/wt/loose-deep/out/a/b/report.txt"
# --- only regenerable junk beside the repo
mksession junk-only; J="$CODE/wt/junk-only"; echo x > "$J/.DS_Store"; mkdir -p "$J/__pycache__"; echo c > "$J/__pycache__/m.cpython-312.pyc"
# --- core.worktree redirect: status judges a clean copy elsewhere, the folder's own tree holds work
mksession redirect; RD="$CODE/wt/redirect/repo"
mkdir -p "$FX/elsewhere"; cp "$RD/f" "$FX/elsewhere/f"
q -C "$RD" config core.worktree "$FX/elsewhere"; echo "only copy" > "$RD/wip.txt"
find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
[ "$(act session-dirs "$L" "$PLAN")" = "keep loose-files-outside-repos" ] \
  && ok "loose files beside a clean pushed repo → keep" || bad "loose: '$(act session-dirs "$L" "$PLAN")'"
[ "$(act session-dirs "$CODE/wt/loose-deep" "$PLAN")" = "keep loose-files-outside-repos" ] \
  && ok "a loose file three folders down → keep" || bad "loose-deep: '$(act session-dirs "$CODE/wt/loose-deep" "$PLAN")'"
[ "$(act session-dirs "$J" "$PLAN")" = "remove stale-session-all-nested-pushed" ] \
  && ok "only .DS_Store and __pycache__ beside the repo → remove" || bad "junk-only: '$(act session-dirs "$J" "$PLAN")'"
[ "$(act session-dirs "$CODE/wt/redirect" "$PLAN" | cut -d' ' -f1)" = keep ] \
  && ok "core.worktree redirect → keep ($(act session-dirs "$CODE/wt/redirect" "$PLAN" | cut -d' ' -f2))" || bad "redirect: '$(act session-dirs "$CODE/wt/redirect" "$PLAN")'"

awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/apply.tsv"
printf 'session-dirs\t%s\nsession-dirs\t%s\nsession-dirs\t%s\n' "$L" "$CODE/wt/loose-deep" "$CODE/wt/redirect" >> "$FX/apply.tsv"   # hand-written: must be refused
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
[ -f "$L/PROMPT.md" ] && [ -f "$L/notes/result.json" ] && [ -f "$L/run.sh" ] && [ -f "$L/bundle.tgz" ] && [ -f "$CODE/wt/loose-deep/out/a/b/report.txt" ] \
  && ok "apply refused the loose-file folders; every loose file survives" || bad "loose files lost: $(cat "$FX/apply.out")"
[ -f "$RD/wip.txt" ] && ok "apply refused the core.worktree folder; its work survives" || bad "redirect work lost: $(cat "$FX/apply.out")"
[ ! -e "$J" ] && ok "apply removed the junk-only session" || bad "junk-only still there: $(cat "$FX/apply.out")"

# --- the run lock
UIDN="$(/usr/bin/id -u)"; mkdir -p "$FX/tmp"
mkdir "$FX/tmp/mac-agent-hygiene-$UIDN.lock"          # fresh: a run of THIS user holds it
TMPDIR="$FX/tmp" bash "$HYG" run >/dev/null 2>&1
grep -q "skipped: previous run still holds $FX/tmp/mac-agent-hygiene-$UIDN.lock" "$HYG_LOG" && [ ! -e "$FX/tmp/mac-agent-hygiene.lock" ] \
  && ok "HYG_LOCK unset → per-user lock \$TMPDIR/mac-agent-hygiene-<uid>.lock" || bad "default lock is not per user: $(tail -3 "$HYG_LOG")"
rmdir "$FX/tmp/mac-agent-hygiene-$UIDN.lock" 2>/dev/null
FOREIGN=""
for c in /var/empty /usr/share/empty; do
  [ -d "$c" ] && [ ! -L "$c" ] && [ ! -O "$c" ] && [ -z "$(ls -A "$c" 2>/dev/null)" ] && { FOREIGN="$c"; break; }
done
if [ -n "$FOREIGN" ]; then
  HYG_LOCK="$FOREIGN" bash "$HYG" run >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && grep -q "run refused: $FOREIGN .*not owned" "$HYG_LOG" \
    && ok "an empty lock dir another user owns ($FOREIGN) → refused (rc=2)" || bad "foreign lock not refused (rc=$rc): $(tail -2 "$HYG_LOG")"
else ok "foreign-lock: SKIP (no empty directory owned by another user on this host)"; fi

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
