#!/bin/bash
# hygiene-wt-scan-roots.test.sh — card uO9PFYg8: ~/code/_worktrees is a worktree scan root, with every
# keep rule intact, against the REAL scripts/hygiene.sh and its DEFAULT scope (HYG_WT_NESTED unset).
#
# Measured 2026-10-29: ~/code/_worktrees held 21 GB in 70 dirs (62 linked worktrees), and the routine
# never listed one of them — the default scope was ~/code/*wt-* plus ~/code/wt/**.
#
#   KNOWN-POSITIVE  _worktrees/x linked, clean, pushed, idle            → remove pushed (AC-3)
#   KNOWN-POSITIVE  _worktrees/<session>/<wt> nested, pushed, idle      → remove pushed
#   KNOWN-POSITIVE  wt/<session>/<wt> nested, pushed, idle              → remove pushed (AC-2: nested
#                   session worktrees are judged one by one by the worktrees pass)
#   KNOWN-NEGATIVE  _worktrees dirty / unpushed / touched recently / a process cwd inside → keep
#   KNOWN-NEGATIVE  wt/<session>/<wt> dirty                             → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  a full clone under _worktrees is never listed; apply refuses a hand-written line
#   KNOWN-NEGATIVE  a worktree deeper than HYG_WT_DEPTH under _worktrees is never listed
#   KNOWN-NEGATIVE  HYG_WT_NESTED="wt" (an explicit config) still leaves _worktrees out
#   status          worktrees_total equals the in-scope linked worktrees `git worktree list` reports (AC-4)
#   plan            is read-only: every dir and every `git worktree list` entry survives it
#   apply           removes exactly the planned ones; branch refs survive
#
# Nothing here touches the real HOME: HOME is a fixture dir. lsof is optional (the cwd case SKIPs).
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-scanroot-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"   # macOS: /var → /private/var, so git's absolute paths compare equal
SLEEPER=""
trap '[ -n "$SLEEPER" ] && { kill "$SLEEPER"; wait "$SLEEPER"; } 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
# Default scope on purpose: HYG_WT_ROOT / HYG_WT_GLOB / HYG_WT_NESTED / HYG_WT_DEPTH are NOT set.
unset HYG_WT_ROOT HYG_WT_GLOB HYG_WT_NESTED HYG_WT_DEPTH
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none"
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=0 HYG_GIT="$GITBIN" HYG_GH=""

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
commit(){ echo "$2" > "$1/$(echo "$2" | tr -c 'a-zA-Z0-9\n' _)"; q -C "$1" add -A; q -C "$1" commit -qm "$2"; }
addwt(){ mkdir -p "$(dirname "$2")"; q -C "$MAIN" worktree add -q -b "$1" "$2"; }   # branch path
pushed(){ addwt "$1" "$2"; commit "$2" "$1 work"; q -C "$2" push -q origin "$1"; }

# ---- origin + main clone (the parent repo lives OUTSIDE the scan roots, like ~/code/opsagent) -------
ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
commit "$MAIN" "initial"; q -C "$MAIN" push -q origin HEAD:main

UW="$CODE/_worktrees"
P_FLAT="$UW/2VyzZhtZ";               pushed wt-flat "$P_FLAT"
P_NEST="$UW/pipe-abc/demo";          pushed wt-nest "$P_NEST"
P_SESS="$CODE/wt/pipe-2vFqlJyB/demo"; pushed wt-sess "$P_SESS"
K_DIRTY="$UW/dirty";      pushed wt-dirty "$K_DIRTY"; echo edit >> "$K_DIRTY/wt-dirty_work"
K_UNPUSHED="$UW/unpushed"; addwt wt-unpushed "$K_UNPUSHED"; commit "$K_UNPUSHED" "local only"
K_RECENT="$UW/recent";    pushed wt-recent "$K_RECENT"
K_CWD="$UW/busy";         pushed wt-busy "$K_CWD"
K_SESSDIRTY="$CODE/wt/pipe-2vFqlJyB/dirty"; pushed wt-sessdirty "$K_SESSDIRTY"; echo x > "$K_SESSDIRTY/untracked.txt"
DEEP="$UW/a/b/c/demo";    pushed wt-deep "$DEEP"
CLONE="$UW/4DCulfyt";     mkdir -p "$UW"; q clone -q "$ORIGIN" "$CLONE"
q -C "$MAIN" fetch -q origin

# Age everything past HYG_WT_AGE_DAYS, then touch the one "recent" worktree.
find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null
touch "$K_RECENT/wt-recent_work"

# A process whose cwd is inside K_CWD (only meaningful when lsof exists).
if [ -x /usr/sbin/lsof ]; then (cd "$K_CWD" && exec sleep 300) & SLEEPER=$!; sleep 1; fi

PLAN="$FX/plan.tsv"
WT_BEFORE="$("$GITBIN" -C "$MAIN" worktree list --porcelain | grep -c '^worktree ')"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
row(){ awk -F'\t' -v p="$1" '$1=="worktrees" && $5==p {print $2" "$4}' "$2"; }
expect(){ # path "action reason" label
  local got; got="$(row "$1" "$PLAN")"
  if [ "$got" = "$2" ]; then ok "$3: $2"; else bad "$3: expected '$2', got '${got:-<not listed>}'"; fi; }

