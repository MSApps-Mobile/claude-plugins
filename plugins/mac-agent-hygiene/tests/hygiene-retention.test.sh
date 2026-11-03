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
#   Review 5748468367 (each fixture removed a folder holding real work at d38ec68c; each keeps it, or archives it whole, now):
#   B1  KNOWN-POSITIVE  untracked Hebrew and `with space"q.txt` names are in the archive and listed `archived`
#   B1  KNOWN-NEGATIVE  a listed untracked path that is not on disk → kept, rescue-path-unresolved
#   B2  KNOWN-NEGATIVE  an unreadable (mode 000) untracked file → kept, rescue-copy-failed, no ledger line
#   B3  KNOWN-NEGATIVE  a linked worktree in ~/code/wt with a running registry row inside the grace → kept
#   B3  KNOWN-POSITIVE  the same with a frozen row (older than the grace) → retention applies through the worktrees pass
#   B4  KNOWN-NEGATIVE  a bare repo inside a linked worktree → kept, contains-bare-or-separate-git-dir
#   B5  KNOWN-NEGATIVE  update-ref fails for the stash refs → kept, rescue-stash-refs-failed
#   S1  KNOWN-NEGATIVE  a denied name in an unpushed commit, or in the patch of tracked edits → kept
#   S1  KNOWN-NEGATIVE  a decoy x.pem in the cwd no longer turns *.pem into a literal (server.pem stays out)
#   S1  KNOWN-NEGATIVE  Server.PEM (upper case) stays out; a .env in an orphan root commit keeps under log.showRoot=false
#       KNOWN-NEGATIVE  a tracked file behind a symlinked parent dir (outside the folder) is listed, never copied
#       KNOWN-NEGATIVE  HYG_RETENTION_DAYS=0 is refused; refs/hygiene-rescue/* are gone after a refused rescue
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="${HYG_UNDER_TEST:-$HERE/../scripts/hygiene.sh}"   # HYG_UNDER_TEST: run these fixtures against another revision
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
# A git that fails on demand: FAKE_NO_UPDATEREF (B5), FAKE_GHOST appends a name not on disk to the untracked list (B1).
cat > "$FX/git-fake.sh" <<'GF'
#!/bin/bash
ls=0; o=0; i=0; z=0
for a in "$@"; do case "$a" in update-ref) [ -n "${FAKE_NO_UPDATEREF:-}" ] && exit 1;; ls-files) ls=1;; -o) o=1;; -i) i=1;; -z) z=1;; esac; done
if [ -n "${FAKE_GHOST:-}" ] && [ $ls = 1 ] && [ $o = 1 ] && [ $i = 0 ]; then
  /usr/bin/git "$@" || exit; if [ $z = 1 ]; then printf 'ghost-not-on-disk\0'; else printf 'ghost-not-on-disk\n'; fi; exit 0; fi
