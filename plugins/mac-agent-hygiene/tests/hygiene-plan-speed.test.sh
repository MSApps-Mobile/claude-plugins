#!/bin/bash
# hygiene-plan-speed.test.sh — card NISFIbub: `hygiene.sh plan` was killed at 500-630 s inside the worktrees
# category (685 worktrees, 14 checked). Against the REAL scripts/hygiene.sh, on a synthetic HOME:
#
#   TIME-BOUND      12 idle pushed worktrees, each with a deep gitignored node_modules, plan in < 60 s
#   KNOWN-POSITIVE  the same worktrees are still planned remove/pushed (the faster pushed test decides alike)
#   KNOWN-NEGATIVE  an unpushed worktree is still keep/unpushed-commits
#   KNOWN-POSITIVE  keep rows of worktrees are not sized (kb "-"); remove rows are
#   KNOWN-POSITIVE  plan writes one "plan: <category> N candidates (...) in Ns" line to stderr AND the log
#   KNOWN-POSITIVE  no `git branch -r --contains` call (the per-remote-ref walk the card measured at 5-22 s)
#   BUDGET          with a git shim that makes `status` take 2 s and HYG_WT_BUDGET_SEC=3, plan stops checking
#                   at the budget: it returns in < 20 s (unbounded it needs > 26 s), the rest read
#                   keep/scan-budget-exceeded with kb "-", and `run` removes none of those
#   KNOWN-NEGATIVE  a process whose cwd is inside a worktree keeps it; a sibling whose name only starts the
#                   same (c1 vs c10) is not matched
#
# Nothing here touches the real HOME. shellcheck disable=SC2015  # ok()/bad() always return 0
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-speed-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
SLEEPER=""
trap '[ -n "$SLEEPER" ] && kill "$SLEEPER" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main

CODE="$HOME/code"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$CODE"
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/nonexistent

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
col(){ /usr/bin/awk -F'\t' -v p="$1" -v c="$2" '$5==p{print $c}' "$3"; }

# ---- synthetic tree -------------------------------------------------------------------------------
ORIGIN="$FX/origin.git"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
echo node_modules/ > "$MAIN/.gitignore"; echo a > "$MAIN/a"; q -C "$MAIN" add -A; q -C "$MAIN" commit -qm init
q -C "$MAIN" push -q origin HEAD:main
N=12; WTS=()
for i in $(seq 1 $N); do
  d="$CODE/wt/pipe-$i/c$i"; mkdir -p "$(dirname "$d")"; q -C "$MAIN" worktree add -q -b "b$i" "$d" main
  for p in 1 2 3 4 5 6 7 8; do m="$d/node_modules/p$p/node_modules/dep/lib/deep/er"; mkdir -p "$m"
    (cd "$m" && : > f1.js && : > f2.js && : > f3.js && : > f4.js && : > f5.js && : > f6.js && : > f7.js && : > f8.js); done
  WTS+=( "$d" )
done
UNP="$CODE/wt/pipe-unpushed/u"; mkdir -p "$(dirname "$UNP")"; q -C "$MAIN" worktree add -q -b unp "$UNP" main
echo x > "$UNP/x"; q -C "$UNP" add -A; q -C "$UNP" commit -qm "local only"
/usr/bin/find "$CODE" -exec /usr/bin/touch -h -t 202001010000 {} + 2>/dev/null

# git shim: logs every call; SLOW_STATUS=<s> makes `status` sleep (a slow worktree, deterministically)
mkdir -p "$FX/bin"
cat > "$FX/bin/git" <<EOF
#!/bin/bash
echo "\$*" >> "$FX/git-calls.log"
case " \$* " in *" status "*) [ -n "\${SLOW_STATUS:-}" ] && sleep "\$SLOW_STATUS";; esac
exec "$GITBIN" "\$@"
EOF
chmod +x "$FX/bin/git"
export HYG_GIT="$FX/bin/git"

# ---- unbounded plan on the synthetic tree ---------------------------------------------------------
PLAN="$FX/plan.tsv"; : > "$FX/git-calls.log"
t0=$SECONDS
HYG_WT_BUDGET_SEC=0 bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(head -3 "$FX/plan.err")"
el=$((SECONDS-t0))
[ "$el" -lt 60 ] && ok "plan over $((N+1)) worktrees with deep node_modules finished in ${el}s (< 60)" || bad "plan took ${el}s"
np=0; for d in "${WTS[@]}"; do [ "$(col "$d" 2 "$PLAN")/$(col "$d" 4 "$PLAN")" = remove/pushed ] && np=$((np+1)); done
[ "$np" = "$N" ] && ok "all $N pushed worktrees planned remove/pushed" || bad "only $np of $N planned remove/pushed: $(cut -f2,4 "$PLAN" | sort | uniq -c | tr '\n' ' ')"
[ "$(col "$UNP" 2 "$PLAN")/$(col "$UNP" 4 "$PLAN")" = keep/unpushed-commits ] && ok "unpushed worktree kept (unpushed-commits)" \
  || bad "unpushed worktree: $(col "$UNP" 2 "$PLAN")/$(col "$UNP" 4 "$PLAN")"
