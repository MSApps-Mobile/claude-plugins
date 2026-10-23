#!/bin/bash
# hygiene-worktrees.test.sh — the worktree rules of card SIDmENpf, against the REAL scripts/hygiene.sh.
#
# Fixture HOME with a fake "github.com/acme/demo" origin (a local bare repo) and a stubbed `gh`:
#
#   KNOWN-POSITIVE  a pushed worktree nested under wt/pipe-*/... is planned as remove (pushed)
#   KNOWN-POSITIVE  a legacy direct child ~/code/agent-wt-1 is still planned as remove
#   KNOWN-POSITIVE  a rebased branch whose MERGED PR has another head SHA, but whose local-only commit
#                   subjects all match the PR's commits (one via gh's "…" truncation) → remove (merged-pr-commits)
#   KNOWN-NEGATIVE  same, but one local subject has no match among the PR's commits → keep (unpushed-commits)
#   KNOWN-NEGATIVE  a full clone under wt/sup-*/... is never listed, and apply refuses a hand-written line for it
#   KNOWN-NEGATIVE  a linked worktree outside the agent dirs (~/code/project-feature) is never listed
#   KNOWN-POSITIVE  apply removes exactly the planned worktrees; branch refs survive (`git worktree remove`)
#
# Needs git and the absolute-path tools hygiene.sh calls (/usr/bin/find, /usr/bin/du, ...); prints SKIP
# without them. lsof is optional (missing ⇒ no cwd is "inside"). Nothing here touches the real HOME.
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-wt-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"   # macOS: /var → /private/var, so git's absolute paths compare equal
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$CODE"
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=1 HYG_GIT="$GITBIN" HYG_GH="$FX/bin/gh"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }
commit(){ echo "$2" > "$1/$(echo "$2" | tr -c 'a-zA-Z0-9\n' _)"; q -C "$1" add -A; q -C "$1" commit -qm "$2"; }

# ---- origin + main clone ---------------------------------------------------------------------------
ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
commit "$MAIN" "initial"; q -C "$MAIN" push -q origin HEAD:main

# 1) nested pushed worktree: ~/code/wt/pipe-123/demo
NESTED="$CODE/wt/pipe-123/demo"; mkdir -p "$(dirname "$NESTED")"
q -C "$MAIN" worktree add -q -b feat-nested "$NESTED"
commit "$NESTED" "nested work"; q -C "$NESTED" push -q origin feat-nested

# 2) legacy direct child ~/code/agent-wt-1, pushed
LEGACY="$CODE/agent-wt-1"
q -C "$MAIN" worktree add -q -b feat-legacy "$LEGACY"
commit "$LEGACY" "legacy work"; q -C "$LEGACY" push -q origin feat-legacy

# 3) rebased: two local-only commits; the merged PR (#101) has a different head SHA
LONG="Refactor the hygiene worktree scanner so nested phase directories are walked too"
REBASED="$CODE/wt/pipe-456/demo"; mkdir -p "$(dirname "$REBASED")"
q -C "$MAIN" worktree add -q -b feat-rebased "$REBASED"
commit "$REBASED" "fix: walk nested worktrees"; commit "$REBASED" "$LONG"

# 4) inconclusive: one local subject matches PR #102, one does not
INCONC="$CODE/wt/ref-789/demo"; mkdir -p "$(dirname "$INCONC")"
q -C "$MAIN" worktree add -q -b feat-inconclusive "$INCONC"
commit "$INCONC" "fix: shared subject"; commit "$INCONC" "an extra local experiment"

# 5) full clone under wt/: must never be removed
CLONE="$CODE/wt/sup-1/demo"; mkdir -p "$(dirname "$CLONE")"; q clone -q "$ORIGIN" "$CLONE"

# 6) a human's own linked worktree outside the agent dirs: out of scope even though pushed
OWN="$CODE/project-feature"
q -C "$MAIN" worktree add -q -b own-feature "$OWN"
commit "$OWN" "own work"; q -C "$OWN" push -q origin own-feature