exec /usr/bin/git "$@"
GF
chmod +x "$FX/git-fake.sh"

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
wrow(){ /usr/bin/awk -F'\t' -v p="$W/$2" '$1=="worktrees" && $5==p{print $2"/"$4}' "$1"; }
LEDGER="$FX/state/archived.tsv"
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
# review 5748468367 fixtures
mk q-hebrew; ( cd "$W/q-hebrew" && echo edit >> tracked && echo shalom > "שלום.md" && echo quoted > 'with space"q.txt' ); old "$W/q-hebrew"
mk q-ghost; echo edit >> "$W/q-ghost/tracked"; old "$W/q-ghost"
mk r-locked; ( cd "$W/r-locked" && echo edit >> tracked && echo locked > locked.txt ); old "$W/r-locked"; chmod 000 "$W/r-locked/locked.txt"
git clone -q "$FX/origin.git" "$FX/wtmain" 2>/dev/null
for wt in s-linked-live s2-linked-frozen t-linked-bare; do git -C "$FX/wtmain" worktree add -q -b "$wt" "$W/$wt" 2>/dev/null; echo edit >> "$W/$wt/tracked"; done
git init -q --bare "$W/t-linked-bare/stash.git"
old "$W/s-linked-live"; old "$W/s2-linked-frozen"; old "$W/t-linked-bare"; old "$FX/wtmain"
mk u-stashfail; ( cd "$W/u-stashfail" && echo s1 >> tracked && git stash -q && echo s2 >> tracked && git stash -q ); old "$W/u-stashfail"
mk v-envcommit; ( cd "$W/v-envcommit" && echo S3CRET > .env && git add -f .env && git commit -qm env ); old "$W/v-envcommit"
mk v-keypatch; ( cd "$W/v-keypatch" && git checkout -q -b s1 && echo k1 > cfg.key && git add cfg.key && git commit -qm key && git push -q origin s1 && echo S3CRET >> cfg.key ) 2>/dev/null; old "$W/v-keypatch"
mk v-rootenv; ( cd "$W/v-rootenv" && git checkout -q --orphan o && git rm -rqf --cached . && echo S3CRET > .env && git add -f .env && git commit -qm root-env && git config log.showRoot false ); old "$W/v-rootenv"
mkdir -p "$FX/outside-sub"; mk x-symparent; ( cd "$W/x-symparent" && git checkout -q -b x1 && mkdir sub && echo in > sub/x && git add sub/x && git commit -qm sub && git push -q origin x1 && git update-index --assume-unchanged sub/x && rm -rf sub && echo OUTSIDE > "$FX/outside-sub/x" && ln -s "$FX/outside-sub" sub ) 2>/dev/null; old "$W/x-symparent"
mk w-stashup; ( cd "$W/w-stashup" && echo s1 >> tracked && git stash -q ); old "$W/w-stashup"
cat > "$HYG_SESSIONS_JSON" <<JSON
[ {"session":"i-frozen","status":"running","started_at":"2026-01-02T10:00+02:00"},
  {"session":"j-recentrow","status":"running","started_at":"$(/bin/date +%F)T10:00+02:00"},
  {"session":"k-nodaterow","status":"running"},
  {"session":"s-linked-live","status":"running","started_at":"$(/bin/date +%F)T09:00+02:00"},
  {"session":"s2-linked-frozen","status":"running","started_at":"2026-01-02T10:00+02:00"} ]
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
[ ! -s "$LEDGER" ] && ok "failed upload → no ledger line" || bad "ledger written on failure"

# Apply for real, under a cap first
/usr/bin/awk -F'\t' '$2=="remove" && $1=="session-dirs"{print $1"\t"$5}' "$P" | /usr/bin/grep -E '/(a-dirty|b-stash|c-unpushed|d-deleted|i-frozen|l-secrets|m-plain|n-bigfile|p-url)$' > "$FX/go.tsv"
env HYG_RETENTION_DAYS=7 HYG_RESCUE_CMD="$FX/up-ok.sh" HYG_RETENTION_MAX_PER_RUN=2 bash "$HYG" apply "$FX/go.tsv" > "$FX/cap.out" 2>&1
[ "$(/usr/bin/grep -c $'\tremoved\t' "$FX/cap.out")" = 2 ] && [ "$(/usr/bin/grep -c 'retention-cap-reached' "$FX/cap.out")" -ge 1 ] && ok "cap stops the run at 2" || bad "cap: $(cat "$FX/cap.out")"
mkdir -p "$FX/globcwd"; : > "$FX/globcwd/x.pem"; : > "$FX/globcwd/decoy.key"; ln -s /etc/hosts "$W/l-secrets/hosts-link"; echo S3CRET > "$W/l-secrets/Server.PEM"; old "$W/l-secrets"
( cd "$FX/globcwd" && env $RET bash "$HYG" apply "$FX/go.tsv" ) > "$FX/go.out" 2>&1
for f in a-dirty b-stash c-unpushed d-deleted i-frozen l-secrets m-plain n-bigfile p-url; do [ ! -e "$W/$f" ] && ok "$f removed" || bad "$f still there: $(grep "$f" "$FX/go.out")"; done
[ "$(/usr/bin/wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')" = 9 ] && ok "9 ledger lines" || bad "ledger: $(cat "$LEDGER" 2>&1)"

