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
#   KNOWN-NEGATIVE  a walk that fails reads as a bare repo: the folder is kept
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
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none" HYG_WT_ROOTS="$W:*"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$W" HYG_GRADLE_HOME="$HOME/gradle-none" HYG_DEVICE_SUPPORT="$HOME/ds-none"
export HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/android-none" HYG_PKG_CACHES=""
export HYG_SESSIONS_JSON="$FX/sessions.json" HYG_STATE_DIR="$FX/state"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
echo '[]' > "$HYG_SESSIONS_JSON"

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
mkdir -p "$W/s-denied/sealed"; echo x > "$W/s-denied/f"; old "$W/s-denied"; chmod 000 "$W/s-denied/sealed"

P="$FX/plan.tsv"; bash "$HYG" plan > "$P" 2>/dev/null
case "$(row "$P" session-dirs "$W/s-dirty")" in *$'\tkeep\t'*$'\tnested-dirty-uncommitted-work\t'*$'\t>7d\tnest/inner') ok "keep row names age and blocker";; *) bad "dirty row: $(row "$P" session-dirs "$W/s-dirty")";; esac
case "$(row "$P" session-dirs "$W/s-clean")" in *$'\tremove\t'*$'\t>7d\t') ok "remove row carries its age";; *) bad "clean row: $(row "$P" session-dirs "$W/s-clean")";; esac
[ "$(row "$P" session-dirs "$W/s-dirty" | cut -f3)" -ge 2048 ] && ok "over-window keep is sized" || bad "over-window keep unsized"
case "$(row "$P" session-dirs "$W/s-week")" in *$'\tkeep\t0\t'*$'\t1-7d\t'*) ok "keep inside the window is not sized";; *) bad "week row: $(row "$P" session-dirs "$W/s-week")";; esac
[ -z "$(row "$P" build-artifacts "$W/s-fresh/pkg/node_modules")" ] && ok "recently touched folder gets no artifact row" || bad "artifact row for a fresh folder"
case "$(row "$P" session-dirs "$W/s-denied")" in *$'\tkeep\t'*contains-bare-or-separate-git-dir*) ok "a failed walk keeps the folder";; *) bad "denied row: $(row "$P" session-dirs "$W/s-denied")";; esac

bash "$HYG" report "$P" > "$FX/report" 2>/dev/null
/usr/bin/grep -q $'^>7d\tkeep\tsession-dirs\tnested-dirty-uncommitted-work\t1\t' "$FX/report" && ok "report groups by age and reason" || bad "report groups: $(cat "$FX/report")"
/usr/bin/grep -qF "$(printf 'kept-over-window\tnested-dirty-uncommitted-work\tnest/inner\t%s' "$W/s-dirty")" "$FX/report" && ok "report names the over-window keep" || bad "report keep line"
/usr/bin/grep -q "kept-over-window.*s-week" "$FX/report" && bad "report lists a folder inside the window" || ok "report leaves out folders inside the window"

# Budget spent: an already expired clock evaluates nothing in the three slow passes
sed 's/^PLAN_T0=\$SECONDS$/PLAN_T0=-100000/; s/^  PLAN_T0=\$SECONDS$/  PLAN_T0=-100000/' "$HYG" > "$FX/hyg-spent.sh"
bash "$FX/hyg-spent.sh" plan > "$FX/spent.tsv" 2>/dev/null
/usr/bin/awk -F'\t' '($1=="session-dirs"||$1=="worktrees"||$1=="build-artifacts") && $2=="remove"{f=1} END{exit f}' "$FX/spent.tsv" && ok "spent budget removes nothing" || bad "spent budget removed: $(cat "$FX/spent.tsv")"
[ "$(/usr/bin/awk -F'\t' '$1=="session-dirs" && $4=="scan-budget-exceeded"{n++} END{print n+0}' "$FX/spent.tsv")" -ge 4 ] && ok "spent budget reads scan-budget-exceeded" || bad "spent rows: $(cat "$FX/spent.tsv")"

# Fairness: the folder never scanned goes first
mkdir -p "$FX/state"; printf '%s\t%s\n' "$W/s-clean" "$(/bin/date +%s)" "$W/s-week" "$(/bin/date +%s)" "$W/s-fresh" "$(/bin/date +%s)" "$W/s-denied" "$(/bin/date +%s)" > "$FX/state/scanned-session-dirs.tsv"
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

echo "# pass=$PASS fail=$FAILN"; [ "$FAILN" = 0 ]