expect "$P_FLAT"      "remove pushed"               "AC-3 _worktrees/x clean pushed idle"
expect "$P_NEST"      "remove pushed"               "_worktrees/<session>/<wt> nested"
expect "$P_SESS"      "remove pushed"               "AC-2 wt/<session>/<wt> nested"
expect "$K_DIRTY"     "keep dirty-uncommitted-work" "_worktrees dirty"
expect "$K_UNPUSHED"  "keep unpushed-commits"       "_worktrees unpushed"
expect "$K_RECENT"    "keep touched-recently"       "_worktrees touched recently"
expect "$K_SESSDIRTY" "keep dirty-uncommitted-work" "AC-2 wt/<session>/<wt> dirty"
if [ -n "$SLEEPER" ] && /usr/sbin/lsof -d cwd -Fn 2>/dev/null | grep -qxF "n$K_CWD"; then
  expect "$K_CWD" "keep a-process-is-inside" "_worktrees with a process cwd inside"
else echo "SKIP - cwd-inside case (lsof cannot see the fixture process)"; fi
[ -z "$(row "$CLONE" "$PLAN")" ] && ok "full clone under _worktrees is not listed" || bad "clone listed: $(row "$CLONE" "$PLAN")"
[ -z "$(row "$DEEP" "$PLAN")" ] && ok "worktree deeper than HYG_WT_DEPTH is not listed" || bad "deep listed: $(row "$DEEP" "$PLAN")"
[ -z "$(row "$MAIN" "$PLAN")" ] && ok "parent clone is not listed" || bad "parent clone listed"

# ---- plan is read-only -----------------------------------------------------------------------------
WT_AFTER="$("$GITBIN" -C "$MAIN" worktree list --porcelain | grep -c '^worktree ')"
[ "$WT_BEFORE" = "$WT_AFTER" ] && ok "plan leaves git worktree list unchanged ($WT_AFTER)" || bad "plan changed worktree list: $WT_BEFORE → $WT_AFTER"
for d in "$P_FLAT" "$P_NEST" "$P_SESS" "$K_DIRTY" "$K_UNPUSHED" "$K_RECENT" "$K_CWD" "$CLONE"; do
  [ -d "$d" ] || bad "plan removed $d"; done

# ---- an explicit HYG_WT_NESTED="wt" keeps the old scope ----------------------------------------------
HYG_WT_NESTED=wt bash "$HYG" plan > "$FX/plan-wt.tsv" 2>/dev/null
[ -z "$(row "$P_FLAT" "$FX/plan-wt.tsv")" ] && [ -n "$(row "$P_SESS" "$FX/plan-wt.tsv")" ] \
  && ok "HYG_WT_NESTED=wt opts out of _worktrees and keeps wt/" || bad "HYG_WT_NESTED=wt did not narrow the scope"

# ---- status reconciles with git (AC-4 in miniature) --------------------------------------------------
# In scope = every linked worktree git reports under _worktrees/ or wt/ within HYG_WT_DEPTH (3) levels of ~/code.
GIT_N="$("$GITBIN" -C "$MAIN" worktree list --porcelain | sed -n 's/^worktree //p' |
  awk -v c="$CODE/" 'index($0,c)==1 { r=substr($0,length(c)+1); n=split(r,a,"/"); if ((a[1]=="_worktrees"||a[1]=="wt") && n>=2 && n<=3) k++ } END{print k+0}')"
ST_N="$(bash "$HYG" status 2>/dev/null | awk -F'\t' '$1=="worktrees_total"{print $2}')"
[ "$GIT_N" = 8 ] && [ "$ST_N" = "$GIT_N" ] && ok "status worktrees_total=$ST_N reconciles with git worktree list ($GIT_N)" \
  || bad "status worktrees_total=$ST_N, git in-scope count=$GIT_N (expected 8)"

# ---- apply: refuses a hand-written line for the clone and the dirty one; removes the planned ones -----
printf 'worktrees\t%s\nworktrees\t%s\n' "$CLONE" "$K_DIRTY" > "$FX/evil.tsv"
OUT="$(bash "$HYG" apply "$FX/evil.tsv" 2>&1)"
[ "$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="refused"' | wc -l | tr -d ' ')" = 2 ] && ok "apply refuses clone and dirty" || bad "apply did not refuse both: $OUT"
awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1
for d in "$P_FLAT" "$P_NEST" "$P_SESS"; do [ ! -e "$d" ] && ok "removed $d" || bad "still present: $d"; done
for d in "$K_DIRTY" "$K_UNPUSHED" "$K_RECENT" "$K_CWD" "$K_SESSDIRTY" "$DEEP" "$CLONE" "$MAIN"; do [ -d "$d" ] && ok "kept $d" || bad "removed $d"; done
[ -f "$K_DIRTY/wt-dirty_work" ] && grep -q edit "$K_DIRTY/wt-dirty_work" && ok "dirty edit survives" || bad "dirty edit lost"
"$GITBIN" -C "$MAIN" rev-parse -q --verify refs/heads/wt-flat >/dev/null && ok "branch wt-flat survives removal" || bad "branch ref wt-flat is gone"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
