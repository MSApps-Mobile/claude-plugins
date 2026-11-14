#!/bin/bash
# hygiene-wt-safety.test.sh — card w1t7IqUt (rescope of JsY0DY3A), PR #80 findings B12-B16 and the two
# security leads. Real scripts/hygiene.sh, throwaway HOME, nothing touches the real home.
#
#   B12  KNOWN-NEGATIVE  a repo git cannot read (unknown extensions.*, a linked worktree whose parent is
#                        gone, a broken .git in a subfolder) is NOT "no repo": node_modules / .next /
#                        .turbo with a dirty force-tracked file are kept and the edit survives apply
#   B12  KNOWN-POSITIVE  node_modules beside package.json with no .git at any level is still removed
#   B13  KNOWN-NEGATIVE  the worktrees pass honours the registry: a running row, a 0-byte registry, a
#                        running row on the session folder that holds the worktree → keep, folder survives
#   B13  KNOWN-POSITIVE  the same worktree with a "done" row → remove (the fixture is otherwise removable)
#   B16  one helper decides "nothing touched in the window" (static check + the two prune sets behave)
#   L0   lsof sees the fixture process (FAIL, never SKIP); an lsof we cannot fully read keeps on all three
#        passes (session-dirs, build-artifacts, worktrees), in plan and apply: missing, exit 1 with no
#        output, exit 1 after one unrelated row, the real list cut at 60 lines with exit 143 (review B1)
#   B3   KNOWN-NEGATIVE  a nested repo git cannot read (lost HEAD, empty .git) under a healthy outer repo
#                        that ignores node_modules: its dirty force-tracked node_modules file is kept and
#                        survives apply (discovery answers from the outer repo)
#   L1   KNOWN-NEGATIVE  repo config that makes git run a program during plan/apply never runs it:
#                        remote.origin.uploadpack + partial clone, and log.showSignature + gpg.program
#   L1   KNOWN-POSITIVE  a plain config (gh-style clone) is still removable
#   L2   KNOWN-NEGATIVE  a symlink standing where apply will remove (worktree path, a component of it, a
#                        session folder, an artifact path): a file outside survives apply
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-safety.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"   # lsof reports real paths (/private/var/...)
SLEEPER=""
trap '[ -n "$SLEEPER" ] && kill "$SLEEPER" 2>/dev/null; chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
W="$HOME/code/wt"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/code"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$W" HYG_GRADLE_HOME="$HOME/gradle-none" HYG_DEVICE_SUPPORT="$HOME/ds-none"
export HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/android-none" HYG_PKG_CACHES=""
export HYG_SESSIONS_JSON="$FX/sessions.json"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
echo '[]' > "$HYG_SESSIONS_JSON"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
row(){ /usr/bin/awk -F'\t' -v c="$2" -v p="$3" '$1==c && $5==p{print $2"/"$4}' "$1"; }   # plan cat path → action/reason
expect(){ local got; got="$(row "$P" "$1" "$2")"; if [ "$got" = "$3" ]; then ok "$4"; else bad "$4 (want $3, got [$got])"; fi; }

git init -q --bare "$FX/origin.git"
# a stale, clean, pushed top-level clone with a .gitignore and a package.json
mkclone(){ local c="$W/$1"; git clone -q "$FX/origin.git" "$c" 2>/dev/null
  (cd "$c" && printf 'node_modules/\n.next/\n.turbo/\ndist/\n' > .gitignore && echo '{}' > package.json \
    && git add -A && git commit -qm "$1" && git push -q origin HEAD:refs/heads/"$1" 2>/dev/null); }
# force-track a file in each artifact dir, commit, push; then edit it (uncommitted work inside the artifact dirs)
tracked_dirty(){ local c="$W/$1" a; shift
  (cd "$c" && for a in "$@"; do mkdir -p "$a/p"; echo orig > "$a/p/i.js"; git add -f "$a/p/i.js"; done
   git commit -qm tracked-artifacts && git push -q origin HEAD:refs/heads/"$(basename "$c")" 2>/dev/null
   for a in "$@"; do echo EDITED-UNCOMMITTED > "$a/p/i.js"; done); }
