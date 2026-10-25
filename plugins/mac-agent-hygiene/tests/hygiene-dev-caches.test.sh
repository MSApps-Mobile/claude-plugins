#!/bin/bash
# hygiene-dev-caches.test.sh — the 0.2.0 categories (session-dirs, gradle, ios, android, pkg-caches),
# against the REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-POSITIVE  a stale session dir whose only nested repo is clean + pushed is planned remove, and apply removes it
#   KNOWN-NEGATIVE  a stale session dir with ONE dirty nested repo is kept whole
#   KNOWN-NEGATIVE  a session dir with a file touched in the last 24 h is kept
#   KNOWN-NEGATIVE  a nested full clone with a stash, or with a local branch on no remote, keeps the folder
#   KNOWN-POSITIVE  a clone branch its stale origin ref misses but GitHub's default branch contains → remove
#   KNOWN-NEGATIVE  the same when GitHub's default branch lacks it, origin is a crafted URL, or the gh cap is hit → keep
#   KNOWN-POSITIVE  a clean linked worktree whose HEAD a parent-repo branch holds → remove; the branch survives apply
#   KNOWN-NEGATIVE  a linked worktree on a detached HEAD no branch holds → keep
#   KNOWN-NEGATIVE  a linked worktree whose parent (a bare repo) sits inside the same session → keep
#   KNOWN-NEGATIVE  a session holding a bare repo (no .git anywhere) → keep
#   KNOWN-NEGATIVE  a nested repo whose config defines a filter driver is kept, and the driver never runs
#   KNOWN-NEGATIVE  a nested repo with submodules is kept unread (status would run under their config)
#   KNOWN-NEGATIVE  a dirty repo 7 levels deep inside node_modules keeps the folder (the search is not pruned)
#   KNOWN-POSITIVE  the oldest of three old Gradle dists is removed; KNOWN-NEGATIVE the newest two are kept
#   KNOWN-POSITIVE  old iOS DeviceSupport is removed; KNOWN-NEGATIVE the newest one is kept even when old
#   KNOWN-POSITIVE  old ~/.android/cache entries and an idle CocoaPods cache are removed
#   KNOWN-NEGATIVE  an AVD is never a candidate
#   KNOWN-NEGATIVE  `run` with the lock already held removes nothing
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-dev.XXXXXX")" || exit 1
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none" HYG_WT_ROOTS=""
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$HOME/code/wt" HYG_GRADLE_HOME="$HOME/.gradle"
export HYG_DEVICE_SUPPORT="$HOME/ds" HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/.android"
export HYG_PKG_CACHES="$HOME/Library/Caches/CocoaPods"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
action_of(){ /usr/bin/awk -F'\t' -v p="$1" '$5==p{print $2}' "$FX/plan.tsv"; }

# --- session dirs: one repo cloned from a bare origin, committed and pushed
git init -q --bare "$FX/origin.git"
mksession(){ local s="$HOME/code/wt/$1"; mkdir -p "$s"; git clone -q "$FX/origin.git" "$s/repo" 2>/dev/null
  (cd "$s/repo" && echo x > f && git add f && git commit -qm c && git push -q origin HEAD:refs/heads/"$1" 2>/dev/null); echo notes > "$s/PROMPT.md"; }
mksession stale-clean; old "$HOME/code/wt/stale-clean"
mksession stale-dirty; echo wip > "$HOME/code/wt/stale-dirty/repo/wip.txt"; old "$HOME/code/wt/stale-dirty"
mksession fresh                                   # files touched now
mksession stale-stash; (cd "$HOME/code/wt/stale-stash/repo" && echo s >> f && git stash -q); old "$HOME/code/wt/stale-stash"
mksession stale-branch; (cd "$HOME/code/wt/stale-branch/repo" && git checkout -qb local-only && echo b > g && git add g && git commit -qm b && git checkout -q -); old "$HOME/code/wt/stale-branch"
mksession stale-filter; (cd "$HOME/code/wt/stale-filter/repo" && git config filter.evil.clean "touch $FX/PWNED"); old "$HOME/code/wt/stale-filter"
mksession stale-submod; (cd "$HOME/code/wt/stale-submod/repo" && printf '[submodule "x"]\n\tpath = x\n\turl = ../x\n' > .gitmodules && git add .gitmodules && git commit -qm sm && git push -q origin HEAD:refs/heads/stale-submod 2>/dev/null); old "$HOME/code/wt/stale-submod"
mksession stale-gitlink; (cd "$HOME/code/wt/stale-gitlink/repo" && git update-index --add --cacheinfo 160000,$(git rev-parse HEAD),sub && git commit -qm gl && git push -q origin HEAD:refs/heads/stale-gitlink 2>/dev/null); old "$HOME/code/wt/stale-gitlink"
mksession stale-deep; mkdir -p "$HOME/code/wt/stale-deep/a/b/c/d/e/node_modules/pkg"; git init -q "$HOME/code/wt/stale-deep/a/b/c/d/e/node_modules/pkg"; echo u > "$HOME/code/wt/stale-deep/a/b/c/d/e/node_modules/pkg/wip"; old "$HOME/code/wt/stale-deep"

