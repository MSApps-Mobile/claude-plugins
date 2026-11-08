#!/bin/bash
# hygiene-scan-budget.test.sh — card iTGD34Ub, against the REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-POSITIVE  a plan row carries the age bucket and, on a nested keep, the repo that decided it
#   KNOWN-POSITIVE  report groups rows by age and reason, and names every over-window keep with its blocker
#   KNOWN-POSITIVE  kept rows inside the window are not sized; over-window rows are
#   KNOWN-NEGATIVE  a spent budget evaluates nothing: rows read keep/scan-budget-exceeded, none reads remove
#   KNOWN-POSITIVE  the next run scans the folders the previous one did not reach first
#   KNOWN-NEGATIVE  apply never trusts a plan-time cache: a folder dirtied after the plan is refused
#   KNOWN-POSITIVE  a recently touched folder costs no artifact walk (no build-artifacts row)
#   KNOWN-NEGATIVE  a walk that fails keeps the folder as repo-walk-failed, naming the path it could not read
#   KNOWN-POSITIVE  a stray HEAD keeps the folder and the report names that HEAD path as the blocker (B1)
#   KNOWN-POSITIVE  a folder-level keep prints . as its blocker, never -
#   KNOWN-NEGATIVE  a read-only $TMPD (cache unwritable) keeps a folder whose nested dirty clone an empty inventory would hide (S1)
#   KNOWN-NEGATIVE  a cache that cannot be read back keeps such a folder too (S1)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-budget.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"
trap 'chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
W="$HOME/code/wt"; mkdir -p "$W"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$W" HYG_GRADLE_HOME="$HOME/gradle-none" HYG_DEVICE_SUPPORT="$HOME/ds-none"
export HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/android-none" HYG_PKG_CACHES=""
export HYG_SESSIONS_JSON="$FX/sessions.json" HYG_STATE_DIR="$FX/state"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
echo '[{"session":"s-alive","status":"running"}]' > "$HYG_SESSIONS_JSON"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
row(){ /usr/bin/awk -F'\t' -v c="$2" -v p="$3" '$1==c && $5==p' "$1"; }

git init -q --bare "$FX/origin.git"
clone(){ git clone -q "$FX/origin.git" "$1" 2>/dev/null; ( cd "$1" && echo a > a && git add a && git commit -qm a && git push -q origin HEAD:refs/heads/"$(basename "$1")" ); }
mkdir -p "$W/s-dirty/nest/inner"; clone "$W/s-dirty/nest/inner"; echo wip >> "$W/s-dirty/nest/inner/a"; dd if=/dev/zero of="$W/s-dirty/blob" bs=1024 count=2048 2>/dev/null; old "$W/s-dirty"
clone "$W/s-clean"; old "$W/s-clean"
mkdir -p "$W/s-week"; clone "$W/s-week/repo"; echo wip >> "$W/s-week/repo/a"; old "$W/s-week"; touch -t "$(/bin/date -v-3d +%Y%m%d%H%M)" "$W/s-week/repo/a"
mkdir -p "$W/s-fresh/pkg/node_modules/x"; echo '{}' > "$W/s-fresh/pkg/package.json"; echo y > "$W/s-fresh/pkg/node_modules/x/y"
mkdir -p "$W/s-denied/node_modules/sealed"; echo x > "$W/s-denied/f"; old "$W/s-denied"; chmod 000 "$W/s-denied/node_modules/sealed"
mkdir -p "$W/s-stray/vendor/pkg"; echo 'ref: refs/heads/main' > "$W/s-stray/vendor/pkg/HEAD"; echo x > "$W/s-stray/f"; old "$W/s-stray"
mkdir -p "$W/s-alive"; echo x > "$W/s-alive/f"; old "$W/s-alive"

