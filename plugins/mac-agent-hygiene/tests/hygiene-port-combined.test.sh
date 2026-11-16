#!/bin/bash
# hygiene-port-combined.test.sh — card JQ96IKNK: main's worktree scope (#67, #81) and #66's session-dirs
# run TOGETHER at their defaults, against the REAL scripts/hygiene.sh, and never disagree in the
# destructive direction.
#
# One session ~/code/wt/pipe-combo holds two linked worktrees of a parent repo that lives outside it:
#   KNOWN-POSITIVE  wt/pipe-combo/pushed    clean, HEAD on a remote ref     → worktrees: remove pushed
#   KNOWN-NEGATIVE  wt/pipe-combo/held      clean, commit only on a local parent branch
#                                                                            → worktrees: keep unpushed-commits
#   KNOWN-NEGATIVE  the session folder itself (HYG_SESSION_PARENT_BRANCH_OK default 0)
#                                                                            → session-dirs: keep nested-unpushed-commits
#   apply           removes the pushed worktree only; the held worktree, its commit and the folder survive
#
# Nothing here touches the real HOME. lsof is required (missing ⇒ hygiene.sh keeps everything: fail closed).
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-combined-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
# Default worktree scope AND default session-dirs: only the unrelated categories are pointed away.
unset HYG_WT_ROOT HYG_WT_GLOB HYG_WT_NESTED HYG_WT_DEPTH HYG_SESSION_ROOT HYG_SESSION_PARENT_BRANCH_OK
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_GRADLE_HOME="$HOME/gr-none"
export HYG_DEVICE_SUPPORT="$HOME/ds-none" HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/an-none" HYG_PKG_CACHES=""
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=0 HYG_GIT="$GITBIN" HYG_GH="" HYG_LOCK="$FX/lock"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
commit(){ echo "$2" > "$1/$(echo "$2" | tr -c 'a-zA-Z0-9\n' _)"; q -C "$1" add -A; q -C "$1" commit -qm "$2"; }

ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
commit "$MAIN" "initial"; q -C "$MAIN" push -q origin HEAD:main

SESS="$CODE/wt/pipe-combo"; mkdir -p "$SESS"
PUSHED="$SESS/pushed"; q -C "$MAIN" worktree add -q -b combo-pushed "$PUSHED"; commit "$PUSHED" "pushed work"; q -C "$PUSHED" push -q origin combo-pushed
HELD="$SESS/held"; q -C "$MAIN" worktree add -q -b combo-held "$HELD"; commit "$HELD" "local only work"
HELD_SHA="$("$GITBIN" -C "$HELD" rev-parse HEAD)"
q -C "$MAIN" fetch -q origin
find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
row(){ awk -F'\t' -v c="$1" -v p="$2" '$1==c && $5==p {print $2" "$4}' "$PLAN"; }
expect(){ local got; got="$(row "$1" "$2")"
  if [ "$got" = "$3" ]; then ok "$4: $3"; else bad "$4: expected '$3', got '${got:-<not listed>}'"; fi; }
expect worktrees    "$PUSHED" "remove pushed"                      "worktrees pass, pushed worktree"
expect worktrees    "$HELD"   "keep unpushed-commits"              "worktrees pass, branch-held worktree"
expect session-dirs "$SESS"   "keep nested-unpushed-commits"       "session-dirs, folder holding the branch-held worktree"

awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"
printf 'session-dirs\t%s\n' "$SESS" >> "$FX/real.tsv"   # hand-written: must be refused
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1
[ ! -e "$PUSHED" ] && ok "apply removed the pushed worktree" || bad "pushed worktree still present"
[ -d "$HELD" ] && [ "$("$GITBIN" -C "$HELD" rev-parse HEAD 2>/dev/null)" = "$HELD_SHA" ] && ok "branch-held worktree and its commit survive" || bad "held worktree lost"
awk -F'\t' -v p="$SESS" '$1=="session-dirs" && $2=="refused" && $5==p{f=1} END{exit !f}' "$FX/apply.out" && [ -d "$SESS" ] \
  && ok "apply refused the session folder" || bad "session folder not refused: $(cat "$FX/apply.out")"
"$GITBIN" -C "$MAIN" rev-parse -q --verify refs/heads/combo-pushed >/dev/null && ok "branch combo-pushed survives removal" || bad "branch combo-pushed gone"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