# --- stale origin refs: a commit lands on local main, origin/main stays behind; origin is then repointed
#     at a github.com URL. A fake gh answers `compare SHA...main` from $FX/default-shas.
mkstale(){ mksession "$1"; (cd "$HOME/code/wt/$1/repo" && echo "$1" > h && git add h && git commit -qm "$1" \
  && git remote set-url origin "${2:-https://github.com/o/r.git}"); old "$HOME/code/wt/$1"; }
mkstale stale-on-default; git -C "$HOME/code/wt/stale-on-default/repo" rev-parse HEAD > "$FX/default-shas"
mkstale stale-off-default
mkstale stale-bad-url "https://evil.example/x?github.com/o/r/../../u"; git -C "$HOME/code/wt/stale-bad-url/repo" rev-parse HEAD >> "$FX/default-shas"
cat > "$FX/fake-gh" <<FAKE
#!/bin/bash
[ "\$1" = api ] || exit 1
case "\$2" in repos/o/r) echo main; exit 0;; esac
sha=\$(echo "\$2" | sed -nE 's#^repos/o/r/compare/([0-9a-f]{40})\\.\\.\\.main\$#\\1#p')
[ -n "\$sha" ] || exit 1
echo "\$2" >> "$FX/gh-calls"
grep -qxF "\$sha" "$FX/default-shas" && echo 1 || echo 0
FAKE
chmod +x "$FX/fake-gh"
# --- linked worktree in a session; its parent repo lives outside the session
git clone -q "$FX/origin.git" "$HOME/code/parent" 2>/dev/null
(cd "$HOME/code/parent" && echo p > p && git add p && git commit -qm p && git push -q origin HEAD:refs/heads/parent-base 2>/dev/null)
mkdir -p "$HOME/code/wt/wt-on-branch" "$HOME/code/wt/wt-detached"
git -C "$HOME/code/parent" worktree add -q -b card-local "$HOME/code/wt/wt-on-branch/repo" 2>/dev/null
(cd "$HOME/code/wt/wt-on-branch/repo" && echo w > w && git add w && git commit -qm "local only"); WT_SHA=$(git -C "$HOME/code/wt/wt-on-branch/repo" rev-parse HEAD)
git -C "$HOME/code/parent" worktree add -q --detach "$HOME/code/wt/wt-detached/repo" 2>/dev/null
(cd "$HOME/code/wt/wt-detached/repo" && echo d > d && git add d && git commit -qm "detached only")
old "$HOME/code/wt/wt-on-branch" "$HOME/code/wt/wt-detached"
mkdir -p "$HOME/code/wt/wt-parent-inside"; git clone -q --bare "$FX/origin.git" "$HOME/code/wt/wt-parent-inside/store" 2>/dev/null
git -C "$HOME/code/wt/wt-parent-inside/store" worktree add -q -b inside-only "$HOME/code/wt/wt-parent-inside/repo" stale-clean 2>/dev/null
(cd "$HOME/code/wt/wt-parent-inside/repo" && echo i > i && git add i && git commit -qm "only in the inside parent"); old "$HOME/code/wt/wt-parent-inside"
mkdir -p "$HOME/code/wt/bare-only"; git clone -q --bare "$HOME/code/wt/stale-branch/repo" "$HOME/code/wt/bare-only/store.git" 2>/dev/null; old "$HOME/code/wt/bare-only"