# Restore drills
restore a-dirty >/dev/null; git clone -q "$FX/origin.git" "$FX/r/a-co" 2>/dev/null
pfx=$(/bin/ls -d "$BUCKET"/*/*/a-dirty | head -1)
/usr/bin/jq -e --arg s "$(/usr/bin/shasum -a 256 "$FX/r/a-dirty/repo-1/changes.patch" | cut -d' ' -f1)" '.entries[]|select(.kind=="archived" and .path=="repo-1/changes.patch" and .detail==$s)' "$pfx/manifest.json" >/dev/null && ok "manifest lists the patch as archived with its sha256" || bad "archived entry: $(cat "$pfx/manifest.json")"
[ -s "$FX/r/a-dirty/repo-1/changes.patch" ] && git -C "$FX/r/a-co" apply "$FX/r/a-dirty/repo-1/changes.patch" && /usr/bin/grep -q edit "$FX/r/a-co/tracked" && ok "F3 patch restores the edit" || bad "F3 patch"
restore b-stash >/dev/null; git init -q "$FX/r/b-co"; git -C "$FX/r/b-co" fetch -q "$FX/origin.git" main 2>/dev/null; git -C "$FX/r/b-co" fetch -q "$FX/r/b-stash/repo-1/local.bundle" 'refs/*:refs/restored/*' 2>/dev/null
n=$(git -C "$FX/r/b-co" for-each-ref --format=x 'refs/restored/hygiene-rescue/' | wc -l | tr -d ' '); [ "$n" = 2 ] && ok "F4 both stashes in the bundle" || bad "F4 stash refs: $n"
restore c-unpushed >/dev/null; git init -q "$FX/r/c-co"; git -C "$FX/r/c-co" fetch -q "$FX/origin.git" main 2>/dev/null; git -C "$FX/r/c-co" fetch -q "$FX/r/c-unpushed/repo-1/local.bundle" 'refs/*:refs/restored/*' 2>/dev/null
git -C "$FX/r/c-co" log --all --format=%s | /usr/bin/grep -q wip-commit && ok "tag-only commit restored from the bundle" || bad "tag-only commit"
pfx=$(restore d-deleted); [ "$(/usr/bin/wc -c < "$FX/r/d-deleted/repo-1/changes.patch" | tr -d ' ')" = 0 ] && /usr/bin/jq -e '.entries[]|select(.kind=="deleted-in-worktree" and (.path|endswith("gone1")))' "$pfx/manifest.json" >/dev/null && ok "deletion-only: empty patch, deleted path listed" || bad "deletion: $(cat "$pfx/manifest.json")"
pfx=$(restore l-secrets)
if /usr/bin/grep -rlq S3CRET "$FX/r/l-secrets"; then bad "secrets reached the archive: $(/usr/bin/grep -rl S3CRET "$FX/r/l-secrets")"; else ok "name-denied and ignored files are not in the archive"; fi
[ -f "$FX/r/l-secrets/files/note.txt" ] && ok "ordinary untracked file is archived" || bad "note.txt missing: $(find "$FX/r/l-secrets" -type f)"
/usr/bin/jq -e '.entries[]|select(.kind=="symlink-not-archived" and .path=="hosts-link" and .detail=="/etc/hosts")' "$pfx/manifest.json" >/dev/null && ok "untracked symlink listed with its target" || bad "symlink: $(cat "$pfx/manifest.json")"
/usr/bin/jq -e '[.entries[]|select(.kind=="denied-by-name")|.path]|contains(["server.pem"])' "$pfx/manifest.json" >/dev/null && /usr/bin/jq -e '[.entries[]|select(.kind=="ignored-not-archived")]|length>0' "$pfx/manifest.json" >/dev/null && ok "denied and ignored names are listed" || bad "manifest names: $(cat "$pfx/manifest.json")"
pfx=$(restore m-plain); [ -f "$FX/r/m-plain/files/loose.md" ] && [ ! -e "$FX/r/m-plain/files/.env" ] && [ -s "$FX/r/m-plain/repo-1/changes.patch" ] && ok "plain folder: loose file and nested patch archived, loose .env not" || bad "m-plain: $(find "$FX/r/m-plain" -type f)"
pfx=$(restore n-bigfile); /usr/bin/jq -e '.entries[]|select(.kind=="dropped-over-file-cap" and .path=="big.bin" and (.detail|test("[0-9a-f]{64}")))' "$pfx/manifest.json" >/dev/null && ok "over-cap file dropped, sha256 listed" || bad "bigfile: $(cat "$pfx/manifest.json")"
pfx=$(restore p-url); /usr/bin/grep -q tok3n "$pfx/manifest.json" && bad "token in manifest" || ok "remote userinfo stripped"

