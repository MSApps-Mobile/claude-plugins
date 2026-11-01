#!/bin/bash
# hygiene-wt-artifacts.test.sh — card JsY0DY3A: every ~/code/wt/<session> folder is evaluated, and the
# build-artifacts pass, against the REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-POSITIVE  every top-level folder appears in the plan (session-dirs or worktrees), clones included
#   KNOWN-POSITIVE  a stale top-level full clone, clean and pushed → session-dirs remove
#   KNOWN-NEGATIVE  a stale top-level clone with dirty work / an unpushed branch → kept whole
#   KNOWN-NEGATIVE  a top-level clone owning a linked worktree outside its folder → kept, survives apply
#   KNOWN-NEGATIVE  a session the routines registry calls running → kept (session-dirs and artifacts)
#   KNOWN-NEGATIVE  an unreadable registry → every session kept: bad JSON, empty, {}, name-keyed, no string .session (B7)
#   KNOWN-POSITIVE  gitignored node_modules/.next/dist/coverage in an idle DIRTY clone → removed, dirty work survives
#   KNOWN-POSITIVE  gitignored build/ in an idle clone with an unpushed branch → removed, the branch survives
#   KNOWN-NEGATIVE  a tracked build/ dir, a dist/ that is not ignored → kept
#   KNOWN-POSITIVE  node_modules beside package.json in a plain session folder → removed
#   KNOWN-NEGATIVE  dist/ in a plain (non-git) folder → kept (not provably regenerable)
#   KNOWN-NEGATIVE  artifacts in a recently touched session, or one a process has its cwd in → kept
#   KNOWN-NEGATIVE  a node_modules holding a .git → kept
#   KNOWN-NEGATIVE  B6 an ignored build/ or dist/ holding a bare repo, a separate git-dir, or a repo whose
#                   HEAD is a symlink → kept, the only copy of the commit survives apply
#   KNOWN-NEGATIVE  B5 an ignored-looking build/ in a clone whose core.worktree points elsewhere → kept
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-art.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"   # lsof reports real paths (/private/var/...)
SLEEPER=""
trap '[ -n "$SLEEPER" ] && kill "$SLEEPER" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
W="$HOME/code/wt"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none" HYG_WT_ROOTS="$W:*"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$W" HYG_GRADLE_HOME="$HOME/gradle-none" HYG_DEVICE_SUPPORT="$HOME/ds-none"
export HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/android-none" HYG_PKG_CACHES=""
export HYG_SESSIONS_JSON="$FX/sessions.json"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
act(){ /usr/bin/awk -F'\t' -v p="$2" '$5==p{print $2}' "$1"; }

git init -q --bare "$FX/origin.git"
# top-level full clone, committed + pushed, with a .gitignore covering the artifact names
mkclone(){ local c="$W/$1"; git clone -q "$FX/origin.git" "$c" 2>/dev/null
  (cd "$c" && printf 'node_modules/\n.next/\ndist/\ncoverage/\nbuild/\n' > .gitignore && echo '{}' > package.json \
    && git add -A && git commit -qm "$1" && git push -q origin HEAD:refs/heads/"$1" 2>/dev/null); }
mkart(){ local d; for d in "$@"; do mkdir -p "$d/pkg"; echo blob > "$d/pkg/index.js"; done; }

mkclone clone-clean; old "$W/clone-clean"
mkclone clone-dirty; mkart "$W/clone-dirty/node_modules" "$W/clone-dirty/.next" "$W/clone-dirty/apps/web/dist" "$W/clone-dirty/coverage"
echo wip > "$W/clone-dirty/wip.txt"; old "$W/clone-dirty"
mkclone clone-unpushed; (cd "$W/clone-unpushed" && git checkout -qb local-only && echo b > b && git add b && git commit -qm local && git checkout -q -)
mkart "$W/clone-unpushed/build"; UNPUSHED_SHA=$(git -C "$W/clone-unpushed" rev-parse local-only); old "$W/clone-unpushed"
mkclone clone-tracked; (cd "$W/clone-tracked" && mkdir -p tools/build && echo s > tools/build/script.sh && git add -f tools/build/script.sh \
  && git commit -qm tracked-build && git push -q origin HEAD:refs/heads/clone-tracked 2>/dev/null)