# --- gradle: three old dists with distinct ages; newest two must stay
for v in 8.11.1 8.14.3 9.5.0; do mkdir -p "$HOME/.gradle/wrapper/dists/gradle-$v-bin/x"; done
touch -t 202501010000 "$HOME/.gradle/wrapper/dists/gradle-8.11.1-bin"
touch -t 202502010000 "$HOME/.gradle/wrapper/dists/gradle-8.14.3-bin"
touch -t 202503010000 "$HOME/.gradle/wrapper/dists/gradle-9.5.0-bin"
# --- iOS DeviceSupport: two old, the newer must stay
mkdir -p "$HOME/ds/iPhone 17.0" "$HOME/ds/iPhone 18.0"
touch -t 202401010000 "$HOME/ds/iPhone 17.0"; touch -t 202402010000 "$HOME/ds/iPhone 18.0"
# --- android: an old cache entry, and an AVD that must never appear
mkdir -p "$HOME/.android/cache" "$HOME/.android/avd/pixel.avd"; echo c > "$HOME/.android/cache/sdkbin-1"; old "$HOME/.android/cache/sdkbin-1"
# --- CocoaPods cache, idle
mkdir -p "$HOME/Library/Caches/CocoaPods/Pods"; echo p > "$HOME/Library/Caches/CocoaPods/Pods/a"; old "$HOME/Library/Caches/CocoaPods"

bash "$HYG" plan > "$FX/plan.tsv" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"

[ "$(action_of "$HOME/code/wt/stale-clean")" = remove ] && ok "stale session with clean pushed nested repo → remove" || bad "stale-clean not removable: $(grep stale-clean "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-dirty")" = keep ] && ok "stale session with a dirty nested repo → keep" || bad "stale-dirty: $(grep stale-dirty "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-stash")" = keep ] && ok "nested clone with a stash → keep" || bad "stale-stash: $(grep stale-stash "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-branch")" = keep ] && ok "nested clone with an unpushed local branch → keep" || bad "stale-branch: $(grep stale-branch "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-filter")" = keep ] && [ ! -e "$FX/PWNED" ] && ok "repo whose config defines a filter driver → keep, driver never ran" || bad "stale-filter: $(grep stale-filter "$FX/plan.tsv") pwned=$( [ -e "$FX/PWNED" ] && echo yes || echo no)"
[ "$(action_of "$HOME/code/wt/stale-submod")" = keep ] && ok "repo with submodules → keep unread" || bad "stale-submod: $(grep stale-submod "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-gitlink")" = keep ] && ok "gitlink without .gitmodules → keep unread" || bad "stale-gitlink: $(grep stale-gitlink "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/stale-deep")" = keep ] && ok "dirty repo deep inside node_modules → keep (search not pruned)" || bad "stale-deep: $(grep stale-deep "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/fresh")" = keep ] && ok "recently touched session → keep" || bad "fresh: $(grep '/fresh' "$FX/plan.tsv")"
[ "$(action_of "$HOME/.gradle/wrapper/dists/gradle-8.11.1-bin")" = remove ] && ok "oldest Gradle dist → remove" || bad "gradle 8.11.1: $(grep 8.11.1 "$FX/plan.tsv")"
[ "$(action_of "$HOME/.gradle/wrapper/dists/gradle-8.14.3-bin")" = keep ] && [ "$(action_of "$HOME/.gradle/wrapper/dists/gradle-9.5.0-bin")" = keep ] && ok "newest two Gradle dists → keep" || bad "gradle newest two not kept"
[ "$(action_of "$HOME/ds/iPhone 17.0")" = remove ] && ok "old DeviceSupport → remove" || bad "ds 17: $(grep 'iPhone 17' "$FX/plan.tsv")"
[ "$(action_of "$HOME/ds/iPhone 18.0")" = keep ] && ok "newest DeviceSupport → keep" || bad "ds 18: $(grep 'iPhone 18' "$FX/plan.tsv")"
[ "$(action_of "$HOME/.android/cache/sdkbin-1")" = remove ] && ok "old android cache → remove" || bad "android cache: $(grep sdkbin "$FX/plan.tsv")"
grep -q '/avd' "$FX/plan.tsv" && bad "an AVD appeared in the plan" || ok "AVD never a candidate"
[ "$(action_of "$HOME/Library/Caches/CocoaPods")" = remove ] && ok "idle CocoaPods cache → remove" || bad "cocoapods: $(grep CocoaPods "$FX/plan.tsv")"