P="$FX/plan.tsv"; bash "$HYG" plan > "$P" 2>/dev/null
case "$(row "$P" session-dirs "$W/s-dirty")" in *$'\tkeep\t'*$'\tnested-dirty-uncommitted-work\t'*$'\t>7d\tnest/inner') ok "keep row names age and blocker";; *) bad "dirty row: $(row "$P" session-dirs "$W/s-dirty")";; esac
case "$(row "$P" session-dirs "$W/s-clean")" in *$'\tremove\t'*$'\t>7d\t') ok "remove row carries its age";; *) bad "clean row: $(row "$P" session-dirs "$W/s-clean")";; esac
[ "$(row "$P" session-dirs "$W/s-dirty" | cut -f3)" -ge 2048 ] && ok "over-window keep is sized" || bad "over-window keep unsized"
case "$(row "$P" session-dirs "$W/s-week")" in *$'\tkeep\t0\t'*$'\t1-7d\t'*) ok "keep inside the window is not sized";; *) bad "week row: $(row "$P" session-dirs "$W/s-week")";; esac
[ -z "$(row "$P" build-artifacts "$W/s-fresh/pkg/node_modules")" ] && ok "recently touched folder gets no artifact row" || bad "artifact row for a fresh folder"
case "$(row "$P" session-dirs "$W/s-denied")" in *$'\tkeep\t'*$'\trepo-walk-failed\t'*$'\t>7d\tnode_modules/sealed') ok "a failed walk keeps the folder as repo-walk-failed, blocker = the unreadable path";; *) bad "denied row: $(row "$P" session-dirs "$W/s-denied")";; esac
case "$(row "$P" session-dirs "$W/s-stray")" in *$'\tkeep\t'*$'\tcontains-bare-or-separate-git-dir\t'*$'\t>7d\tvendor/pkg/HEAD') ok "a stray HEAD keep names the HEAD path as its blocker";; *) bad "stray row: $(row "$P" session-dirs "$W/s-stray")";; esac
case "$(row "$P" session-dirs "$W/s-alive")" in *$'\tkeep\t'*$'\tsession-alive-in-registry\t'*$'\t>7d\t.') ok "a folder-level keep names . as its blocker";; *) bad "alive row: $(row "$P" session-dirs "$W/s-alive")";; esac

bash "$HYG" report "$P" > "$FX/report" 2>/dev/null
/usr/bin/grep -q $'^>7d\tkeep\tsession-dirs\tnested-dirty-uncommitted-work\t1\t' "$FX/report" && ok "report groups by age and reason" || bad "report groups: $(cat "$FX/report")"
/usr/bin/grep -qF "$(printf 'kept-over-window\tnested-dirty-uncommitted-work\tnest/inner\t%s' "$W/s-dirty")" "$FX/report" && ok "report names the over-window keep" || bad "report keep line"
/usr/bin/grep -q "kept-over-window.*s-week" "$FX/report" && bad "report lists a folder inside the window" || ok "report leaves out folders inside the window"
/usr/bin/grep -qF "$(printf 'kept-over-window\tcontains-bare-or-separate-git-dir\tvendor/pkg/HEAD\t%s' "$W/s-stray")" "$FX/report" && ok "report names the HEAD path that kept the folder" || bad "report stray line: $(grep s-stray "$FX/report")"
/usr/bin/grep -qF "$(printf 'kept-over-window\trepo-walk-failed\tnode_modules/sealed\t%s' "$W/s-denied")" "$FX/report" && ok "report names the path a failed walk could not read" || bad "report denied line: $(grep s-denied "$FX/report")"
/usr/bin/grep -qF "$(printf 'kept-over-window\tsession-alive-in-registry\t.\t%s' "$W/s-alive")" "$FX/report" && ok "report prints . for a folder-level keep" || bad "report alive line: $(grep s-alive "$FX/report")"
/usr/bin/awk -F'\t' '$1=="kept-over-window" && $3=="-"{f=1} END{exit f}' "$FX/report" && ok "no over-window keep in the report prints -" || bad "a - blocker: $(grep kept-over-window "$FX/report")"

# Budget spent: an already expired clock evaluates nothing in the three slow passes
sed 's/^PLAN_T0=\$SECONDS$/PLAN_T0=-100000/; s/^  PLAN_T0=\$SECONDS$/  PLAN_T0=-100000/' "$HYG" > "$FX/hyg-spent.sh"
bash "$FX/hyg-spent.sh" plan > "$FX/spent.tsv" 2>/dev/null
/usr/bin/awk -F'\t' '($1=="session-dirs"||$1=="worktrees"||$1=="build-artifacts") && $2=="remove"{f=1} END{exit f}' "$FX/spent.tsv" && ok "spent budget removes nothing" || bad "spent budget removed: $(cat "$FX/spent.tsv")"
[ "$(/usr/bin/awk -F'\t' '$1=="session-dirs" && $4=="scan-budget-exceeded"{n++} END{print n+0}' "$FX/spent.tsv")" -ge 4 ] && ok "spent budget reads scan-budget-exceeded" || bad "spent rows: $(cat "$FX/spent.tsv")"

# A slow pass ahead of the budget must not eat the slow passes' share: 12 min budget, 5 min gone
sed '/^case "\${1:-}" in$/,$d' "$HYG" > "$FX/hyg-dl.sh"
cat >> "$FX/hyg-dl.sh" <<'INNER'
PLAN_T0=$((SECONDS-300)); w=$(budget_deadline worktrees); a=$(budget_deadline build-artifacts); s=$(budget_deadline session-dirs); g=$(budget_deadline gradle)
HYG_PLAN_BUDGET_MIN=0; z=$(budget_deadline session-dirs); echo "$w $a $s $g $z"
INNER
[ "$(bash "$FX/hyg-dl.sh" 2>/dev/null)" = "440 510 720 0 0" ] && ok "each pass gets a share of what is left, cache passes and budget 0 have no limit" || bad "deadlines: $(bash "$FX/hyg-dl.sh" 2>&1)"