# Commits over the cap stay
printf 'session-dirs\t%s\n' "$W/o-toobig" > "$FX/big.tsv"
env $RET bash "$HYG" apply "$FX/big.tsv" > "$FX/big.out" 2>&1
[ -d "$W/o-toobig/.git" ] && /usr/bin/grep -q 'rescue-commits-and-patches-over-cap' "$FX/big.out" && ok "commits over the cap → kept" || bad "toobig: $(cat "$FX/big.out")"

# ---------- review 5748468367 ----------
HYG_RETENTION_DAYS=0 HYG_RESCUE_CMD="$FX/up-ok.sh" bash "$HYG" plan > /dev/null 2>&1; [ $? = 2 ] && ok "HYG_RETENTION_DAYS=0 refused" || bad "RETENTION_DAYS=0 accepted"
one(){ printf '%s\t%s\n' "$1" "$W/$2" > "$FX/one.tsv"; }
# B1
one session-dirs q-hebrew; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/q.out" 2>&1
pfx=$(restore q-hebrew 2>/dev/null)
[ ! -e "$W/q-hebrew" ] && [ "$(cat "$FX/r/q-hebrew/files/שלום.md" 2>/dev/null)" = shalom ] && [ "$(cat "$FX/r/q-hebrew/files/with space\"q.txt" 2>/dev/null)" = quoted ] \
  && ok "B1 Hebrew and quoted untracked names are in the archive" || bad "B1 names: $(cat "$FX/q.out"; find "$FX/r/q-hebrew" -type f 2>/dev/null)"
[ -n "$pfx" ] && /usr/bin/jq -e '[.entries[]|select(.kind=="archived")|.path]|contains(["files/שלום.md","files/with space\"q.txt"])' "$pfx/manifest.json" >/dev/null \
  && ok "B1 both listed as archived" || bad "B1 manifest: $(cat "$pfx/manifest.json" 2>/dev/null)"
