#!/bin/bash
# hygiene-retention.test.sh — card iTGD34Ub AC 2, CTO ruling 6ae7919566f264486f337e8e, REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-NEGATIVE  retention unset (the public default) → dirty and unpushed folders keep, unchanged
#   KNOWN-POSITIVE  dirty folder idle over the window → removed after a verified archive; the patch restores the edit
#   KNOWN-POSITIVE  F3 the patch is not empty under the script's own git flags
#   KNOWN-POSITIVE  F4 two stashes → both restored from the bundle
#   KNOWN-POSITIVE  an unpushed branch and a tag-only commit → restored from the bundle
#   KNOWN-POSITIVE  a deletion-only repo → the patch stays small, deleted paths are in the manifest
#   KNOWN-NEGATIVE  rescue command fails → refused, folder intact, no ledger line
#   KNOWN-NEGATIVE  rescue command unset → kept, even with the window set
#   KNOWN-NEGATIVE  a repo that only committed inside the window → kept (.git metadata counts as a touch)
#   KNOWN-NEGATIVE  a repo config that can run commands, a linked worktree outside → kept, named blocker
#   KNOWN-NEGATIVE  a non-terminal registry row dated inside the grace, or with no date → kept
#   KNOWN-POSITIVE  a non-terminal row older than the grace → retention applies
#   KNOWN-NEGATIVE  .env, *.pem and ignored files never reach the archive; names are in the manifest
#   KNOWN-POSITIVE  an over-cap untracked file is dropped and listed with its sha256, the folder still goes
#   KNOWN-NEGATIVE  commits and patches over the cap → kept
#   KNOWN-NEGATIVE  HYG_RETENTION_MAX_PER_RUN stops the rest, which stay intact
#   KNOWN-POSITIVE  userinfo in a remote URL does not reach the manifest
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-ret.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
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
BUCKET="$FX/bucket"; mkdir -p "$BUCKET"
cat > "$FX/up-ok.sh" <<'UP'
#!/bin/bash
mkdir -p "$BUCKET/$2" && cp "$1"/* "$BUCKET/$2/"
UP
printf '#!/bin/bash\nexit 1\n' > "$FX/up-fail.sh"; chmod +x "$FX/up-ok.sh" "$FX/up-fail.sh"; export BUCKET

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$1" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
row(){ /usr/bin/awk -F'\t' -v p="$W/$2" '$1=="session-dirs" && $5==p{print $2"/"$4}' "$1"; }
git init -q --bare "$FX/origin.git"; git -C "$FX/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$FX/origin.git" "$FX/seed" 2>/dev/null; ( cd "$FX/seed" && git checkout -q -b main && echo base > tracked && echo gone > gone1 && printf 'node_modules\n.env\nsecret-ignored\n' > .gitignore && git add . && git commit -qm base && git push -q origin main )
mk(){ git clone -q "$FX/origin.git" "$W/$1" 2>/dev/null; }
RET="HYG_RETENTION_DAYS=7 HYG_RESCUE_CMD=$FX/up-ok.sh HYG_RETENTION_MAX_PER_RUN=50"
plan_ret(){ env $RET bash "$HYG" plan > "$1" 2>/dev/null; }
restore(){ local pfx; pfx=$(/bin/ls -d "$BUCKET"/*/*/"$1" | head -1); mkdir -p "$FX/r/$1"; cat "$pfx"/part-*.b64 | /usr/bin/base64 -D | /usr/bin/tar -xzf - -C "$FX/r/$1"; printf '%s' "$pfx"; }