edited(){ local c="$W/$1" a; shift; for a in "$@"; do [ "$(cat "$c/$a/p/i.js" 2>/dev/null)" = EDITED-UNCOMMITTED ] || return 1; done; }

# ---------------- B12 fixtures ----------------
# (a) unknown extension: git refuses the repo ("unknown repository extension"), the files are tracked and dirty
mkclone b12-ext; tracked_dirty b12-ext node_modules .next .turbo
git -C "$W/b12-ext" config core.repositoryformatversion 1; git -C "$W/b12-ext" config extensions.futureextension true
git -C "$W/b12-ext" rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "# fixture b12-ext: git still reads the repo" >&2
old "$W/b12-ext"
# (b) a linked worktree whose parent repo is gone (its .git file points at a missing gitdir), tracked node_modules
git clone -q "$FX/origin.git" "$FX/b12-parent" 2>/dev/null
(cd "$FX/b12-parent" && printf 'node_modules/\n' > .gitignore && echo '{}' > package.json && git add -A && git commit -qm p && git push -q origin HEAD:refs/heads/b12-parent 2>/dev/null)
git -C "$FX/b12-parent" worktree add -q -b b12-wt "$W/b12-orphan" 2>/dev/null
(cd "$W/b12-orphan" && for a in node_modules .next .turbo; do mkdir -p $a/p && echo orig > $a/p/i.js && git add -f $a/p/i.js; done && git commit -qm t \
  && for a in node_modules .next .turbo; do echo EDITED-UNCOMMITTED > $a/p/i.js; done)
rm -rf "$FX/b12-parent"; old "$W/b12-orphan"
# (c) a broken .git in a subfolder: the artifact's parent is a subfolder, the session folder has no .git
mkdir -p "$W/b12-sub/app/node_modules/p" "$W/b12-sub/app/.next/p" "$W/b12-sub/app/.turbo/p"; echo '{}' > "$W/b12-sub/app/package.json"
echo orig > "$W/b12-sub/app/node_modules/p/i.js"; echo orig > "$W/b12-sub/app/.next/p/i.js"; echo orig > "$W/b12-sub/app/.turbo/p/i.js"
echo "gitdir: $FX/does-not-exist/.git/worktrees/x" > "$W/b12-sub/app/.git"; old "$W/b12-sub"
# (d) control: no .git anywhere → still removed
mkdir -p "$W/b12-plain/app/node_modules/p" "$W/b12-plain/app/.turbo/p"; echo '{}' > "$W/b12-plain/app/package.json"
echo x > "$W/b12-plain/app/node_modules/p/i.js"; echo x > "$W/b12-plain/app/.turbo/p/i.js"; old "$W/b12-plain"
# ---------------- B3 fixtures ----------------
# a pushed clean clone (outer .gitignore has node_modules/) holding sub/, a repo with one commit and a
# force-tracked sub/node_modules/p/i.js edited and uncommitted; then sub's repo is damaged
mkb3(){ mkclone "$1"; ( cd "$W/$1" && git init -q sub && cd sub && echo s > s && mkdir -p node_modules/p && echo orig > node_modules/p/i.js \
    && git add s && git add -f node_modules/p/i.js && git commit -qm sub && echo EDITED-UNCOMMITTED > node_modules/p/i.js ); }
mkb3 b3-lost-head; rm -f "$W/b3-lost-head/sub/.git/HEAD"
mkb3 b3-empty-git; rm -rf "$W/b3-empty-git/sub/.git"; mkdir "$W/b3-empty-git/sub/.git"
for c in b3-lost-head b3-empty-git; do git -C "$W/$c/sub" rev-parse --show-toplevel 2>/dev/null | /usr/bin/grep -qx "$(cd -P "$W/$c" && pwd -P)" \
  || echo "# fixture $c: git does not answer from the outer repo" >&2; old "$W/$c"; done