[ "$(col "$UNP" 3 "$PLAN")" = - ] && ok "keep row of a worktree is not sized (kb -)" || bad "keep row kb = $(col "$UNP" 3 "$PLAN")"
k=$(col "${WTS[0]}" 3 "$PLAN"); case "$k" in ''|*[!0-9]*) bad "remove row kb not numeric: $k";; *) ok "remove row is sized (kb $k)";; esac
grep -q "^plan: worktrees $((N+1)) candidates ($N remove) in [0-9]*s$" "$FX/plan.err" && ok "per-category duration line on stderr" \
  || bad "no duration line on stderr: $(cat "$FX/plan.err")"
grep -q "plan: worktrees $((N+1)) candidates ($N remove) in [0-9]*s$" "$HYG_LOG" && ok "per-category duration line in the log" || bad "no duration line in the log"
grep -q 'branch -r --contains' "$FX/git-calls.log" && bad "plan still calls git branch -r --contains" || ok "no git branch -r --contains call"

# ---- a process inside a worktree; prefix sibling not matched ----------------------------------------
(cd "${WTS[0]}" && exec sleep 300) & SLEEPER=$!
sleep 1
if [ -x /usr/sbin/lsof ] && /usr/sbin/lsof -p "$SLEEPER" -d cwd -Fn 2>/dev/null | grep -qxF "n${WTS[0]}"; then
  HYG_WT_BUDGET_SEC=0 bash "$HYG" plan > "$FX/plan-cwd.tsv" 2>/dev/null
  [ "$(col "${WTS[0]}" 4 "$FX/plan-cwd.tsv")" = a-process-is-inside ] && ok "worktree with a process inside is kept" \
    || bad "cwd-inside worktree: $(col "${WTS[0]}" 2 "$FX/plan-cwd.tsv")/$(col "${WTS[0]}" 4 "$FX/plan-cwd.tsv")"
  S10="$CODE/wt/pipe-10/c10"
  [ "$(col "$S10" 4 "$FX/plan-cwd.tsv")" = pushed ] && ok "sibling c10 not matched by a cwd in c1" || bad "c10: $(col "$S10" 4 "$FX/plan-cwd.tsv")"
else echo "skip - lsof cannot see the sleeper's cwd here"; fi
kill "$SLEEPER" 2>/dev/null; wait "$SLEEPER" 2>/dev/null; SLEEPER=""

# ---- budget: slow status, 3 s budget -------------------------------------------------------------
t0=$SECONDS
SLOW_STATUS=2 HYG_WT_BUDGET_SEC=3 bash "$HYG" plan > "$FX/plan-b.tsv" 2>"$FX/plan-b.err"
el=$((SECONDS-t0))
[ "$el" -lt 20 ] && ok "budgeted plan returned in ${el}s (< 20; unbounded > $((2*(N+1))) s)" || bad "budgeted plan took ${el}s"
cut=$(/usr/bin/awk -F'\t' '$2=="keep" && $4=="scan-budget-exceeded"' "$FX/plan-b.tsv" | /usr/bin/wc -l | tr -d ' ')
chk=$(/usr/bin/awk -F'\t' '$4!="scan-budget-exceeded"' "$FX/plan-b.tsv" | /usr/bin/wc -l | tr -d ' ')
tot=$(/usr/bin/wc -l < "$FX/plan-b.tsv" | tr -d ' ')
[ "$tot" = $((N+1)) ] && ok "every worktree has a row ($tot)" || bad "rows: $tot, want $((N+1))"
[ "$cut" -ge 1 ] && [ "$chk" -ge 1 ] && ok "$chk checked, $cut read keep/scan-budget-exceeded" || bad "checked=$chk cut=$cut"
[ -z "$(/usr/bin/awk -F'\t' '$4=="scan-budget-exceeded" && $3!="-"' "$FX/plan-b.tsv")" ] && ok "budget rows carry kb -" || bad "budget row sized"
grep -q "not checked: scan-budget-exceeded" "$FX/plan-b.err" && ok "stderr names the unchecked count" || bad "stderr: $(cat "$FX/plan-b.err")"

# run: removes only what it checked within the budget; budget-cut worktrees stay
: > "$FX/git-calls.log"
SLOW_STATUS=2 HYG_WT_BUDGET_SEC=3 bash "$HYG" run > "$FX/run.out" 2>/dev/null
removed=$(/usr/bin/awk -F'\t' '$2=="removed"' "$FX/run.out" | /usr/bin/wc -l | tr -d ' ')
left=0; for d in "${WTS[@]}"; do [ -d "$d" ] && left=$((left+1)); done
[ $((removed+left)) = "$N" ] && [ "$left" -ge 1 ] && ok "run removed $removed, left $left unchecked/kept in place" || bad "run removed=$removed left=$left"
[ -d "$UNP" ] && ok "unpushed worktree survives run" || bad "run removed the unpushed worktree"
grep -q '^summary	done' "$FX/run.out" && ok "run reached apply done" || bad "run output: $(tail -2 "$FX/run.out")"

echo "---"; echo "pass=$PASS fail=$FAILN"; [ "$FAILN" = 0 ]
