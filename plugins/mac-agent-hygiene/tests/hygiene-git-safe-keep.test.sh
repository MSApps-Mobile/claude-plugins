#!/bin/bash
# hygiene-git-safe-keep.test.sh — card JsY0DY3A rework (PR #80 review B1/B2/B3): the session-dirs pass
# `rm -rf`s a whole ~/code/wt/<session> folder, so git_safe must KEEP a clone whenever deleting it
# could lose work. Run against the REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-NEGATIVE  B1 a clean pushed clone owning a linked worktree OUTSIDE its folder, that worktree
#                   holding an unpushed (detached) commit → kept, by plan AND by apply's re-check;
#                   the worktree and its commit survive
#   KNOWN-NEGATIVE  B1 `git worktree list` failing → kept (fail toward keep)
#   KNOWN-NEGATIVE  B2 an untracked file in a clone with status.showUntrackedFiles=no → kept as dirty
#   KNOWN-NEGATIVE  B3 a commit reachable only from a local lightweight tag → kept
#   KNOWN-NEGATIVE  B3 a commit reachable only from a local annotated tag → kept
#   KNOWN-NEGATIVE  B4 a local edit `git status` cannot see: a tracked file flagged assume-unchanged or
#                   skip-worktree, in a top-level clone, a nested clone or a linked worktree → kept
#   KNOWN-NEGATIVE  B4 `git ls-files` failing → kept (fail toward keep)
#   KNOWN-NEGATIVE  B5 a clone whose core.worktree points outside its folder → kept; its files survive apply
#   KNOWN-NEGATIVE  B5 `git rev-parse --show-toplevel` failing → kept (fail toward keep)
#   KNOWN-POSITIVE  a clone whose core.worktree is a symlink back to its own folder → still removed
#   KNOWN-POSITIVE  a clean pushed clone whose linked worktree lives INSIDE its folder → still removed
#   KNOWN-POSITIVE  a clean pushed clone with no linked worktree, tags on pushed commits → still removed
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-gs.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
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
echo '[]' > "$HYG_SESSIONS_JSON"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
row(){ /usr/bin/awk -F'\t' -v c="$2" -v p="$3" '$1==c && $5==p{print $2"/"$4}' "$1"; }

git init -q --bare "$FX/origin.git"
mkclone(){ local c="$W/$1"; git clone -q "$FX/origin.git" "$c" 2>/dev/null
  (cd "$c" && echo "$1" > README && git add README && git commit -qm "$1" && git push -q origin HEAD:refs/heads/"$1" 2>/dev/null); }
# make a commit on a detached HEAD, return to the branch: the commit is then held only by what the caller adds
detached_commit(){ local c="$1" s; (cd "$c" && git checkout -q --detach && echo x > only-here && git add only-here \
  && git commit -qm only-here) || return 1; s=$(git -C "$c" rev-parse HEAD); git -C "$c" checkout -q - ; echo "$s"; }