q -C "$MAIN" fetch -q origin

# ---- gh stub -----------------------------------------------------------------------------------------
mkdir -p "$FX/bin"
cat > "$FX/bin/gh" <<EOF
#!/bin/bash
case "\$*" in
  *"pr list --repo acme/demo --state merged"*)
    echo "feat-rebased 0000000000000000000000000000000000000000 101"
    echo "feat-inconclusive 1111111111111111111111111111111111111111 102" ;;
  *"pr view 101 --repo acme/demo"*)
    echo "fix: walk nested worktrees"
    echo "${LONG:0:60}…" ;;
  *"pr view 102 --repo acme/demo"*)
    echo "fix: shared subject" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FX/bin/gh"

# Age everything (worktree contents and dirs) past HYG_WT_AGE_DAYS.
find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
row(){ awk -F'\t' -v p="$1" '$1=="worktrees" && $5==p {print $2" "$4}' "$PLAN"; }

expect(){ # path "action reason" label
  local got; got="$(row "$1")"
  if [ "$got" = "$2" ]; then ok "$3: $2"; else bad "$3: expected '$2', got '${got:-<not listed>}'"; fi; }
expect "$NESTED"  "remove pushed"            "nested wt/pipe-*/demo"
expect "$LEGACY"  "remove pushed"            "legacy direct child agent-wt-1"
expect "$REBASED" "remove merged-pr-commits" "rebased branch, PR commit subjects match"
expect "$INCONC"  "keep unpushed-commits"    "inconclusive branch, one subject unmatched"
[ -z "$(row "$CLONE")" ] && ok "full clone under wt/ is not listed" || bad "full clone listed: $(row "$CLONE")"
[ -z "$(row "$OWN")" ] && ok "own worktree outside agent dirs is not listed" || bad "own worktree listed: $(row "$OWN")"
[ -z "$(row "$MAIN")" ] && ok "main clone is not listed" || bad "main clone listed"

# ---- apply refuses hand-written lines for the clone, the out-of-scope worktree and the inconclusive one ----
printf 'worktrees\t%s\nworktrees\t%s\nworktrees\t%s\n' "$CLONE" "$OWN" "$INCONC" > "$FX/evil.tsv"
OUT="$(bash "$HYG" apply "$FX/evil.tsv" 2>&1)"
n="$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="refused"' | wc -l | tr -d ' ')"
[ "$n" = 3 ] && ok "apply refuses clone / out-of-scope / inconclusive" || bad "apply did not refuse all three: $OUT"
printf '%s\n' "$OUT" | awk -F'\t' -v p="$CLONE" '$5==p && $4=="not-a-linked-worktree"{f=1} END{exit !f}' \
  && ok "clone refused as not-a-linked-worktree" || bad "clone not refused with not-a-linked-worktree"
[ -d "$CLONE/.git" ] && [ -d "$OWN" ] && [ -d "$INCONC" ] && ok "clone, own and inconclusive dirs intact" || bad "a kept dir was removed"

# ---- apply the real plan --------------------------------------------------------------------------
awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1
for d in "$NESTED" "$LEGACY" "$REBASED"; do [ ! -e "$d" ] && ok "removed $d" || bad "still present: $d"; done
for d in "$INCONC" "$CLONE" "$OWN" "$MAIN"; do [ -d "$d" ] && ok "kept $d" || bad "removed $d"; done
"$GITBIN" -C "$MAIN" rev-parse -q --verify refs/heads/feat-rebased >/dev/null && ok "branch feat-rebased survives removal" \
  || bad "branch ref feat-rebased is gone"
! "$GITBIN" -C "$MAIN" worktree list --porcelain | grep -qF "$REBASED" && ok "git worktree list no longer has the rebased worktree" \
  || bad "worktree metadata not pruned"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
