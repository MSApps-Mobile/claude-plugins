#!/bin/bash
# hygiene-wt-scaffold.test.sh — card d9GJrXfc: a worktree whose ONLY dirt is the agent session's own
# untracked scaffolding (PROMPT.md, docs/qa/<card>/...) no longer pins it forever. Runs the REAL
# scripts/hygiene.sh against a fixture HOME (local bare "github.com/acme/demo" origin, no gh).
#
#   KNOWN-POSITIVE  pushed + only `?? PROMPT.md`                        → remove pushed-scaffold-only
#   KNOWN-POSITIVE  pushed + only `?? docs/qa/GTFuHzt9/...`             → remove pushed-scaffold-only
#   KNOWN-POSITIVE  apply archives the scaffolding to a dated .tar.gz first, then removes the worktree;
#                   the archive holds the files byte for byte and the branch ref survives
#   KNOWN-NEGATIVE  PROMPT.md + one real untracked file                → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  a modified tracked file                            → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  a modified tracked file + PROMPT.md                → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  PROMPT.md staged (`git add`)                       → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  only PROMPT.md, but HEAD is unpushed               → keep unpushed-commits
#   KNOWN-NEGATIVE  unreadable status (corrupt index)                  → keep git-status-failed
#   KNOWN-NEGATIVE  look-alikes: sub/PROMPT.md, prompt.md, docs/qa/<not an 8-char id>/x, a docs/qa/<id>
#                   FILE, PROMPT.md.bak                                → keep dirty-uncommitted-work
#   KNOWN-NEGATIVE  a real file appears after the plan → apply refuses, PROMPT.md and the tree intact
#   KNOWN-NEGATIVE  the archive cannot be written → apply refuses (remove-failed), nothing deleted
#   KNOWN-POSITIVE  the clean pushed worktree still goes as plain `pushed` (no regression)
#
# Needs git, tar and the absolute-path tools hygiene.sh calls; prints SKIP without them.
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp /usr/bin/tar; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
GITBIN="$(command -v git)" || { echo "SKIP: git not found"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-scaffold-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
trap 'chmod -R u+w "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

CODE="$HOME/code"
ARCH="$HOME/scaffold-archive"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$CODE"
export HYG_WT_AGE_DAYS=1 HYG_WT_MERGED_PR_CHECK=0 HYG_GIT="$GITBIN" HYG_GH="" HYG_SCAFFOLD_ARCHIVE="$ARCH"

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
q(){ "$GITBIN" "$@" >/dev/null 2>&1 || { echo "setup failed: git $*"; exit 1; }; }

ORIGIN="$FX/github.com/acme/demo.git"
mkdir -p "$(dirname "$ORIGIN")"; q init -q --bare "$ORIGIN"
MAIN="$CODE/demo"; q clone -q "$ORIGIN" "$MAIN"
echo base > "$MAIN/tracked.txt"; q -C "$MAIN" add tracked.txt; q -C "$MAIN" commit -qm initial; q -C "$MAIN" push -q origin HEAD:main

# mkwt <name>: a pushed linked worktree at ~/code/wt/pipe-test/<name> on branch b-<name>
mkwt(){ local w="$CODE/wt/pipe-test/$1"; mkdir -p "$(dirname "$w")"
  q -C "$MAIN" worktree add -q -b "b-$1" "$w"; echo "$1" > "$w/f-$1"; q -C "$w" add "f-$1"; q -C "$w" commit -qm "work $1"
  [ "${2:-push}" = push ] && q -C "$w" push -q origin "b-$1"; printf '%s' "$w"; }

CLEAN=$(mkwt clean)
PROMPT=$(mkwt prompt-only);   printf 'phase prompt\nline 2\n' > "$PROMPT/PROMPT.md"
QA=$(mkwt qa-only);           mkdir -p "$QA/docs/qa/GTFuHzt9/shots"; echo evidence > "$QA/docs/qa/GTFuHzt9/report.md"; echo png > "$QA/docs/qa/GTFuHzt9/shots/a.png"
MIXED=$(mkwt mixed);          echo p > "$MIXED/PROMPT.md"; echo real > "$MIXED/notes.txt"
TRACKED=$(mkwt tracked);      echo edit >> "$TRACKED/tracked.txt"
TRPROMPT=$(mkwt tracked-prompt); echo edit >> "$TRPROMPT/tracked.txt"; echo p > "$TRPROMPT/PROMPT.md"
STAGED=$(mkwt staged);        echo p > "$STAGED/PROMPT.md"; q -C "$STAGED" add PROMPT.md
UNPUSHED=$(mkwt unpushed nopush); echo p > "$UNPUSHED/PROMPT.md"
CORRUPT=$(mkwt corrupt);      echo p > "$CORRUPT/PROMPT.md"
LOOK1=$(mkwt look-sub);       mkdir -p "$LOOK1/sub"; echo p > "$LOOK1/sub/PROMPT.md"
LOOK2=$(mkwt look-case);      echo p > "$LOOK2/prompt.md"
LOOK3=$(mkwt look-qa-id);     mkdir -p "$LOOK3/docs/qa/not-a-card-id"; echo x > "$LOOK3/docs/qa/not-a-card-id/x"
LOOK4=$(mkwt look-qa-file);   mkdir -p "$LOOK4/docs/qa"; echo x > "$LOOK4/docs/qa/ABCD1234"
LOOK5=$(mkwt look-bak);       echo p > "$LOOK5/PROMPT.md.bak"
LATE=$(mkwt late);            echo p > "$LATE/PROMPT.md"
NOARCH=$(mkwt no-archive);    echo p > "$NOARCH/PROMPT.md"
q -C "$MAIN" fetch -q origin

# corrupt the worktree's own index AFTER setup: `git status` now fails, rev-parse still works
CGD=$("$GITBIN" -C "$CORRUPT" rev-parse --path-format=absolute --git-dir)
printf 'not an index' > "$CGD/index"
"$GITBIN" -C "$CORRUPT" status --porcelain >/dev/null 2>&1 && bad "fixture: corrupt index still reads" || ok "fixture: corrupt index makes git status fail"

find "$CODE" -exec touch -t 202001010000 {} + 2>/dev/null

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
row(){ awk -F'\t' -v p="$1" '$1=="worktrees" && $5==p {print $2" "$4}' "$PLAN"; }
expect(){ local got; got="$(row "$1")"
  if [ "$got" = "$2" ]; then ok "$3: $2"; else bad "$3: expected '$2', got '${got:-<not listed>}'"; fi; }

expect "$CLEAN"    "remove pushed"                "clean pushed worktree (no regression)"
expect "$PROMPT"   "remove pushed-scaffold-only"  "AC-3 only ?? PROMPT.md"
expect "$QA"       "remove pushed-scaffold-only"  "only ?? docs/qa/<card>/"
expect "$MIXED"    "keep dirty-uncommitted-work"    "PROMPT.md + a real untracked file"
expect "$TRACKED"  "keep dirty-uncommitted-work"  "AC-3 modified tracked file"
expect "$TRPROMPT" "keep dirty-uncommitted-work"  "modified tracked file + PROMPT.md"
expect "$STAGED"   "keep dirty-uncommitted-work"  "PROMPT.md staged"
expect "$UNPUSHED" "keep unpushed-commits"        "only PROMPT.md, unpushed HEAD"
expect "$CORRUPT"  "keep git-status-failed"       "unreadable status"
expect "$LOOK1"    "keep dirty-uncommitted-work"    "look-alike sub/PROMPT.md"
expect "$LOOK2"    "keep dirty-uncommitted-work"    "look-alike prompt.md"
expect "$LOOK3"    "keep dirty-uncommitted-work"    "look-alike docs/qa/<not an id>/"
expect "$LOOK4"    "keep dirty-uncommitted-work"    "look-alike docs/qa/<id> as a file"
expect "$LOOK5"    "keep dirty-uncommitted-work"    "look-alike PROMPT.md.bak"

# ---- apply: a real file lands in LATE after the plan; NOARCH's archive dir is unwritable ----
echo "real work" > "$LATE/new-work.txt"; touch -t 202001010000 "$LATE/new-work.txt" "$LATE"   # old, so only the dirt rule can refuse it
expect "$NOARCH"   "remove pushed-scaffold-only"  "no-archive fixture plans as removable"
awk -F'\t' -v n="$NOARCH" '$2=="remove" && $5!=n {print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"   # NOARCH gets its own run below
printf 'worktrees\t%s\n' "$LATE" >> "$FX/real.tsv"
for w in "$TRACKED" "$MIXED" "$CORRUPT"; do printf 'worktrees\t%s\n' "$w" >> "$FX/real.tsv"; done
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1

for d in "$CLEAN" "$PROMPT" "$QA"; do [ ! -e "$d" ] && ok "removed $d" || bad "still present: $d ($(cat "$FX/apply.out"))"; done
awk -F'\t' -v p="$LATE" '$5==p && $2=="refused" && $4=="dirty-uncommitted-work"{f=1} END{exit !f}' "$FX/apply.out" \
  && ok "apply refuses a worktree that gained a real file after the plan" || bad "late: $(grep "$LATE" "$FX/apply.out")"
[ -f "$LATE/PROMPT.md" ] && [ -f "$LATE/new-work.txt" ] && ok "late worktree intact" || bad "late worktree touched"
for d in "$TRACKED" "$MIXED" "$CORRUPT"; do [ -d "$d" ] && ok "apply refused hand-written $d" || bad "removed $d"; done
[ -f "$MIXED/PROMPT.md" ] && [ -f "$MIXED/notes.txt" ] && ok "mixed worktree files intact" || bad "mixed worktree files touched"

# the archive: dated folder, one tarball per removed scaffold worktree, contents byte-identical
TODAY=$(date +%F)
n=$(find "$ARCH/$TODAY" -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 2 ] && ok "two scaffold archives under $TODAY" || bad "expected 2 archives, got $n: $(ls -R "$ARCH" 2>&1)"
PT=$(find "$ARCH/$TODAY" -name '*prompt-only*.tar.gz' | head -1)
QT=$(find "$ARCH/$TODAY" -name '*qa-only*.tar.gz' | head -1)
X="$FX/x"; mkdir -p "$X/p" "$X/q"
[ -n "$PT" ] && tar -xzf "$PT" -C "$X/p" && [ "$(cat "$X/p/PROMPT.md")" = "$(printf 'phase prompt\nline 2')" ] \
  && ok "PROMPT.md recoverable byte for byte" || bad "PROMPT.md archive: ${PT:-missing}"
[ -n "$QT" ] && tar -xzf "$QT" -C "$X/q" && [ "$(cat "$X/q/docs/qa/GTFuHzt9/report.md")" = evidence ] && [ -f "$X/q/docs/qa/GTFuHzt9/shots/a.png" ] \
  && ok "docs/qa/<card>/ recoverable" || bad "qa archive: ${QT:-missing}"
"$GITBIN" -C "$MAIN" rev-parse -q --verify refs/heads/b-prompt-only >/dev/null && ok "branch b-prompt-only survives" || bad "branch ref gone"
grep -q "archived scaffold" "$HYG_LOG" && ok "log names the archive" || bad "no archive line in log"

# ---- archive cannot be written → refuse, keep everything ----
RO="$FX/ro"; mkdir -p "$RO"; chmod 500 "$RO"
printf 'worktrees\t%s\n' "$NOARCH" > "$FX/noarch.tsv"
HYG_SCAFFOLD_ARCHIVE="$RO/sub" bash "$HYG" apply "$FX/noarch.tsv" > "$FX/noarch.out" 2>&1
if [ -w "$RO" ]; then echo "ok   - SKIP unwritable-archive case (running as a user who can write anywhere)"
else
  awk -F'\t' -v p="$NOARCH" '$5==p && $2=="refused" && $4=="remove-failed"{f=1} END{exit !f}' "$FX/noarch.out" \
    && ok "unwritable archive → refused remove-failed" || bad "noarch: $(cat "$FX/noarch.out")"
  [ -f "$NOARCH/PROMPT.md" ] && ok "PROMPT.md kept when it could not be archived" || bad "PROMPT.md deleted without an archive"
fi

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