# B1: clean pushed clone; its linked worktree sits in ANOTHER session folder with an unpushed detached commit
mkclone wt-owner
git -C "$W/wt-owner" worktree add -q --detach "$W/wt-outside" 2>/dev/null
(cd "$W/wt-outside" && echo y > unpushed.txt && git add unpushed.txt && git commit -qm unpushed-in-linked-wt)
OUT_SHA=$(git -C "$W/wt-outside" rev-parse HEAD)
old "$W/wt-owner" "$W/wt-outside"
# positive control: linked worktree INSIDE the clone's own folder (goes with the rm; it is clean and pushed)
mkclone wt-inside-owner
git -C "$W/wt-inside-owner" worktree add -q --detach "$W/wt-inside-owner/sub-wt" 2>/dev/null
printf 'sub-wt/\n' >> "$W/wt-inside-owner/.git/info/exclude"
old "$W/wt-inside-owner"
# B2: untracked file hidden by repo config
mkclone untracked-hidden
git -C "$W/untracked-hidden" config status.showUntrackedFiles no
echo precious > "$W/untracked-hidden/notes.txt"; old "$W/untracked-hidden"
# B3: commit reachable only from a local tag (lightweight / annotated)
mkclone tag-light; TL_SHA=$(detached_commit "$W/tag-light"); git -C "$W/tag-light" tag keep-me "$TL_SHA"; old "$W/tag-light"
mkclone tag-annot; TA_SHA=$(detached_commit "$W/tag-annot"); git -C "$W/tag-annot" tag -a -m keep keep-me "$TA_SHA"; old "$W/tag-annot"
# positive control: a tag on an already-pushed commit does not block removal
mkclone tag-pushed; git -C "$W/tag-pushed" tag v1 HEAD; old "$W/tag-pushed"
# B4: the edit is invisible to `git status` once the index entry carries the flag
mkclone hide-assume; git -C "$W/hide-assume" update-index --assume-unchanged README; echo LOCAL-EDIT >> "$W/hide-assume/README"; old "$W/hide-assume"
mkclone hide-skip; git -C "$W/hide-skip" update-index --skip-worktree README; echo LOCAL-EDIT >> "$W/hide-skip/README"; old "$W/hide-skip"
# ... and the same through the two other callers of git_safe: a nested clone, a linked worktree
mkclone hide-nested/repo; git -C "$W/hide-nested/repo" update-index --skip-worktree README; echo LOCAL-EDIT >> "$W/hide-nested/repo/README"; old "$W/hide-nested"
mkclone hide-wt-owner; git -C "$W/hide-wt-owner" worktree add -q --detach "$W/hide-wt" 2>/dev/null
git -C "$W/hide-wt" update-index --assume-unchanged README; echo LOCAL-EDIT >> "$W/hide-wt/README"; old "$W/hide-wt-owner" "$W/hide-wt"
# B5: core.worktree points at a clean checkout elsewhere, so status never looks at this folder's own files
mkclone wt-elsewhere; mkdir -p "$FX/elsewhere"; cp "$W/wt-elsewhere/README" "$FX/elsewhere/README"
git -C "$W/wt-elsewhere" config core.worktree "$FX/elsewhere"; echo precious > "$W/wt-elsewhere/notes.txt"; old "$W/wt-elsewhere"
# positive control: the comparison is physical, a symlink back to the folder itself is not "elsewhere"
mkclone wt-self-link; ln -s "$W/wt-self-link" "$FX/self-link"; git -C "$W/wt-self-link" config core.worktree "$FX/self-link"; old "$W/wt-self-link"
# The fixtures must really read clean to git, or the keep below would prove nothing
for c in hide-assume hide-skip hide-nested/repo hide-wt wt-elsewhere; do
  [ -z "$(git -C "$W/$c" status --porcelain --untracked-files=all)" ] && ok "fixture $c reads clean to git status" || bad "fixture $c is not clean: $(git -C "$W/$c" status --porcelain)"
done

bash "$HYG" plan > "$FX/plan.tsv" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
P="$FX/plan.tsv"

case "$(row "$P" session-dirs "$W/wt-owner")" in keep/clone-has-linked-worktrees) ok "B1 clone with an outside linked worktree → keep (clone-has-linked-worktrees)";;
  *) bad "B1 wt-owner: $(row "$P" session-dirs "$W/wt-owner")";; esac