# ---------------- B13 fixtures ----------------
# a clean, pushed, idle linked worktree at top level, parent repo outside the session root
git clone -q "$FX/origin.git" "$FX/b13-parent" 2>/dev/null
(cd "$FX/b13-parent" && echo a > a && git add a && git commit -qm a && git push -q origin HEAD:refs/heads/b13-parent 2>/dev/null)
mkwt(){ git -C "$FX/b13-parent" worktree add -q -b "$(basename "$1")" "$1" 2>/dev/null && git -C "$1" push -q origin "HEAD:refs/heads/$(basename "$1")" 2>/dev/null; }
mkwt "$W/b13-run"; mkwt "$W/b13-zero"; mkwt "$W/b13-done"
mkdir -p "$W/b13-live"; mkwt "$W/b13-live/inner"            # the folder holds the worktree; the registry names the FOLDER
old "$W/b13-run" "$W/b13-zero" "$W/b13-done" "$W/b13-live"
cat > "$FX/reg-run.json" <<'JSON'
[ {"session":"b13-run","status":"running"}, {"session":"b13-live","status":"running"}, {"session":"b13-done","status":"done"} ]
JSON
: > "$FX/reg-zero.json"

# ---------------- L1 fixtures (command execution during plan) ----------------
CANARY_A="$FX/canary-uploadpack"; CANARY_B="$FX/canary-gpg"
printf '#!/bin/sh\necho ran >> "%s"\nexit 1\n' "$CANARY_A" > "$FX/canaryA.sh"; printf '#!/bin/sh\necho ran >> "%s"\nexit 1\n' "$CANARY_B" > "$FX/canaryB.sh"; chmod +x "$FX"/canary*.sh
mkrepo(){ git clone -q "$FX/origin.git" "$1" 2>/dev/null
  (cd "$1" && echo a > a && git add a && git commit -qm c1 && git push -q origin HEAD:refs/heads/"$2" 2>/dev/null && echo b > b && git add b && git commit -qm c2 && git push -q origin HEAD:refs/heads/"$2" 2>/dev/null); }
# route A: promisor remote with a canary uploadpack, HEAD's tree object missing locally ⇒ git would lazy-fetch
mkrepo "$W/l1-promisor" l1-promisor
git -C "$W/l1-promisor" config core.repositoryformatversion 1; git -C "$W/l1-promisor" config extensions.partialclone origin
git -C "$W/l1-promisor" config remote.origin.promisor true; git -C "$W/l1-promisor" config remote.origin.partialclonefilter blob:none
git -C "$W/l1-promisor" config remote.origin.uploadpack "$FX/canaryA.sh"
T=$(git -C "$W/l1-promisor" rev-parse 'HEAD^{tree}'); rm -f "$W/l1-promisor/.git/objects/${T:0:2}/${T:2}"; old "$W/l1-promisor"
# route B: linked worktree whose HEAD is a local-only commit with a gpgsig header; log.showSignature + gpg.program
mkrepo "$FX/l1-parent" l1-parent; git -C "$FX/l1-parent" worktree add -q -b l1-sig "$W/l1-sig" 2>/dev/null
( cd "$W/l1-sig" && tree=$(git write-tree) && par=$(git rev-parse HEAD) && sha=$(printf 'tree %s\nparent %s\nauthor t <t@example.invalid> 1700000000 +0000\ncommitter t <t@example.invalid> 1700000000 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n fake\n -----END PGP SIGNATURE-----\n\nsigned\n' "$tree" "$par" | git hash-object -t commit -w --stdin) && git update-ref HEAD "$sha" )
git -C "$FX/l1-parent" config remote.origin.url https://github.com/fake/fake.git
git -C "$FX/l1-parent" config log.showSignature true; git -C "$FX/l1-parent" config gpg.program "$FX/canaryB.sh"
old "$W/l1-sig"
printf '#!/bin/sh\ncase "$*" in *"pr list"*) echo "l1-sig 0000000000000000000000000000000000000000 7";; *"pr view"*) echo c1;; *) exit 1;; esac\n' > "$FX/gh-stub"; chmod +x "$FX/gh-stub"
# control: the config a gh/git clone really has (+ user and branch tracking) is NOT blocked
mkrepo "$W/l1-plain" l1-plain; git -C "$W/l1-plain" config user.name t; git -C "$W/l1-plain" config branch.l1-plain.remote origin
git -C "$W/l1-plain" config branch.l1-plain.merge refs/heads/l1-plain; git -C "$W/l1-plain" config remote.origin.gh-resolved base; old "$W/l1-plain"