mk a-dirty; echo edit >> "$W/a-dirty/tracked"; old "$W/a-dirty"
mk b-stash; ( cd "$W/b-stash" && echo s1 >> tracked && git stash -q && echo s2 >> tracked && git stash -q ); old "$W/b-stash"
mk c-unpushed; ( cd "$W/c-unpushed" && git checkout -q -b wip && echo c > c && git add c && git commit -qm wip-commit && git tag only-tag && git checkout -q main && git branch -qD wip ); old "$W/c-unpushed"
mk d-deleted; ( cd "$W/d-deleted" && rm gone1 ); old "$W/d-deleted"
mk e-fails; echo edit >> "$W/e-fails/tracked"; old "$W/e-fails"
mk f-recentmeta; ( cd "$W/f-recentmeta" && echo x > x && git add x && git commit -qm x ); /usr/bin/find "$W/f-recentmeta" -name .git -prune -o -exec touch -h -t 202601010000 {} + 2>/dev/null
mk g-filter; git -C "$W/g-filter" config filter.evil.clean 'touch /tmp/pwned-hyg-ret'; echo edit >> "$W/g-filter/tracked"; old "$W/g-filter"
mk h-wtowner; git -C "$W/h-wtowner" worktree add -q -b out "$FX/outside" 2>/dev/null; echo edit >> "$W/h-wtowner/tracked"; old "$W/h-wtowner"
mk i-frozen; echo edit >> "$W/i-frozen/tracked"; old "$W/i-frozen"
mk j-recentrow; echo edit >> "$W/j-recentrow/tracked"; old "$W/j-recentrow"
mk k-nodaterow; echo edit >> "$W/k-nodaterow/tracked"; old "$W/k-nodaterow"
mk l-secrets; ( cd "$W/l-secrets" && echo edit >> tracked && echo S3CRET > .env && echo S3CRET > server.pem && echo S3CRET > secret-ignored && echo keepme > note.txt ); old "$W/l-secrets"
mkdir -p "$W/m-plain/nest"; git clone -q "$FX/origin.git" "$W/m-plain/nest/inner" 2>/dev/null; echo edit >> "$W/m-plain/nest/inner/tracked"; echo loose > "$W/m-plain/loose.md"; echo S3CRET > "$W/m-plain/.env"; old "$W/m-plain"
mk n-bigfile; ( cd "$W/n-bigfile" && dd if=/dev/urandom of=big.bin bs=1048576 count=6 2>/dev/null ); old "$W/n-bigfile"
mk o-toobig; ( cd "$W/o-toobig" && dd if=/dev/urandom of=huge bs=1048576 count=24 2>/dev/null && git add huge && git commit -qm huge ); old "$W/o-toobig"
mk p-url; git -C "$W/p-url" remote set-url origin "https://user:tok3n@example.invalid/o/r.git"; echo edit >> "$W/p-url/tracked"; old "$W/p-url"
cat > "$HYG_SESSIONS_JSON" <<JSON
[ {"session":"i-frozen","status":"running","started_at":"2026-01-02T10:00+02:00"},
  {"session":"j-recentrow","status":"running","started_at":"$(/bin/date +%F)T10:00+02:00"},
  {"session":"k-nodaterow","status":"running"} ]
JSON

# default off
bash "$HYG" plan > "$FX/off.tsv" 2>/dev/null
[ "$(row "$FX/off.tsv" a-dirty)" = keep/clone-dirty-uncommitted-work ] && ok "retention off → dirty kept" || bad "off: $(row "$FX/off.tsv" a-dirty)"
[ "$(row "$FX/off.tsv" i-frozen)" = keep/session-alive-in-registry ] && ok "retention off → registry rows bind as before" || bad "off row: $(row "$FX/off.tsv" i-frozen)"
HYG_RETENTION_DAYS=7 bash "$HYG" plan > "$FX/nocmd.tsv" 2>/dev/null
[ "$(row "$FX/nocmd.tsv" a-dirty)" = keep/clone-dirty-uncommitted-work ] && ok "no rescue command → kept" || bad "nocmd: $(row "$FX/nocmd.tsv" a-dirty)"

P="$FX/plan.tsv"; plan_ret "$P"
for f in a-dirty b-stash c-unpushed d-deleted i-frozen l-secrets m-plain n-bigfile p-url; do
  case "$(row "$P" $f)" in remove/retention-rescue-*) ok "$f planned for rescue";; *) bad "$f: $(row "$P" $f)";; esac; done
