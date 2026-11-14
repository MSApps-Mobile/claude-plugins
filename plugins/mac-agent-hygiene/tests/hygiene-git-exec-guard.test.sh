#!/bin/bash
# hygiene-git-exec-guard.test.sh — card JQ96IKNK security rework: repo-owned config must never make the
# read-only checks run a program, or judge a different tree than the one rm -rf removes. Runs against the
# REAL scripts/hygiene.sh in a throwaway HOME (Linux and macOS):
#
#   KNOWN-NEGATIVE  a linked worktree whose repo config sets log.showSignature=true + gpg.program (and
#                   gpg.ssh.program / gpg.x509.program) on a signed, unpushed commit: `plan` keeps it
#                   (repo-config-not-allowlisted) and the program NEVER runs (no marker file)
#   KNOWN-NEGATIVE  the same keys in the user's GLOBAL config (the deny-list reads only repo files):
#                   `plan` still never runs the program (GITS forces log.showSignature=false)
#
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-exec-guard.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
export HYG_WT_ROOT="$CODE" HYG_WT_NESTED="wt" HYG_WT_DEPTH=3 HYG_SESSION_ROOT="$CODE/wt" HYG_SESSION_PARENT_BRANCH_OK=0
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_GRADLE_HOME="$HOME/gr-none"
export HYG_DEVICE_SUPPORT="$HOME/ds-none" HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/an-none" HYG_PKG_CACHES=""
# The merged-PR path must be live: it is the one that runs `git log HEAD --not --remotes`. The fake gh
# answers nothing, so every repo here stays KEPT whatever happens — the assertion is the marker file.
cat > "$FX/fake-gh" <<'FAKE'
#!/bin/bash
exit 0
FAKE
chmod +x "$FX/fake-gh"
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=1 HYG_GIT="$GITBIN" HYG_GH="$FX/fake-gh" HYG_LOCK="$FX/lock"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
commit(){ echo "$2" > "$1/$(echo "$2" | tr -c 'a-zA-Z0-9\n' _)"; q -C "$1" add -A; q -C "$1" commit -qm "$2"; }
# A commit carrying a gpgsig header, built by hand so no signer is needed. Same tree as HEAD ⇒ still clean.
signed_commit(){ local d="$1" tree parent sha
  tree="$("$GITBIN" -C "$d" rev-parse 'HEAD^{tree}')"; parent="$("$GITBIN" -C "$d" rev-parse HEAD)"
  sha="$(printf 'tree %s\nparent %s\nauthor t <t@example.com> 1600000000 +0000\ncommitter t <t@example.com> 1600000000 +0000\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n iQEzBAABCAAdFiEE\n -----END PGP SIGNATURE-----\n\n%s\n' \
    "$tree" "$parent" "$2" | "$GITBIN" -C "$d" hash-object -t commit -w --stdin)"
  q -C "$d" reset -q --soft "$sha"; }
# The "signature verifier": writes a marker when git runs it.
cat > "$FX/evil-gpg" <<EVIL
#!/bin/sh
echo "\$0 \$*" >> "$FX/PWNED"
exit 1
EVIL
chmod +x "$FX/evil-gpg"

ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
commit "$MAIN" "initial"; q -C "$MAIN" push -q origin HEAD:main

# --- repo-local keys: a worktree of a parent whose config carries the exec keys
EVILP="$CODE/evil-parent"; q clone -q "$ORIGIN" "$EVILP"
SIG="$CODE/wt/pipe-sig/repo"; mkdir -p "$(dirname "$SIG")"; q -C "$EVILP" worktree add -q -b sig-local "$SIG" origin/main
signed_commit "$SIG" "signed local work"
q -C "$EVILP" config log.showSignature true
q -C "$EVILP" config gpg.program "$FX/evil-gpg"
q -C "$EVILP" config gpg.ssh.program "$FX/evil-gpg"
q -C "$EVILP" config gpg.x509.program "$FX/evil-gpg"
# --- global keys only: a plain worktree whose repo config is clean
GLOB="$CODE/wt/pipe-sig-global/repo"; mkdir -p "$(dirname "$GLOB")"; q -C "$MAIN" worktree add -q -b sig-global "$GLOB" origin/main
signed_commit "$GLOB" "signed global work"
q -C "$MAIN" fetch -q origin
find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null

# sanity: the fixture really does make git run the program when nothing guards it
rm -f "$FX/PWNED"; "$GITBIN" -C "$SIG" log --format=%s HEAD --not --remotes >/dev/null 2>&1
[ -s "$FX/PWNED" ] && ok "fixture: plain git log on the signed commit runs gpg.program (the hole is real)" \
  || bad "fixture: plain git log did not run gpg.program; the test proves nothing"
rm -f "$FX/PWNED"

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
act(){ awk -F'\t' -v c="$1" -v p="$2" '$1==c && $5==p {print $2" "$4}' "$3"; }
[ "$(act worktrees "$SIG" "$PLAN")" = "keep repo-config-not-allowlisted" ] \
  && ok "repo-local log.showSignature + gpg.program → worktree kept unread" || bad "signed worktree: '$(act worktrees "$SIG" "$PLAN")'"
[ "$(act session-dirs "$CODE/wt/pipe-sig" "$PLAN")" = "keep nested-repo-config-not-allowlisted" ] \
  && ok "repo-local log.showSignature + gpg.program → session folder kept unread" || bad "signed session: '$(act session-dirs "$CODE/wt/pipe-sig" "$PLAN")'"
[ ! -e "$FX/PWNED" ] && ok "repo-local keys: plan never ran gpg.program (no marker)" || bad "plan ran the repo's gpg.program: $(cat "$FX/PWNED")"

# --- the same keys in the user's global config: the deny-list does not see them, GITS must override
q config --global log.showSignature true
q config --global gpg.program "$FX/evil-gpg"
rm -f "$FX/PWNED"
bash "$HYG" plan > "$FX/plan-global.tsv" 2>"$FX/plan.err" || bad "plan (global keys) exited non-zero: $(cat "$FX/plan.err")"
q config --global --unset log.showSignature
[ ! -e "$FX/PWNED" ] && ok "global log.showSignature: plan never ran gpg.program (no marker)" || bad "plan ran gpg.program under global showSignature: $(cat "$FX/PWNED")"
[ "$(act worktrees "$GLOB" "$FX/plan-global.tsv" | cut -d' ' -f1)" = keep ] && ok "global keys: unpushed signed worktree still kept" || bad "global worktree: '$(act worktrees "$GLOB" "$FX/plan-global.tsv")'"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