mkart "$W/clone-tracked/lib/.turbo"   # .turbo is not in this repo's .gitignore
old "$W/clone-tracked"
mkclone clone-alive; mkart "$W/clone-alive/node_modules"; old "$W/clone-alive"
mkclone clone-fresh; mkart "$W/clone-fresh/node_modules"   # touched now
mkclone clone-cwd; mkart "$W/clone-cwd/node_modules"; old "$W/clone-cwd"
mkclone clone-nested-git; mkart "$W/clone-nested-git/node_modules"; git init -q "$W/clone-nested-git/node_modules/pkg"; old "$W/clone-nested-git"
# B6: git repos a `.git` search cannot see, inside an ignored artifact dir
mkclone clone-bare-build; git init -q --bare "$W/clone-bare-build/build/backup.git"
(cd "$W/clone-bare-build" && git checkout -q --detach && echo only > only.txt && git add only.txt && git commit -qm only-in-backup \
  && git push -q "$W/clone-bare-build/build/backup.git" HEAD:refs/heads/only 2>/dev/null); BARE_SHA=$(git -C "$W/clone-bare-build" rev-parse HEAD)
git -C "$W/clone-bare-build" checkout -q -; git -C "$W/clone-bare-build" update-ref -d refs/heads/only 2>/dev/null; old "$W/clone-bare-build"
mkclone clone-sep-dist; mkdir -p "$W/clone-sep-dist/dist" "$FX/sep-work"; git init -q --separate-git-dir="$W/clone-sep-dist/dist/sep-data" "$FX/sep-work"; old "$W/clone-sep-dist"
mkclone clone-symhead; git init -q --bare "$W/clone-symhead/build/sym.git"; rm "$W/clone-symhead/build/sym.git/HEAD"
ln -s refs/heads/main "$W/clone-symhead/build/sym.git/HEAD"; old "$W/clone-symhead"
# B5: to git this folder's build/ is outside the work tree, and the elsewhere tree's .gitignore covers the name
mkclone clone-elsewhere; mkdir -p "$FX/art-elsewhere"; cp "$W/clone-elsewhere/.gitignore" "$W/clone-elsewhere/package.json" "$FX/art-elsewhere/"
git -C "$W/clone-elsewhere" config core.worktree "$FX/art-elsewhere"; mkart "$W/clone-elsewhere/build"; echo precious > "$W/clone-elsewhere/build/notes.txt"; old "$W/clone-elsewhere"
# plain session folders
mkdir -p "$W/plain-node/app"; echo '{}' > "$W/plain-node/app/package.json"; mkart "$W/plain-node/app/node_modules" "$W/plain-node/app/dist"; old "$W/plain-node"
# a linked worktree at top level: the worktrees pass owns it, not session-dirs. Its parent clone is a
# separate session folder, which session-dirs must KEEP: the rm would take the worktree's git data.
mkclone clone-wtowner; git -C "$W/clone-wtowner" worktree add -q -b wt-branch "$W/top-linked" 2>/dev/null
old "$W/clone-wtowner" "$W/top-linked"
cat > "$HYG_SESSIONS_JSON" <<JSON
[ {"session":"clone-alive","status":"running"}, {"session":"clone-clean","status":"done"}, {"session":"plain-node","status":"dead"} ]
JSON
(cd "$W/clone-cwd" && exec sleep 300) & SLEEPER=$!; disown "$SLEEPER" 2>/dev/null
sleep 1

bash "$HYG" plan > "$FX/plan.tsv" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
P="$FX/plan.tsv"