one session-dirs q-ghost; env $RET HYG_GIT="$FX/git-fake.sh" FAKE_GHOST=1 bash "$HYG" apply "$FX/one.tsv" > "$FX/qg.out" 2>&1
[ -f "$W/q-ghost/tracked" ] && /usr/bin/grep -q $'refused\t.*rescue-path-unresolved' "$FX/qg.out" && ok "B1 a listed path not on disk → kept" || bad "B1 ghost: $(cat "$FX/qg.out")"
# B2
n0=$(/usr/bin/wc -l < "$LEDGER" | tr -d ' ')
one session-dirs r-locked; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/r.out" 2>&1
[ -e "$W/r-locked/locked.txt" ] && /usr/bin/grep -q $'refused\t.*rescue-copy-failed' "$FX/r.out" && ok "B2 unreadable untracked file → kept" || bad "B2: $(cat "$FX/r.out")"
[ "$(/usr/bin/wc -l < "$LEDGER" | tr -d ' ')" = "$n0" ] && ok "B2 no ledger line" || bad "B2 ledger: $(tail -1 "$LEDGER")"
chmod 600 "$W/r-locked/locked.txt" 2>/dev/null
# B3, B4: the worktrees pass
case "$(wrow "$P" s-linked-live)" in keep/*session-alive-in-registry) ok "B3 linked worktree with a live row → kept";; *) bad "B3 plan: $(wrow "$P" s-linked-live)";; esac
case "$(wrow "$P" s2-linked-frozen)" in remove/retention-rescue-*) ok "B3 linked worktree with a frozen row → rescue";; *) bad "B3 frozen: $(wrow "$P" s2-linked-frozen)";; esac
case "$(wrow "$P" t-linked-bare)" in keep/*contains-bare-or-separate-git-dir) ok "B4 bare repo inside a linked worktree → kept";; *) bad "B4 plan: $(wrow "$P" t-linked-bare)";; esac
printf 'worktrees\t%s\nworktrees\t%s\nworktrees\t%s\n' "$W/s-linked-live" "$W/t-linked-bare" "$W/s2-linked-frozen" > "$FX/wt.tsv"
env $RET bash "$HYG" apply "$FX/wt.tsv" > "$FX/wt.out" 2>&1
[ -f "$W/s-linked-live/tracked" ] && [ -d "$W/t-linked-bare/stash.git" ] && ok "B3/B4 apply keeps both" || bad "B3/B4 apply: $(cat "$FX/wt.out")"
[ ! -e "$W/s2-linked-frozen" ] && ! git -C "$FX/wtmain" worktree list | /usr/bin/grep -q s2-linked-frozen && ok "B3 frozen worktree rescued, removed and pruned" || bad "B3 frozen apply: $(cat "$FX/wt.out")"
# B5
one session-dirs u-stashfail; env $RET HYG_GIT="$FX/git-fake.sh" FAKE_NO_UPDATEREF=1 bash "$HYG" apply "$FX/one.tsv" > "$FX/u.out" 2>&1
[ -d "$W/u-stashfail/.git" ] && /usr/bin/grep -q $'refused\t.*rescue-stash-refs-failed' "$FX/u.out" && ok "B5 failed stash update-ref → kept" || bad "B5: $(cat "$FX/u.out")"
# S1
one session-dirs v-envcommit; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/v.out" 2>&1
[ -f "$W/v-envcommit/.env" ] && /usr/bin/grep -q $'refused\t.*rescue-denied-name-in-commits' "$FX/v.out" && ok "S1 .env in an unpushed commit → kept" || bad "S1 commit: $(cat "$FX/v.out")"
one session-dirs v-keypatch; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/v2.out" 2>&1
[ -f "$W/v-keypatch/cfg.key" ] && /usr/bin/grep -q $'refused\t.*rescue-denied-name-in-patch' "$FX/v2.out" && ok "S1 edited tracked *.key → kept" || bad "S1 patch: $(cat "$FX/v2.out")"
one session-dirs v-rootenv; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/v3.out" 2>&1
[ -f "$W/v-rootenv/.env" ] && /usr/bin/grep -q $'refused\t.*rescue-denied-name-in-commits' "$FX/v3.out" && ok "S1 .env in a root commit under log.showRoot=false → kept" || bad "S1 root: $(cat "$FX/v3.out")"
one session-dirs x-symparent; env $RET bash "$HYG" apply "$FX/one.tsv" > "$FX/x.out" 2>&1
pfx=$(restore x-symparent 2>/dev/null)
[ ! -e "$W/x-symparent" ] && [ -f "$FX/outside-sub/x" ] && ! /usr/bin/grep -rqs OUTSIDE "$FX/r/x-symparent" && /usr/bin/jq -e '.entries[]|select(.kind=="outside-folder-not-archived" and .path=="sub/x")' "$pfx/manifest.json" >/dev/null \
  && ok "file behind a symlinked parent is listed, not copied" || bad "symparent: $(cat "$FX/x.out"; cat "$pfx/manifest.json" 2>/dev/null; find "$FX/r/x-symparent" -type f 2>/dev/null)"
# rescue refs do not outlive a refused rescue
one session-dirs w-stashup; HYG_RETENTION_DAYS=7 HYG_RESCUE_CMD="$FX/up-fail.sh" bash "$HYG" apply "$FX/one.tsv" > "$FX/w.out" 2>&1
[ -d "$W/w-stashup/.git" ] && [ -z "$(git -C "$W/w-stashup" for-each-ref refs/hygiene-rescue/)" ] && ok "refused rescue leaves no refs/hygiene-rescue" || bad "refs left: $(git -C "$W/w-stashup" for-each-ref refs/hygiene-rescue/) $(cat "$FX/w.out")"

echo "# pass=$PASS fail=$FAILN"; [ "$FAILN" = 0 ]