# ---------------- L2 fixtures (a symlink where apply removes) ----------------
OUT="$FX/outside"; mkdir -p "$OUT"
git clone -q "$FX/origin.git" "$FX/l2-parent" 2>/dev/null
(cd "$FX/l2-parent" && echo a > a && git add a && git commit -qm a && git push -q origin HEAD:refs/heads/l2-parent 2>/dev/null)
git -C "$FX/l2-parent" worktree add -q -b l2-real "$OUT/real-wt" 2>/dev/null && git -C "$OUT/real-wt" push -q origin HEAD:refs/heads/l2-real 2>/dev/null
old "$OUT/real-wt"
mkdir -p "$OUT/art/node_modules" "$OUT/sessdir"; echo precious > "$OUT/art/node_modules/keep.txt"; echo precious > "$OUT/sessdir/keep.txt"
ln -s "$OUT/real-wt" "$W/l2-link"                     # the worktree path itself is a symlink
ln -s "$OUT" "$W/l2-hop"                              # a COMPONENT of the path is a symlink: l2-hop/real-wt is $OUT/real-wt
ln -s "$OUT/sessdir" "$W/l2-sess"                     # a session folder that is a symlink
mkdir -p "$W/l2-art"; echo '{}' > "$W/l2-art/package.json"; ln -s "$OUT/art" "$W/l2-art/app"; old "$W/l2-art"   # app/ → outside, app/node_modules is outside
old "$W/l2-link" "$W/l2-hop" "$W/l2-sess"

# B16: a fresh file in dist/ only; everything else old
mkclone b16; mkdir -p "$W/b16/dist" "$W/b16/node_modules/p"; echo x > "$W/b16/node_modules/p/i.js"; echo x > "$W/b16/dist/new.js"; old "$W/b16"; touch "$W/b16/dist/new.js"
# B16/fail-closed: a subfolder find cannot read ⇒ idleness is unmeasured ⇒ keep the folder
mkclone b16-eacces; mkdir -p "$W/b16-eacces/locked"; echo x > "$W/b16-eacces/locked/f"; old "$W/b16-eacces"; chmod 000 "$W/b16-eacces/locked"
# a stale clean clone and a process sitting in a folder (lsof visibility)
mkclone l0-clean; old "$W/l0-clean"
mkdir -p "$W/l0-cwd"; echo x > "$W/l0-cwd/f"; old "$W/l0-cwd"
(cd "$W/l0-cwd" && exec sleep 300) & SLEEPER=$!; disown "$SLEEPER" 2>/dev/null
sleep 1

plan(){ bash "$HYG" plan > "$1" 2>"$1.err" || bad "plan exited non-zero: $(cat "$1.err")"; }
LSOF=""; for c in /usr/sbin/lsof /usr/bin/lsof; do [ -x "$c" ] && { LSOF="$c"; break; }; done

# =============== L0: lsof can see the fixture process; absent lsof ⇒ keep ===============
if [ -n "$LSOF" ] && "$LSOF" -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/grep -qxF "$W/l0-cwd"; then ok "L0 lsof ($LSOF) sees the fixture process in $W/l0-cwd"
else bad "L0 lsof cannot see the fixture process (lsof=[$LSOF]); the cwd checks below would prove nothing"; fi