case "$(row "$P" worktrees "$W/wt-outside")" in keep/*) ok "B1 the outside linked worktree with an unpushed commit → keep";;
  *) bad "B1 wt-outside: $(row "$P" worktrees "$W/wt-outside")";; esac
case "$(row "$P" session-dirs "$W/wt-inside-owner")" in remove/*) ok "control: clone whose linked worktree is inside its own folder → remove";;
  *) bad "wt-inside-owner: $(row "$P" session-dirs "$W/wt-inside-owner")";; esac
case "$(row "$P" session-dirs "$W/untracked-hidden")" in keep/clone-dirty-uncommitted-work) ok "B2 untracked file under status.showUntrackedFiles=no → keep (dirty)";;
  *) bad "B2 untracked-hidden: $(row "$P" session-dirs "$W/untracked-hidden")";; esac
case "$(row "$P" session-dirs "$W/tag-light")" in keep/clone-has-unpushed-tag) ok "B3 commit held only by a lightweight local tag → keep";;
  *) bad "B3 tag-light: $(row "$P" session-dirs "$W/tag-light")";; esac
case "$(row "$P" session-dirs "$W/tag-annot")" in keep/clone-has-unpushed-tag) ok "B3 commit held only by an annotated local tag → keep";;
  *) bad "B3 tag-annot: $(row "$P" session-dirs "$W/tag-annot")";; esac
case "$(row "$P" session-dirs "$W/tag-pushed")" in remove/*) ok "control: tag on a pushed commit → remove";;
  *) bad "tag-pushed: $(row "$P" session-dirs "$W/tag-pushed")";; esac
case "$(row "$P" session-dirs "$W/hide-assume")" in keep/clone-index-hides-changes) ok "B4 assume-unchanged local edit in a clone → keep";;
  *) bad "B4 hide-assume: $(row "$P" session-dirs "$W/hide-assume")";; esac
case "$(row "$P" session-dirs "$W/hide-skip")" in keep/clone-index-hides-changes) ok "B4 skip-worktree local edit in a clone → keep";;
  *) bad "B4 hide-skip: $(row "$P" session-dirs "$W/hide-skip")";; esac
case "$(row "$P" session-dirs "$W/hide-nested")" in keep/nested-index-hides-changes) ok "B4 skip-worktree local edit in a nested clone → keep";;
  *) bad "B4 hide-nested: $(row "$P" session-dirs "$W/hide-nested")";; esac
case "$(row "$P" worktrees "$W/hide-wt")" in keep/index-hides-changes) ok "B4 assume-unchanged local edit in a linked worktree → keep";;
  *) bad "B4 hide-wt: $(row "$P" worktrees "$W/hide-wt")";; esac
case "$(row "$P" session-dirs "$W/wt-elsewhere")" in keep/clone-worktree-not-this-folder) ok "B5 core.worktree elsewhere → keep";;
  *) bad "B5 wt-elsewhere: $(row "$P" session-dirs "$W/wt-elsewhere")";; esac
case "$(row "$P" session-dirs "$W/wt-self-link")" in remove/*) ok "control: core.worktree a symlink to the folder itself → remove";;
  *) bad "wt-self-link: $(row "$P" session-dirs "$W/wt-self-link")";; esac

# apply re-checks every row: feed it the dangerous folders as if a stale plan had said remove
printf 'session-dirs\t%s\n' "$W/wt-owner" "$W/untracked-hidden" "$W/tag-light" "$W/tag-annot" \
  "$W/hide-assume" "$W/hide-skip" "$W/hide-nested" "$W/wt-elsewhere" > "$FX/apply.tsv"
printf 'worktrees\t%s\n' "$W/hide-wt" >> "$FX/apply.tsv"
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
[ -d "$W/wt-owner/.git" ] && [ "$(git -C "$W/wt-outside" rev-parse HEAD 2>/dev/null)" = "$OUT_SHA" ] \
  && git -C "$W/wt-outside" cat-file -e "$OUT_SHA^{commit}" 2>/dev/null \
  && ok "B1 apply refused the owner; the linked worktree's unpushed commit survives" || bad "B1 after apply: $(cat "$FX/apply.out")"
[ -f "$W/untracked-hidden/notes.txt" ] && ok "B2 apply refused; the untracked file survives" || bad "B2 notes.txt gone"
git -C "$W/tag-light" cat-file -e "$TL_SHA^{commit}" 2>/dev/null && git -C "$W/tag-annot" cat-file -e "$TA_SHA^{commit}" 2>/dev/null \
  && ok "B3 apply refused; the tag-only commits survive" || bad "B3 tag-only commit gone"
for c in hide-assume hide-skip hide-nested/repo hide-wt; do
  /usr/bin/grep -q LOCAL-EDIT "$W/$c/README" 2>/dev/null && ok "B4 apply refused; the hidden edit in $c survives" || bad "B4 hidden edit in $c gone"
done
[ -f "$W/wt-elsewhere/notes.txt" ] && ok "B5 apply refused; the folder's own file survives" || bad "B5 notes.txt gone"
[ "$(/usr/bin/awk -F'\t' '$2=="removed"' "$FX/apply.out" | wc -l | tr -d ' ')" = 0 ] && ok "apply removed none of them" \
  || bad "apply removed: $(awk -F'\t' '$2=="removed"' "$FX/apply.out")"

# fail toward keep: a git whose `worktree list` fails ⇒ the clone is kept, unread
mkdir -p "$FX/bin"
cat > "$FX/bin/git" <<'SH'
#!/bin/bash
for a in "$@"; do [ "$a" = worktree ] && { echo "simulated failure" >&2; exit 128; }; done
exec /usr/bin/git "$@"
SH
chmod +x "$FX/bin/git"
HYG_GIT="$FX/bin/git" bash "$HYG" plan > "$FX/plan-fail.tsv" 2>/dev/null
case "$(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")" in keep/clone-git-worktree-list-failed) ok "B1 \`git worktree list\` failing → keep";;
  *) bad "worktree-list failure: $(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")";; esac

# fail toward keep: a git whose `ls-files` fails, then one whose `rev-parse --show-toplevel` fails
cat > "$FX/bin/git" <<'SH'
#!/bin/bash
for a in "$@"; do [ "$a" = ls-files ] && { echo "simulated failure" >&2; exit 128; }; done
exec /usr/bin/git "$@"
SH
HYG_GIT="$FX/bin/git" bash "$HYG" plan > "$FX/plan-fail.tsv" 2>/dev/null
case "$(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")" in keep/clone-git-ls-files-failed) ok "B4 \`git ls-files\` failing → keep";;
  *) bad "ls-files failure: $(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")";; esac
cat > "$FX/bin/git" <<'SH'
#!/bin/bash
for a in "$@"; do [ "$a" = --show-toplevel ] && { echo "simulated failure" >&2; exit 128; }; done
exec /usr/bin/git "$@"
SH
HYG_GIT="$FX/bin/git" bash "$HYG" plan > "$FX/plan-fail.tsv" 2>/dev/null
case "$(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")" in keep/clone-worktree-not-this-folder) ok "B5 \`rev-parse --show-toplevel\` failing → keep";;
  *) bad "show-toplevel failure: $(row "$FX/plan-fail.tsv" session-dirs "$W/tag-pushed")";; esac

echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
