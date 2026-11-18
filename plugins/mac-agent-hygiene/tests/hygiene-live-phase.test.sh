#!/bin/bash
# hygiene-live-phase.test.sh — card wURBXBTk: the LaunchAgent's removal path keeps any checkout under a
# LIVE phase folder by the same three legs as phase-worktree-cleanup.mjs (card 9X0oxnMt), against the
# REAL scripts/hygiene.sh. Process cwds come from a stubbed lsof (HYG_LSOF), so this runs on Linux too.
#
#   KNOWN-POSITIVE (AC-2)  a clean pushed, idle worktree under wt/pipe-*/w/<card>/ whose phase folder has a
#                          fresh launch.log → keep live-phase-folder; apply refuses it; it survives
#   KNOWN-POSITIVE         same folder, launch.log older than the TTL, nobody inside → remove pushed; apply
#                          removes it and logs `removed [worktrees] … reason=pushed path=<path>` (AC-3)
#   KNOWN-NEGATIVE         no launch.log, a process cwd in the phase folder (not in the checkout) → keep
#   KNOWN-NEGATIVE         an `.in-use-by-*` marker in the phase folder, or an intermediate folder → keep
#   KNOWN-NEGATIVE         lsof failing → keep cwd-unmeasured, also for a legacy direct child (~/code/agent-wt-1)
#   KNOWN-NEGATIVE         a process in an UNRELATED folder releases nothing it should not hold
#   CONTROL                a full clone under the live phase is never listed (hygiene removes linked worktrees only)
#
# Nothing here touches the real HOME.
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-live-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$CODE"
export HYG_WT_AGE_DAYS=1 HYG_WT_DEPTH=4 HYG_WT_MERGED_PR_CHECK=0 HYG_GIT="$GITBIN" HYG_GH=""
unset HYG_LIVE_TTL_MIN HYG_WT_NESTED HYG_WT_GLOB

# lsof stub: $FX/lsof-mode is "none" (only pid 1 at /), "cwd <path>" (pid 999999 sits in <path>), or "fail".
mkdir -p "$FX/bin"
cat > "$FX/bin/lsof" <<EOF
#!/bin/bash
mode="\$(cat "$FX/lsof-mode" 2>/dev/null)"
case "\$mode" in
  fail) exit 2 ;;
  cwd\ *) printf 'p1\nn/\np999999\nn%s\n' "\${mode#cwd }" ;;
  *) printf 'p1\nn/\n' ;;
esac
EOF
chmod +x "$FX/bin/lsof"
export HYG_LSOF="$FX/bin/lsof"
lsof_mode(){ printf '%s\n' "$1" > "$FX/lsof-mode"; }
lsof_mode none

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
commit(){ echo "$2" > "$1/$(echo "$2" | tr -c 'a-zA-Z0-9\n' _)"; q -C "$1" add -A; q -C "$1" commit -qm "$2"; }
pushed(){ mkdir -p "$(dirname "$2")"; q -C "$MAIN" worktree add -q -b "$1" "$2"; commit "$2" "$1 work"; q -C "$2" push -q origin "$1"; }

ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
commit "$MAIN" "initial"; q -C "$MAIN" push -q origin HEAD:main

PHASE="$CODE/wt/pipe-live"                 # a phase folder, the way /board-pipeline lays it out
WT="$PHASE/w/card1"                        # 4 levels under ~/code (HYG_WT_DEPTH=4)
pushed feat-live "$WT"
CLONE="$PHASE/trainer"; q clone -q "$ORIGIN" "$CLONE"   # a reference clone: never hygiene's to remove
OTHER="$CODE/wt/pipe-other/demo"; pushed feat-other "$OTHER"
LEGACY="$CODE/agent-wt-1"; pushed feat-legacy "$LEGACY"
q -C "$MAIN" fetch -q origin

find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null   # everything idle past HYG_WT_AGE_DAYS
echo "slot event" > "$PHASE/launch.log"                       # fresh: written just now

row(){ awk -F'\t' -v p="$1" '$1=="worktrees" && $5==p {print $2"\t"$4}' "$2"; }
plan(){ bash "$HYG" plan > "$1" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"; }
expect(){ # path action reason-prefix plan label
  local got act why; got="$(row "$1" "$4")"; act="${got%%	*}"; why="${got#*	}"
  if [ "$act" = "$2" ] && case "$why" in "$3"*) true;; *) false;; esac; then ok "$5: $act $why"
  else bad "$5: expected '$2 $3…', got '${got:-<not listed>}'"; fi; }