case "$(row "$P" f-recentmeta)" in keep/*) ok "metadata touched inside the window → kept";; *) bad "f-recentmeta: $(row "$P" f-recentmeta)";; esac
case "$(row "$P" g-filter)" in keep/*can-run-commands) ok "command-running config → kept";; *) bad "g-filter: $(row "$P" g-filter)";; esac
case "$(row "$P" h-wtowner)" in keep/retention-blocked-has-linked-worktrees) ok "linked worktree outside → kept, named";; *) bad "h: $(row "$P" h-wtowner)";; esac
[ "$(row "$P" j-recentrow)" = keep/session-alive-in-registry ] && ok "row inside the grace → kept" || bad "j: $(row "$P" j-recentrow)"
[ "$(row "$P" k-nodaterow)" = keep/session-alive-in-registry ] && ok "row with no date → kept" || bad "k: $(row "$P" k-nodaterow)"
[ -d "$W/a-dirty" ] && [ ! -e "$BUCKET/x" ] && ok "plan removed and uploaded nothing" || bad "plan wrote"

# Failed upload: everything stays
printf 'session-dirs\t%s\n' "$W/e-fails" > "$FX/f.tsv"
HYG_RETENTION_DAYS=7 HYG_RESCUE_CMD="$FX/up-fail.sh" bash "$HYG" apply "$FX/f.tsv" > "$FX/f.out" 2>&1
[ -f "$W/e-fails/tracked" ] && /usr/bin/grep -q $'refused\t.*rescue-upload-unverified' "$FX/f.out" && ok "failed upload → refused, folder intact" || bad "fail: $(cat "$FX/f.out")"
[ ! -s "$FX/state/rescued.tsv" ] && ok "failed upload → no ledger line" || bad "ledger written on failure"

# Apply for real, under a cap first
/usr/bin/awk -F'\t' '$2=="remove" && $1=="session-dirs"{print $1"\t"$5}' "$P" | /usr/bin/grep -E '/(a-dirty|b-stash|c-unpushed|d-deleted|i-frozen|l-secrets|m-plain|n-bigfile|p-url)$' > "$FX/go.tsv"
env HYG_RETENTION_DAYS=7 HYG_RESCUE_CMD="$FX/up-ok.sh" HYG_RETENTION_MAX_PER_RUN=2 bash "$HYG" apply "$FX/go.tsv" > "$FX/cap.out" 2>&1
[ "$(/usr/bin/grep -c $'\tremoved\t' "$FX/cap.out")" = 2 ] && [ "$(/usr/bin/grep -c 'retention-cap-reached' "$FX/cap.out")" -ge 1 ] && ok "cap stops the run at 2" || bad "cap: $(cat "$FX/cap.out")"
env $RET bash "$HYG" apply "$FX/go.tsv" > "$FX/go.out" 2>&1
for f in a-dirty b-stash c-unpushed d-deleted i-frozen l-secrets m-plain n-bigfile p-url; do [ ! -e "$W/$f" ] && ok "$f removed" || bad "$f still there: $(grep "$f" "$FX/go.out")"; done
[ "$(/usr/bin/wc -l < "$FX/state/rescued.tsv" | tr -d ' ')" = 9 ] && ok "9 ledger lines" || bad "ledger: $(cat "$FX/state/rescued.tsv")"

# Restore drills
restore a-dirty >/dev/null; git clone -q "$FX/origin.git" "$FX/r/a-co" 2>/dev/null
[ -s "$FX/r/a-dirty/repo-1/changes.patch" ] && git -C "$FX/r/a-co" apply "$FX/r/a-dirty/repo-1/changes.patch" && /usr/bin/grep -q edit "$FX/r/a-co/tracked" && ok "F3 patch restores the edit" || bad "F3 patch"
restore b-stash >/dev/null; git init -q "$FX/r/b-co"; git -C "$FX/r/b-co" fetch -q "$FX/origin.git" main 2>/dev/null; git -C "$FX/r/b-co" fetch -q "$FX/r/b-stash/repo-1/local.bundle" 'refs/*:refs/restored/*' 2>/dev/null
n=$(git -C "$FX/r/b-co" for-each-ref --format=x 'refs/restored/hygiene-rescue/' | wc -l | tr -d ' '); [ "$n" = 2 ] && ok "F4 both stashes in the bundle" || bad "F4 stash refs: $n"
restore c-unpushed >/dev/null; git init -q "$FX/r/c-co"; git -C "$FX/r/c-co" fetch -q "$FX/origin.git" main 2>/dev/null; git -C "$FX/r/c-co" fetch -q "$FX/r/c-unpushed/repo-1/local.bundle" 'refs/*:refs/restored/*' 2>/dev/null
git -C "$FX/r/c-co" log --all --format=%s | /usr/bin/grep -q wip-commit && ok "tag-only commit restored from the bundle" || bad "tag-only commit"
pfx=$(restore d-deleted); [ "$(/usr/bin/wc -c < "$FX/r/d-deleted/repo-1/changes.patch" | tr -d ' ')" = 0 ] && /usr/bin/jq -e '.entries[]|select(.kind=="deleted-in-worktree" and (.path|endswith("gone1")))' "$pfx/manifest.json" >/dev/null && ok "deletion-only: empty patch, deleted path listed" || bad "deletion: $(cat "$pfx/manifest.json")"
pfx=$(restore l-secrets)
if /usr/bin/grep -rlq S3CRET "$FX/r/l-secrets"; then bad "secrets reached the archive: $(/usr/bin/grep -rl S3CRET "$FX/r/l-secrets")"; else ok "name-denied and ignored files are not in the archive"; fi
[ -f "$FX/r/l-secrets/files/note.txt" ] && ok "ordinary untracked file is archived" || bad "note.txt missing: $(find "$FX/r/l-secrets" -type f)"
/usr/bin/jq -e '[.entries[]|select(.kind=="denied-by-name")|.path]|contains(["server.pem"])' "$pfx/manifest.json" >/dev/null && /usr/bin/jq -e '[.entries[]|select(.kind=="ignored-not-archived")]|length>0' "$pfx/manifest.json" >/dev/null && ok "denied and ignored names are listed" || bad "manifest names: $(cat "$pfx/manifest.json")"
pfx=$(restore m-plain); [ -f "$FX/r/m-plain/files/loose.md" ] && [ ! -e "$FX/r/m-plain/files/.env" ] && [ -s "$FX/r/m-plain/repo-1/changes.patch" ] && ok "plain folder: loose file and nested patch archived, loose .env not" || bad "m-plain: $(find "$FX/r/m-plain" -type f)"
pfx=$(restore n-bigfile); /usr/bin/jq -e '.entries[]|select(.kind=="dropped-over-file-cap" and .path=="big.bin" and (.detail|test("[0-9a-f]{64}")))' "$pfx/manifest.json" >/dev/null && ok "over-cap file dropped, sha256 listed" || bad "bigfile: $(cat "$pfx/manifest.json")"
pfx=$(restore p-url); /usr/bin/grep -q tok3n "$pfx/manifest.json" && bad "token in manifest" || ok "remote userinfo stripped"

# Commits over the cap stay
printf 'session-dirs\t%s\n' "$W/o-toobig" > "$FX/big.tsv"
env $RET bash "$HYG" apply "$FX/big.tsv" > "$FX/big.out" 2>&1
[ -d "$W/o-toobig/.git" ] && /usr/bin/grep -q 'rescue-commits-and-patches-over-cap' "$FX/big.out" && ok "commits over the cap → kept" || bad "toobig: $(cat "$FX/big.out")"

echo "# pass=$PASS fail=$FAILN"; [ "$FAILN" = 0 ]