# Fairness: the folder never scanned goes first
mkdir -p "$FX/state"; printf '%s\t%s\n' "$W/s-clean" "$(/bin/date +%s)" "$W/s-week" "$(/bin/date +%s)" "$W/s-fresh" "$(/bin/date +%s)" "$W/s-denied" "$(/bin/date +%s)" "$W/s-stray" "$(/bin/date +%s)" "$W/s-alive" "$(/bin/date +%s)" > "$FX/state/scanned-session-dirs.tsv"
bash "$HYG" plan > "$FX/fair.tsv" 2>/dev/null
[ "$(/usr/bin/awk -F'\t' '$1=="session-dirs"{print $5; exit}' "$FX/fair.tsv")" = "$W/s-dirty" ] && ok "the folder the last run did not reach goes first" || bad "fair order: $(awk -F'\t' '$1=="session-dirs"{print $5}' "$FX/fair.tsv")"
[ -f "$FX/state/scanned-session-dirs.tsv" ] && /usr/bin/grep -qF "$W/s-dirty" "$FX/state/scanned-session-dirs.tsv" && ok "a scanned folder is recorded" || bad "scanned state not written"

# Apply re-reads the disk: dirty the planned folder after the plan, in the same process
sed '/^case "\${1:-}" in$/,$d' "$HYG" > "$FX/hyg-lib.sh"
cat >> "$FX/hyg-lib.sh" <<INNER
check_item session-dirs "$W/s-clean" && echo planned-remove
echo wip >> "$W/s-clean/a"; old_t=202601010000; touch -t \$old_t "$W/s-clean/a"
printf 'session-dirs\t%s\n' "$W/s-clean" > "$FX/late.tsv"
apply "$FX/late.tsv"
INNER
bash "$FX/hyg-lib.sh" > "$FX/late.out" 2>&1
[ -d "$W/s-clean" ] && /usr/bin/grep -q 'refused' "$FX/late.out" && ok "apply refuses a folder dirtied after the plan" || bad "late dirty: $(cat "$FX/late.out")"

# S1: the inventory cache cannot be written. Each folder below is clean and pushed apart from the nested clone the walk
# would find, so an empty inventory would read "no repo" and remove it. A read-only $TMPD must keep it instead.
mkdir -p "$W/s-ro/nest"; clone "$W/s-ro/nest/roinner"; echo wip >> "$W/s-ro/nest/roinner/a"; old "$W/s-ro"
sed '/^case "\${1:-}" in$/,$d' "$HYG" > "$FX/hyg-ro.sh"
cat >> "$FX/hyg-ro.sh" <<INNER
/bin/chmod 500 "\$TMPD"
check_item session-dirs "$W/s-ro"; echo "check rc=\$? \$REASON \$BLOCKER"
printf 'session-dirs\t%s\n' "$W/s-ro" > "$FX/ro.tsv"
apply "$FX/ro.tsv"
/bin/chmod 700 "\$TMPD"
INNER
bash "$FX/hyg-ro.sh" > "$FX/ro.out" 2>&1
/usr/bin/grep -q '^check rc=1 repo-inventory-cache-failed \.$' "$FX/ro.out" && ok "read-only TMPD: plan keeps the folder (repo-inventory-cache-failed)" || bad "ro check: $(cat "$FX/ro.out")"
[ -d "$W/s-ro/nest/roinner" ] && /usr/bin/grep -q $'refused\t0\trepo-inventory-cache-failed' "$FX/ro.out" && ok "read-only TMPD: apply refuses and the folder stays" || bad "ro apply: $(cat "$FX/ro.out")"

# S1: the cache was written but cannot be read back
mkdir -p "$W/s-rb/nest"; clone "$W/s-rb/nest/rbinner"; echo wip >> "$W/s-rb/nest/rbinner/a"; old "$W/s-rb"
sed '/^case "\${1:-}" in$/,$d' "$HYG" > "$FX/hyg-rb.sh"
cat >> "$FX/hyg-rb.sh" <<INNER
repo_inventory "$W/s-rb" >/dev/null; /bin/chmod 000 "\$TMPD/inv-\$(path_key "$W/s-rb")"
check_item session-dirs "$W/s-rb"; echo "check rc=\$? \$REASON \$BLOCKER"
INNER
bash "$FX/hyg-rb.sh" > "$FX/rb.out" 2>&1
/usr/bin/grep -q '^check rc=1 repo-inventory-cache-failed \.$' "$FX/rb.out" && ok "unreadable cache: the folder is kept" || bad "rb check: $(cat "$FX/rb.out")"

echo "# pass=$PASS fail=$FAILN"; [ "$FAILN" = 0 ]