P="$FX/plan.tsv"; plan "$P"
expect session-dirs "$W/l0-cwd" "keep/a-process-is-inside" "L0 a folder a process sits in → keep a-process-is-inside"
expect session-dirs "$W/l0-clean" "remove/stale-session-all-nested-pushed" "L0 control: with lsof the same clone is removable"
expect build-artifacts "$W/b12-plain/app/node_modules" "remove/node-artifact-beside-package-json" "L0 control: with lsof the no-.git node_modules is removable"
expect worktrees "$W/b13-done" "remove/pushed" "L0 control: with lsof the idle pushed worktree is removable"
# B1: an lsof we cannot fully read is blind on every pass. Each stub stands in for a failure part way.
printf '#!/bin/sh\nexit 1\n' > "$FX/lsof-exit1"
printf '#!/bin/sh\nprintf "p1\\nfcwd\\nn/\\n"\nexit 1\n' > "$FX/lsof-onerow"
printf '#!/bin/sh\n"%s" -d cwd -Fn 2>/dev/null | /usr/bin/head -60\nexit 143\n' "${LSOF:-/usr/sbin/lsof}" > "$FX/lsof-cut"
chmod +x "$FX/lsof-exit1" "$FX/lsof-onerow" "$FX/lsof-cut"
[ "$("$FX/lsof-onerow" | /usr/bin/sed -n 's/^n//p')" = / ] && ok "L0 stub lsof-onerow prints one unrelated cwd row" || bad "L0 stub lsof-onerow output wrong"
[ "$("$FX/lsof-cut" | /usr/bin/grep -c '^n')" -gt 0 ] && ok "L0 stub lsof-cut prints real cwd rows before exit 143" || bad "L0 stub lsof-cut printed no cwd row"
for s in no-such-lsof lsof-exit1 lsof-onerow lsof-cut; do
  HYG_LSOF="$FX/$s" plan "$FX/plan-$s.tsv"
  for t in "session-dirs $W/l0-clean" "build-artifacts $W/b12-plain/app/node_modules" "worktrees $W/b13-done"; do
    set -- $t; got="$(row "$FX/plan-$s.tsv" "$1" "$2")"
    case "$got" in keep/*) ok "L0 lsof=$s: $1 ${2#"$W/"} kept (blind ⇒ fail closed)";; *) bad "L0 lsof=$s: $1 ${2#"$W/"} [$got]";; esac
  done
done
# the same on apply, with the one-row stub and the cut list: nothing is removed
printf 'session-dirs\t%s\nbuild-artifacts\t%s\nworktrees\t%s\n' "$W/l0-clean" "$W/b12-plain/app/node_modules" "$W/b13-done" > "$FX/apply-l0.tsv"
for s in lsof-onerow lsof-cut; do
  HYG_LSOF="$FX/$s" bash "$HYG" apply "$FX/apply-l0.tsv" > "$FX/apply-l0-$s.out" 2>&1
  [ -d "$W/l0-clean" ] && [ -d "$W/b12-plain/app/node_modules" ] && [ -d "$W/b13-done" ] && [ "$(/usr/bin/grep -c '	removed	' "$FX/apply-l0-$s.out")" = 0 ] \
    && ok "L0 apply with lsof=$s removed none of the three" || bad "L0 apply with lsof=$s: $(cat "$FX/apply-l0-$s.out")"
done

# =============== B12 ===============
for a in node_modules .next .turbo; do
  expect build-artifacts "$W/b12-ext/$a" "keep/git-cannot-read-repo" "B12 unreadable repo (unknown extension): $a with a dirty tracked file → keep"
done
for a in node_modules .next .turbo; do
  expect build-artifacts "$W/b12-orphan/$a" "keep/git-cannot-read-repo" "B12 linked worktree whose parent is gone: tracked $a → keep"
  expect build-artifacts "$W/b12-sub/app/$a" "keep/git-cannot-read-repo" "B12 broken .git in a subfolder: $a → keep"
done
expect build-artifacts "$W/b12-plain/app/node_modules" "remove/node-artifact-beside-package-json" "B12 control: no .git at any level, node_modules → remove"
expect build-artifacts "$W/b12-plain/app/.turbo" "remove/node-artifact-beside-package-json" "B12 control: no .git at any level, .turbo → remove"

# =============== B3 ===============
for c in b3-lost-head b3-empty-git; do
  expect build-artifacts "$W/$c/sub/node_modules" "keep/git-cannot-read-repo" "B3 nested repo git cannot read ($c) under a healthy outer repo → keep"
done

# =============== B13 (plans) ===============
cp "$HYG_SESSIONS_JSON" "$FX/reg-empty.json"
HYG_SESSIONS_JSON="$FX/reg-run.json" plan "$FX/plan-run.tsv"
HYG_SESSIONS_JSON="$FX/reg-zero.json" plan "$FX/plan-zero.tsv"
cp "$FX/plan.tsv" "$FX/plan-b16.tsv"
expect worktrees "$W/b13-run" "remove/pushed" "B13 control: registry [] → idle pushed worktree is removable"
Q="$FX/plan-run.tsv"; got="$(row "$Q" worktrees "$W/b13-run")";  [ "$got" = keep/session-alive-in-registry ] && ok "B13 registry row running → worktree kept" || bad "B13 running row: [$got]"
got="$(row "$Q" worktrees "$W/b13-live/inner")"; [ "$got" = keep/session-alive-in-registry ] && ok "B13 registry row running on the folder holding the worktree → kept" || bad "B13 running folder: [$got]"
got="$(row "$Q" worktrees "$W/b13-done")"; [ "$got" = remove/pushed ] && ok "B13 registry row done → removable (fixture is otherwise removable)" || bad "B13 done row: [$got]"
Q="$FX/plan-zero.tsv"
n=0; for w in b13-run b13-zero b13-done b13-live/inner; do [ "$(row "$Q" worktrees "$W/$w" | cut -d/ -f1)" = keep ] && n=$((n+1)); done
[ "$n" = 4 ] && ok "B13 0-byte registry → every worktree kept" || bad "B13 0-byte registry kept only $n of 4"

# =============== B16 ===============
c=$(/usr/bin/grep -c -- '-prune -o -type f -mmin' "$HYG")
[ "$c" = 1 ] && ok "B16 one find-walk decides 'nothing touched in the window'" || bad "B16 $c walks of the form '-prune -o -type f -mmin' (want 1)"
expect session-dirs "$W/b16" "keep/touched-recently" "B16 session-dirs counts a fresh file in dist/ (the folder is deleted whole)"
case "$(row "$FX/plan-b16.tsv" build-artifacts "$W/b16/node_modules")" in remove/*) ok "B16 build-artifacts ignores artifact dirs' own files when judging idleness";; *) bad "B16 artifacts idle: $(row "$FX/plan-b16.tsv" build-artifacts "$W/b16/node_modules")";; esac

expect session-dirs "$W/b16-eacces" "keep/touched-recently" "B16 a subfolder find cannot read → idleness unmeasured → keep (fail closed)"

# =============== L1: plan runs no repo-config command ===============
rm -f "$CANARY_A" "$CANARY_B"
HYG_WT_MERGED_PR_CHECK=1 HYG_GH="$FX/gh-stub" plan "$FX/plan-l1.tsv"
[ -e "$CANARY_A" ] && bad "L1 remote.origin.uploadpack + partial clone: the canary RAN during plan" || ok "L1 uploadpack/partialClone canary did not run during plan"
[ -e "$CANARY_B" ] && bad "L1 log.showSignature + gpg.program: the canary RAN during plan" || ok "L1 showSignature/gpg.program canary did not run during plan"
case "$(row "$FX/plan-l1.tsv" session-dirs "$W/l1-promisor")" in keep/*) ok "L1 the promisor clone is kept";; *) bad "L1 promisor: $(row "$FX/plan-l1.tsv" session-dirs "$W/l1-promisor")";; esac
case "$(row "$FX/plan-l1.tsv" worktrees "$W/l1-sig")" in keep/*) ok "L1 the signed-commit worktree is kept";; *) bad "L1 sig: $(row "$FX/plan-l1.tsv" worktrees "$W/l1-sig")";; esac
expect session-dirs "$W/l1-plain" "remove/stale-session-all-nested-pushed" "L1 control: a plain gh-style config is not blocked"
# the same on apply: hand-written plan lines for the two trap repos
rm -f "$CANARY_A" "$CANARY_B"
printf 'session-dirs\t%s\nworktrees\t%s\n' "$W/l1-promisor" "$W/l1-sig" > "$FX/apply-l1.tsv"
HYG_WT_MERGED_PR_CHECK=1 HYG_GH="$FX/gh-stub" bash "$HYG" apply "$FX/apply-l1.tsv" > "$FX/apply-l1.out" 2>&1
[ ! -e "$CANARY_A" ] && [ ! -e "$CANARY_B" ] && [ -d "$W/l1-promisor" ] && [ -d "$W/l1-sig" ] && ok "L1 apply ran neither canary and removed neither repo" || bad "L1 apply: A=$([ -e "$CANARY_A" ] && echo RAN) B=$([ -e "$CANARY_B" ] && echo RAN) $(cat "$FX/apply-l1.out")"

# =============== L2: a symlink where apply removes ===============
for t in "worktrees $W/l2-link" "worktrees $W/l2-hop/real-wt" "session-dirs $W/l2-sess" "build-artifacts $W/l2-art/app/node_modules"; do
  set -- $t; printf '%s\t%s\n' "$1" "$2" >> "$FX/apply-l2.tsv"; done
bash "$HYG" apply "$FX/apply-l2.tsv" > "$FX/apply-l2.out" 2>&1
[ -f "$OUT/real-wt/a" ] && [ -f "$OUT/real-wt/.git" ] && ok "L2 the worktree behind a symlinked path survives apply" || bad "L2 outside worktree damaged: $(ls -A "$OUT/real-wt" 2>&1 | head -3)"
[ -f "$OUT/art/node_modules/keep.txt" ] && ok "L2 an artifact dir behind a symlinked folder survives apply" || bad "L2 outside node_modules removed"
[ -f "$OUT/sessdir/keep.txt" ] && ok "L2 a symlinked session folder's target survives apply" || bad "L2 outside session dir removed"
[ "$(/usr/bin/grep -c '	removed	' "$FX/apply-l2.out")" = 0 ] && ok "L2 apply reported no removal for any of the four symlink paths" || bad "L2 apply removed something: $(cat "$FX/apply-l2.out")"

# =============== apply: the dirty tracked files inside artifact dirs survive ===============
kill "$SLEEPER" 2>/dev/null; SLEEPER=""
/usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$P" | /usr/bin/grep -v "/b13-" > "$FX/apply.tsv"
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
edited b12-ext node_modules .next .turbo && ok "B12 apply left the unreadable repo's dirty tracked files alone" || bad "B12 b12-ext after apply: $(cat "$W/b12-ext/node_modules/p/i.js" 2>&1)"
edited b12-orphan node_modules .next .turbo && ok "B12 apply left the orphaned worktree's dirty files alone" || bad "B12 b12-orphan after apply"
[ -f "$W/b12-sub/app/node_modules/p/i.js" ] && [ -f "$W/b12-sub/app/.next/p/i.js" ] && [ -f "$W/b12-sub/app/.turbo/p/i.js" ] && ok "B12 apply left the broken-.git subfolder's artifacts alone" || bad "B12 b12-sub after apply"
# B3 on apply: hand-written lines (the plan keeps them, so they are not in apply.tsv)
printf 'build-artifacts\t%s\nbuild-artifacts\t%s\n' "$W/b3-lost-head/sub/node_modules" "$W/b3-empty-git/sub/node_modules" > "$FX/apply-b3.tsv"
bash "$HYG" apply "$FX/apply-b3.tsv" > "$FX/apply-b3.out" 2>&1
edited b3-lost-head/sub node_modules && edited b3-empty-git/sub node_modules && ok "B3 apply left both damaged nested repos' dirty node_modules files alone" || bad "B3 apply: $(cat "$FX/apply-b3.out")"
[ ! -e "$W/b12-plain/app/node_modules" ] && ok "B12 control: apply removed the no-.git node_modules" || bad "B12 b12-plain still there"
/usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$FX/plan-run.tsv" > "$FX/apply-run.tsv"
grep -q "b13-done" "$FX/apply-run.tsv" && ok "B13 the running-registry plan lists b13-done for removal" || bad "B13 apply-run.tsv has no b13-done line"
HYG_SESSIONS_JSON="$FX/reg-run.json" bash "$HYG" apply "$FX/apply-run.tsv" > "$FX/apply-run.out" 2>&1
[ -d "$W/b13-run" ] && [ -d "$W/b13-live/inner" ] && ok "B13 apply with a running registry left both live worktrees" || bad "B13 live worktree removed: $(grep -F b13- "$FX/apply-run.out")"
[ ! -e "$W/b13-done" ] && ok "B13 apply removed the worktree whose row is done" || bad "B13 b13-done still there"

echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