# --- linked worktrees need no gh: decided in the first plan
[ "$(action_of "$HOME/code/wt/wt-on-branch")" = remove ] && ok "clean linked worktree on a parent-repo branch → remove" || bad "wt-on-branch: $(grep wt-on-branch "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/bare-only")" = keep ] && ok "session holding only a bare repo → keep" || bad "bare-only: $(grep bare-only "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/wt-parent-inside")" = keep ] && ok "worktree whose bare parent is inside the session → keep" || bad "wt-parent-inside: $(grep wt-parent-inside "$FX/plan.tsv")"
[ "$(action_of "$HOME/code/wt/wt-detached")" = keep ] && ok "linked worktree on a detached HEAD no branch holds → keep" || bad "wt-detached: $(grep wt-detached "$FX/plan.tsv")"
# --- GitHub default-branch check: off above, on below with the fake gh
[ "$(action_of "$HOME/code/wt/stale-on-default")" = keep ] && ok "gh check off → stale-ref clone kept" || bad "stale-on-default with check off: $(grep stale-on-default "$FX/plan.tsv")"
HYG_WT_MERGED_PR_CHECK=1 HYG_GH="$FX/fake-gh" bash "$HYG" plan > "$FX/plan-gh.tsv" 2>/dev/null
gh_action(){ /usr/bin/awk -F'\t' -v p="$1" '$5==p{print $2}' "$FX/plan-gh.tsv"; }
[ "$(gh_action "$HOME/code/wt/stale-on-default")" = remove ] && ok "clone commit on GitHub's default branch → remove" || bad "stale-on-default: $(grep stale-on-default "$FX/plan-gh.tsv")"
[ "$(gh_action "$HOME/code/wt/stale-off-default")" = keep ] && ok "clone commit GitHub's default branch lacks → keep" || bad "stale-off-default: $(grep stale-off-default "$FX/plan-gh.tsv")"
[ "$(gh_action "$HOME/code/wt/stale-bad-url")" = keep ] && ok "crafted origin URL → no gh call, keep" || bad "stale-bad-url: $(grep stale-bad-url "$FX/plan-gh.tsv")"
grep -q evil "$FX/gh-calls" 2>/dev/null && bad "gh was called for the crafted URL" || ok "gh never called for the crafted URL"
[ "$(gh_action "$HOME/code/wt/stale-dirty")" = keep ] && ok "gh check never overrides dirty work" || bad "stale-dirty with gh: $(grep stale-dirty "$FX/plan-gh.tsv")"
HYG_WT_MERGED_PR_CHECK=1 HYG_GH="$FX/fake-gh" HYG_GH_SHA_CHECK_MAX=0 bash "$HYG" plan > "$FX/plan-cap.tsv" 2>/dev/null
[ "$(/usr/bin/awk -F'\t' -v p="$HOME/code/wt/stale-on-default" '$5==p{print $2}' "$FX/plan-cap.tsv")" = keep ] && ok "gh call cap reached → keep" || bad "cap: $(grep stale-on-default "$FX/plan-cap.tsv")"

# --- run with the lock held removes nothing
mkdir "$HYG_LOCK"; bash "$HYG" run >/dev/null 2>&1
[ -d "$HOME/code/wt/stale-clean" ] && grep -q 'skipped: previous run still holds' "$HYG_LOG" && ok "held lock → run skipped" || bad "run did not respect the lock"
rmdir "$HYG_LOCK"

# --- apply the real plan
/usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$FX/plan.tsv" > "$FX/apply.tsv"
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
[ ! -e "$HOME/code/wt/stale-clean" ] && ok "apply removed the clean stale session" || bad "stale-clean still there: $(cat "$FX/apply.out")"
[ -f "$HOME/code/wt/stale-dirty/repo/wip.txt" ] && ok "dirty session's work survived" || bad "dirty work lost"
[ -d "$HOME/.gradle/wrapper/dists/gradle-9.5.0-bin" ] && [ ! -e "$HOME/.gradle/wrapper/dists/gradle-8.11.1-bin" ] && ok "gradle apply kept newest, removed oldest" || bad "gradle apply wrong"
[ -d "$HOME/.android/avd/pixel.avd" ] && ok "AVD intact after apply" || bad "AVD gone"
[ ! -e "$HOME/code/wt/wt-on-branch" ] && [ "$(git -C "$HOME/code/parent" rev-parse card-local 2>/dev/null)" = "$WT_SHA" ] \
  && [ -z "$(git -C "$HOME/code/parent" worktree list --porcelain | grep wt-on-branch)" ] \
  && ok "linked worktree removed, its unpushed branch survives in the parent, metadata pruned" || bad "wt-on-branch apply: $(cat "$FX/apply.out")"
[ -d "$HOME/code/wt/wt-detached/repo" ] && ok "detached worktree survived apply" || bad "detached worktree lost"

echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