# --- enumeration: every top-level folder is in the plan exactly once as session-dirs or worktrees
missing=0; for d in "$W"/*/; do d="${d%/}"
  n=$(/usr/bin/awk -F'\t' -v p="$d" '$5==p && ($1=="session-dirs"||$1=="worktrees")' "$P" | /usr/bin/wc -l | tr -d ' ')
  [ "$n" = 1 ] || { missing=$((missing+1)); echo "  # $d listed $n times"; }; done
[ "$missing" = 0 ] && ok "every top-level folder evaluated exactly once" || bad "$missing folders not evaluated exactly once"
[ "$(/usr/bin/awk -F'\t' -v p="$W/top-linked" '$1=="worktrees" && $5==p' "$P" | wc -l | tr -d ' ')" = 1 ] && ! /usr/bin/awk -F'\t' -v p="$W/top-linked" '$1=="session-dirs" && $5==p{f=1} END{exit !f}' "$P" \
  && ok "top-level linked worktree → worktrees pass only" || bad "top-linked: $(grep top-linked "$P")"
grep -q "clone-has-linked-worktrees	$W/clone-wtowner$" "$P" && ok "clone owning a linked worktree outside its folder → keep" \
  || bad "clone-wtowner: $(grep 'clone-wtowner$' "$P")"

# --- session-dirs on clones
[ "$(act "$P" "$W/clone-clean")" = remove ] && ok "stale clean pushed top-level clone → remove" || bad "clone-clean: $(grep -F "$W/clone-clean	" "$P"; grep "clone-clean$" "$P")"
[ "$(act "$P" "$W/clone-dirty")" = keep ] && ok "top-level clone with dirty work → keep" || bad "clone-dirty: $(grep 'clone-dirty$' "$P")"
[ "$(act "$P" "$W/clone-unpushed")" = keep ] && ok "top-level clone with an unpushed branch → keep" || bad "clone-unpushed: $(grep 'clone-unpushed$' "$P")"
grep -q "session-alive-in-registry	$W/clone-alive$" "$P" && ok "session running in the registry → keep" || bad "clone-alive: $(grep 'clone-alive$' "$P")"

# --- build-artifacts
art(){ /usr/bin/awk -F'\t' -v p="$1" '$1=="build-artifacts" && $5==p{print $2"/"$4}' "$P"; }
for a in node_modules .next apps/web/dist coverage; do
  case "$(art "$W/clone-dirty/$a")" in remove/*) ok "dirty clone: gitignored $a → remove";; *) bad "clone-dirty/$a: $(art "$W/clone-dirty/$a")";; esac; done
case "$(art "$W/clone-unpushed/build")" in remove/*) ok "unpushed clone: gitignored build/ → remove";; *) bad "clone-unpushed/build: $(art "$W/clone-unpushed/build")";; esac
case "$(art "$W/clone-tracked/tools/build")" in keep/has-tracked-files) ok "tracked build/ → keep";; *) bad "tracked build: $(art "$W/clone-tracked/tools/build")";; esac
case "$(art "$W/clone-tracked/lib/.turbo")" in keep/not-gitignored) ok "un-ignored .turbo → keep";; *) bad "lib/.turbo: $(art "$W/clone-tracked/lib/.turbo")";; esac
case "$(art "$W/clone-alive/node_modules")" in keep/session-alive-in-registry) ok "artifact in a running session → keep";; *) bad "alive nm: $(art "$W/clone-alive/node_modules")";; esac
case "$(art "$W/clone-fresh/node_modules")" in keep/session-touched-recently) ok "artifact in a recently touched session → keep";; *) bad "fresh nm: $(art "$W/clone-fresh/node_modules")";; esac
case "$(art "$W/clone-cwd/node_modules")" in keep/a-process-is-inside) ok "artifact in a session a process sits in → keep";; *) bad "cwd nm: $(art "$W/clone-cwd/node_modules")";; esac
case "$(art "$W/clone-nested-git/node_modules")" in keep/contains-a-repo) ok "node_modules holding a .git → keep";; *) bad "nested-git nm: $(art "$W/clone-nested-git/node_modules")";; esac
case "$(art "$W/clone-bare-build/build")" in keep/contains-bare-or-separate-git-dir) ok "B6 ignored build/ holding a bare repo → keep";; *) bad "B6 bare: $(art "$W/clone-bare-build/build")";; esac
case "$(art "$W/clone-sep-dist/dist")" in keep/contains-bare-or-separate-git-dir) ok "B6 ignored dist/ holding a separate git-dir → keep";; *) bad "B6 sep: $(art "$W/clone-sep-dist/dist")";; esac
case "$(art "$W/clone-symhead/build")" in keep/contains-bare-or-separate-git-dir) ok "B6 ignored build/ holding a repo with a symlink HEAD → keep";; *) bad "B6 symhead: $(art "$W/clone-symhead/build")";; esac
case "$(art "$W/clone-elsewhere/build")" in keep/worktree-not-this-folder) ok "B5 build/ in a clone whose core.worktree is elsewhere → keep";; *) bad "B5 elsewhere: $(art "$W/clone-elsewhere/build")";; esac
case "$(art "$W/plain-node/app/node_modules")" in remove/node-artifact-beside-package-json) ok "plain folder: node_modules beside package.json → remove";; *) bad "plain nm: $(art "$W/plain-node/app/node_modules")";; esac
case "$(art "$W/plain-node/app/dist")" in keep/not-provably-regenerable) ok "plain folder: dist/ → keep";; *) bad "plain dist: $(art "$W/plain-node/app/dist")";; esac

# --- unreadable registry ⇒ everything alive ⇒ nothing removable
echo '{not json' > "$FX/bad.json"
HYG_SESSIONS_JSON="$FX/bad.json" bash "$HYG" plan > "$FX/plan-bad.tsv" 2>/dev/null
/usr/bin/awk -F'\t' '($1=="session-dirs"||$1=="build-artifacts") && $2=="remove"{f=1} END{exit f}' "$FX/plan-bad.tsv" \
  && ok "unreadable registry → no session or artifact removed" || bad "bad registry still removes: $(awk -F'\t' '$2=="remove"' "$FX/plan-bad.tsv")"

# --- B7: every registry shape that is not one array of objects with a string .session keeps everything
i=0
for shape in '' '{}' '{"reg1":{"status":"running"}}' '[{"id":"reg1","status":"running"}]' '{"sessions":[{"session":"reg1","status":"running"}]}' '[{"session":1,"status":"done"}]' '[] []' '["reg1"]'; do
  i=$((i+1)); printf '%s' "$shape" > "$FX/shape$i.json"
  HYG_SESSIONS_JSON="$FX/shape$i.json" bash "$HYG" plan > "$FX/plan-shape$i.tsv" 2>/dev/null
  /usr/bin/awk -F'\t' '($1=="session-dirs"||$1=="build-artifacts") && $2=="remove"{f=1} END{exit f}' "$FX/plan-shape$i.tsv" \
    && ok "B7 registry shape [$shape] → no session or artifact removed" || bad "B7 registry shape [$shape] still removes"
done
echo '[]' > "$FX/empty.json"
HYG_SESSIONS_JSON="$FX/empty.json" bash "$HYG" plan > "$FX/plan-empty.tsv" 2>/dev/null
/usr/bin/awk -F'\t' '$1=="session-dirs" && $2=="remove"{f=1} END{exit !f}' "$FX/plan-empty.tsv" \
  && ok "B7 an empty array stays a valid registry (a removal is still planned)" || bad "B7 [] should stay valid"

# --- apply: artifacts first, then sessions; dirty work and unpushed branches survive
kill "$SLEEPER" 2>/dev/null; SLEEPER=""
/usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$P" > "$FX/apply.tsv"
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
[ ! -e "$W/clone-dirty/node_modules" ] && [ ! -e "$W/clone-dirty/apps/web/dist" ] && [ -f "$W/clone-dirty/wip.txt" ] && [ -f "$W/clone-dirty/package.json" ] \
  && ok "apply stripped the dirty clone's artifacts; its dirty work and sources survive" || bad "clone-dirty after apply: $(ls -A "$W/clone-dirty")"
[ ! -e "$W/clone-unpushed/build" ] && [ "$(git -C "$W/clone-unpushed" rev-parse local-only 2>/dev/null)" = "$UNPUSHED_SHA" ] \
  && ok "apply stripped build/; the unpushed branch survives" || bad "clone-unpushed after apply"
[ -f "$W/clone-tracked/tools/build/script.sh" ] && [ -d "$W/clone-alive/node_modules" ] && [ -d "$W/clone-fresh/node_modules" ] \
  && ok "kept artifacts are intact after apply" || bad "a kept artifact was removed"
git -C "$W/clone-bare-build/build/backup.git" cat-file -e "$BARE_SHA^{commit}" 2>/dev/null && [ -e "$W/clone-sep-dist/dist/sep-data/HEAD" ] && [ -L "$W/clone-symhead/build/sym.git/HEAD" ] \
  && ok "B6 apply left the repos inside artifact dirs alone; the commit held only by the bare repo survives" || bad "B6 a repo inside an artifact dir is gone"
[ -f "$W/clone-elsewhere/build/notes.txt" ] && ok "B5 apply left the folder's own build/ alone" || bad "B5 clone-elsewhere/build gone"
[ "$(act "$P" "$W/plain-node")" = remove ] && [ ! -e "$W/plain-node" ] && ok "dead idle plain folder (registry: dead) → session-dirs removed it whole" || bad "plain-node: $(grep 'plain-node$' "$P")"
[ -d "$W/clone-wtowner/.git" ] && [ "$(git -C "$W/clone-wtowner" rev-parse wt-branch 2>/dev/null)" != "" ] \
  && ok "the linked worktree's owner clone survives apply" || bad "clone-wtowner gone after apply"
[ ! -e "$W/clone-clean" ] && ok "apply removed the clean stale top-level clone" || bad "clone-clean still there: $(cat "$FX/apply.out")"
[ -z "$(/usr/bin/awk -F'\t' '$2=="refused"' "$FX/apply.out")" ] && ok "apply refused nothing it planned" || bad "refused: $(awk -F'\t' '$2=="refused"' "$FX/apply.out")"

echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