# ---- AC-2 known positive: fresh launch.log keeps the clean pushed worktree ----------------------------
plan "$FX/p1.tsv"
expect "$WT" keep "live-phase-folder: launch.log in $PHASE written < 180 min ago" "$FX/p1.tsv" "fresh launch.log"
expect "$OTHER" remove "pushed" "$FX/p1.tsv" "control: a pushed worktree under a dead phase"
[ -z "$(row "$CLONE" "$FX/p1.tsv")" ] && ok "full reference clone under the live phase is not listed" || bad "clone listed"
printf 'worktrees\t%s\n' "$WT" > "$FX/hand.tsv"
OUT="$(bash "$HYG" apply "$FX/hand.tsv" 2>&1)"
printf '%s\n' "$OUT" | awk -F'\t' -v p="$WT" '$2=="refused" && $5==p && index($4,"live-phase-folder: launch.log")==1{f=1} END{exit !f}' \
  && ok "apply refuses a hand-written line for it" || bad "apply did not refuse: $OUT"
[ -d "$WT" ] && ok "live-phase worktree survives apply" || bad "live-phase worktree removed"
grep -qF "refused [worktrees] reason=live-phase-folder: launch.log in $PHASE" "$HYG_LOG" && grep -qF "path=$WT" "$HYG_LOG" \
  && ok "the refusal is logged with reason and path" || bad "no refusal log line: $(cat "$HYG_LOG")"

# ---- TTL: an old launch.log alone does not hold it ------------------------------------------------------
touch -t 202001010000 "$PHASE/launch.log"
plan "$FX/p2.tsv"
expect "$WT" remove "pushed" "$FX/p2.tsv" "launch.log older than 180 min, nobody inside"
HYG_LIVE_TTL_MIN=99999999 bash "$HYG" plan > "$FX/p2b.tsv" 2>/dev/null
expect "$WT" keep "live-phase-folder: launch.log" "$FX/p2b.tsv" "HYG_LIVE_TTL_MIN widens the window"

# ---- cwd leg, with or without a launch.log ---------------------------------------------------------------
rm -f "$PHASE/launch.log"
lsof_mode "cwd $PHASE"
plan "$FX/p3.tsv"
expect "$WT" keep "live-phase-folder: pid 999999 has its cwd in $PHASE" "$FX/p3.tsv" "no launch.log, a process in the phase folder"
expect "$OTHER" remove "pushed" "$FX/p3.tsv" "a process in another phase does not hold this one"
lsof_mode "cwd $PHASE/w/card2"
plan "$FX/p3b.tsv"
expect "$WT" keep "live-phase-folder: pid 999999 has its cwd in $PHASE/w" "$FX/p3b.tsv" "a process in a sibling card folder holds the phase"
lsof_mode "cwd $CODE/wt"
plan "$FX/p3c.tsv"
expect "$WT" remove "pushed" "$FX/p3c.tsv" "a process in the top-level scan dir itself holds nothing"
lsof_mode none

# ---- marker leg: in the phase folder, and in an intermediate folder --------------------------------------
: > "$PHASE/.in-use-by-pipe-x"
plan "$FX/p4.tsv"
expect "$WT" keep "live-phase-folder: .in-use-by-pipe-x marker in $PHASE" "$FX/p4.tsv" "marker in the phase folder"
rm -f "$PHASE/.in-use-by-pipe-x"; : > "$PHASE/w/.in-use-by-pipe-y"
plan "$FX/p4b.tsv"
expect "$WT" keep "live-phase-folder: .in-use-by-pipe-y marker in $PHASE/w" "$FX/p4b.tsv" "marker in an intermediate folder"
rm -f "$PHASE/w/.in-use-by-pipe-y"

# ---- unmeasured keeps -------------------------------------------------------------------------------------
lsof_mode fail
plan "$FX/p5.tsv"
expect "$WT" keep "cwd-unmeasured" "$FX/p5.tsv" "lsof failing keeps a nested worktree"
expect "$LEGACY" keep "cwd-unmeasured" "$FX/p5.tsv" "lsof failing keeps a legacy direct child"
HYG_LSOF="$FX/bin/no-such-lsof" bash "$HYG" plan > "$FX/p5b.tsv" 2>/dev/null
lsof_mode none
expect "$WT" keep "cwd-unmeasured" "$FX/p5b.tsv" "lsof missing keeps it"

# ---- apply re-reads cwds: a phase that starts after plan still holds ---------------------------------------
plan "$FX/p6.tsv"
expect "$WT" remove "pushed" "$FX/p6.tsv" "dead phase planned for removal"
awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$FX/p6.tsv" > "$FX/real.tsv"
lsof_mode "cwd $PHASE"
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply1.out" 2>&1
[ -d "$WT" ] && ok "a process entering the phase after plan blocks the removal at apply" || bad "removed although a process entered the phase"

# ---- AC-3: the removal is logged with path and reason ----------------------------------------------------
lsof_mode none
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply2.out" 2>&1
[ ! -e "$WT" ] && ok "dead-phase worktree removed" || bad "dead-phase worktree still present"
grep -qF "removed [worktrees]" "$HYG_LOG" && grep -F "removed [worktrees]" "$HYG_LOG" | grep -qF "reason=pushed path=$WT" \
  && ok "removal log line names reason and path" || bad "no attributable removal line: $(cat "$HYG_LOG")"
[ -d "$CLONE/.git" ] && [ -d "$MAIN/.git" ] && ok "reference clone and parent clone intact" || bad "a clone was removed"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
