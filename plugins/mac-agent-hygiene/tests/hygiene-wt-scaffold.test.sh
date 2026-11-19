#!/bin/bash
# hygiene-wt-scaffold.test.sh — card d9GJrXfc: a worktree whose ONLY dirt is the agent session's own
# untracked scaffolding (PROMPT.md, docs/qa/<card>/...) no longer pins it forever. Runs the REAL
# scripts/hygiene.sh against a fixture HOME (local bare "github.com/acme/demo" origin, no gh).
#
#   KNOWN-POSITIVE  pushed + only `?? PROMPT.md`                        → remove pushed-scaffold-only
#   KNOWN-POSITIVE  pushed + only `?? docs/qa/GTFuHzt9/...` in folder qa-GTFuHzt9 → remove pushed-scaffold-only
#   KNOWN-POSITIVE  only `?? docs/qa/Xy7Kp2Qa/...` on branch card/Xy7Kp2Qa-…    → remove pushed-scaffold-only
#   KNOWN-NEGATIVE  B1 (review 5817501927): docs/qa/<id> the worktree does NOT declare → keep
#                   dirty-uncommitted-work: docs/qa/database/schema.sql (also in a folder named
#                   research-database), another card's id, a date token of the folder name
#   KNOWN-NEGATIVE  B2: a locked worktree with only PROMPT.md → keep locked; apply refuses, PROMPT.md intact
#   KNOWN-NEGATIVE  B2: `git worktree remove` fails after the delete → refused remove-failed and every
#                   scaffold file is back byte for byte (mode too), the folder still reads as idle
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
# (BR=<branch> overrides the branch name)
mkwt(){ local w="$CODE/wt/pipe-test/$1" br="${BR:-b-$1}"; mkdir -p "$(dirname "$w")"
  q -C "$MAIN" worktree add -q -b "$br" "$w"; echo "$1" > "$w/f-$1"; q -C "$w" add "f-$1"; q -C "$w" commit -qm "work $1"
  [ "${2:-push}" = push ] && q -C "$w" push -q origin "$br"; printf '%s' "$w"; }

CLEAN=$(mkwt clean)
PROMPT=$(mkwt prompt-only);   printf 'phase prompt\nline 2\n' > "$PROMPT/PROMPT.md"
QA=$(mkwt qa-GTFuHzt9);       mkdir -p "$QA/docs/qa/GTFuHzt9/shots"; echo evidence > "$QA/docs/qa/GTFuHzt9/report.md"; echo png > "$QA/docs/qa/GTFuHzt9/shots/a.png"
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
QABR=$(BR=card/Xy7Kp2Qa-fix-thing mkwt qa-branch); mkdir -p "$QABR/docs/qa/Xy7Kp2Qa"; echo e > "$QABR/docs/qa/Xy7Kp2Qa/r.md"
# B1: an 8-character folder under docs/qa/ that the worktree does not declare is real work
QADB=$(mkwt qa-db);           mkdir -p "$QADB/docs/qa/database"; echo 'create table t(id int);' > "$QADB/docs/qa/database/schema.sql"
QADB2=$(mkwt research-database); mkdir -p "$QADB2/docs/qa/database"; echo x > "$QADB2/docs/qa/database/x"
QAOTH=$(mkwt w2-Pq8Lm3Zt);    mkdir -p "$QAOTH/docs/qa/GTFuHzt9"; echo x > "$QAOTH/docs/qa/GTFuHzt9/x"
QADATE=$(mkwt pipe-sUIVGVt2-20261114-2352); mkdir -p "$QADATE/docs/qa/20261114"; echo x > "$QADATE/docs/qa/20261114/x"
# B2: a locked worktree, and one whose `git worktree remove` fails after the scaffold is deleted
LOCKED=$(mkwt locked);        printf 'locked prompt\n' > "$LOCKED/PROMPT.md"; q -C "$MAIN" worktree lock "$LOCKED"
RMFAIL=$(mkwt rmfail-Rk4Tz9Qa); printf 'rm-fail prompt\n' > "$RMFAIL/PROMPT.md"; chmod 640 "$RMFAIL/PROMPT.md"
mkdir -p "$RMFAIL/docs/qa/Rk4Tz9Qa"; printf 'evidence\n' > "$RMFAIL/docs/qa/Rk4Tz9Qa/report.md"
SAVE="$FX/saved"; mkdir -p "$SAVE"; cp -p "$RMFAIL/PROMPT.md" "$SAVE/PROMPT.md"; cp -p "$RMFAIL/docs/qa/Rk4Tz9Qa/report.md" "$SAVE/report.md"; cp -p "$LOCKED/PROMPT.md" "$SAVE/locked.md"
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
expect "$QABR"     "remove pushed-scaffold-only"  "docs/qa/<id> declared by branch card/<id>-…"
expect "$QADB"     "keep dirty-uncommitted-work"  "B1 docs/qa/database/schema.sql"
expect "$QADB2"    "keep dirty-uncommitted-work"  "B1 docs/qa/database/ in folder research-database"
expect "$QAOTH"    "keep dirty-uncommitted-work"  "B1 docs/qa/<another card's id>/"
expect "$QADATE"   "keep dirty-uncommitted-work"  "B1 docs/qa/<date token of the folder name>/"
expect "$LOCKED"   "keep locked"                  "B2 locked worktree with only PROMPT.md"
expect "$RMFAIL"   "remove pushed-scaffold-only"  "B2 rm-fail fixture plans as removable"

# ---- apply: a real file lands in LATE after the plan; NOARCH's archive dir is unwritable ----
echo "real work" > "$LATE/new-work.txt"; touch -t 202001010000 "$LATE/new-work.txt" "$LATE"   # old, so only the dirt rule can refuse it
expect "$NOARCH"   "remove pushed-scaffold-only"  "no-archive fixture plans as removable"
awk -F'\t' -v n="$NOARCH" -v r="$RMFAIL" '$2=="remove" && $5!=n && $5!=r {print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"   # NOARCH, RMFAIL get their own runs below
printf 'worktrees\t%s\n' "$LATE" >> "$FX/real.tsv"
for w in "$TRACKED" "$MIXED" "$CORRUPT"; do printf 'worktrees\t%s\n' "$w" >> "$FX/real.tsv"; done
bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1

for d in "$CLEAN" "$PROMPT" "$QA" "$QABR"; do [ ! -e "$d" ] && ok "removed $d" || bad "still present: $d ($(cat "$FX/apply.out"))"; done
awk -F'\t' -v p="$LATE" '$5==p && $2=="refused" && $4=="dirty-uncommitted-work"{f=1} END{exit !f}' "$FX/apply.out" \
  && ok "apply refuses a worktree that gained a real file after the plan" || bad "late: $(grep "$LATE" "$FX/apply.out")"
[ -f "$LATE/PROMPT.md" ] && [ -f "$LATE/new-work.txt" ] && ok "late worktree intact" || bad "late worktree touched"
for d in "$TRACKED" "$MIXED" "$CORRUPT"; do [ -d "$d" ] && ok "apply refused hand-written $d" || bad "removed $d"; done
[ -f "$MIXED/PROMPT.md" ] && [ -f "$MIXED/notes.txt" ] && ok "mixed worktree files intact" || bad "mixed worktree files touched"

# the archive: dated folder, one tarball per removed scaffold worktree, contents byte-identical
TODAY=$(date +%F)
n=$(find "$ARCH/$TODAY" -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 3 ] && ok "three scaffold archives under $TODAY" || bad "expected 3 archives, got $n: $(ls -R "$ARCH" 2>&1)"
PT=$(find "$ARCH/$TODAY" -name '*prompt-only*.tar.gz' | head -1)
QT=$(find "$ARCH/$TODAY" -name '*qa-GTFuHzt9*.tar.gz' | head -1)
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

# ---- B2: locked worktree, forced into an apply → refused locked, nothing touched ----
ARCH2="$FX/arch2"
printf 'worktrees\t%s\n' "$LOCKED" > "$FX/locked.tsv"
HYG_SCAFFOLD_ARCHIVE="$ARCH2" bash "$HYG" apply "$FX/locked.tsv" > "$FX/locked.out" 2>&1
awk -F'\t' -v p="$LOCKED" '$5==p && $2=="refused" && $4=="locked"{f=1} END{exit !f}' "$FX/locked.out" \
  && ok "B2 apply refuses a locked worktree (reason locked)" || bad "locked: $(cat "$FX/locked.out")"
cmp -s "$SAVE/locked.md" "$LOCKED/PROMPT.md" && ok "B2 locked worktree keeps PROMPT.md byte for byte" || bad "B2 locked PROMPT.md changed or gone"
[ -z "$(find "$ARCH2" -name '*.tar.gz' 2>/dev/null)" ] && ok "B2 nothing archived for a locked worktree" || bad "B2 locked worktree was archived"

# ---- B2: `git worktree remove` fails AFTER the scaffold was archived and deleted → restored ----
GITFAIL="$FX/git-refuses-remove"
printf '#!/bin/bash\n[ "${1:-}" = -C ] && [ "${3:-}" = worktree ] && [ "${4:-}" = remove ] && { echo "test: remove refused" >&2; exit 1; }\nexec "%s" "$@"\n' "$GITBIN" > "$GITFAIL"
chmod 755 "$GITFAIL"
printf 'worktrees\t%s\n' "$RMFAIL" > "$FX/rmfail.tsv"
HYG_GIT="$GITFAIL" HYG_SCAFFOLD_ARCHIVE="$ARCH2" bash "$HYG" apply "$FX/rmfail.tsv" > "$FX/rmfail.out" 2>&1
awk -F'\t' -v p="$RMFAIL" '$5==p && $2=="refused" && $4=="remove-failed"{f=1} END{exit !f}' "$FX/rmfail.out" \
  && ok "B2 a failed remove reports refused remove-failed" || bad "rmfail: $(cat "$FX/rmfail.out")"
[ -n "$(find "$ARCH2" -name '*rmfail*.tar.gz' 2>/dev/null)" ] && ok "B2 rm-fail scaffold was archived (the delete really ran)" || bad "B2 no archive: the failure path was not exercised"
cmp -s "$SAVE/PROMPT.md" "$RMFAIL/PROMPT.md" && ok "B2 PROMPT.md restored byte for byte" || bad "B2 PROMPT.md not restored"
cmp -s "$SAVE/report.md" "$RMFAIL/docs/qa/Rk4Tz9Qa/report.md" && ok "B2 docs/qa/<id>/ restored byte for byte" || bad "B2 qa report not restored"
mode(){ ls -l "$1" | awk '{print $1}'; }
[ "$(mode "$SAVE/PROMPT.md")" = "$(mode "$RMFAIL/PROMPT.md")" ] && ok "B2 PROMPT.md mode restored" || bad "B2 mode $(mode "$RMFAIL/PROMPT.md") != $(mode "$SAVE/PROMPT.md")"
[ -z "$(find "$RMFAIL" -maxdepth 0 -mtime -1)" ] && [ -z "$(find "$RMFAIL" -type f -mtime -1 -not -path '*/.git' 2>/dev/null)" ] \
  && ok "B2 the kept tree still reads as idle (folder + file mtimes restored)" || bad "B2 the restore made the tree look touched"
[ -z "$("$GITBIN" -C "$RMFAIL" status --porcelain | grep -v -e '^?? PROMPT.md$' -e '^?? docs/')" ] && ok "B2 git status unchanged after the restore" || bad "B2 status: $("$GITBIN" -C "$RMFAIL" status --porcelain)"
grep -q "scaffold of $RMFAIL restored" "$HYG_LOG" && ok "B2 log names the restore" || bad "B2 no restore line in log"
bash "$HYG" plan > "$FX/plan2.tsv" 2>/dev/null
awk -F'\t' -v p="$RMFAIL" '$5==p && $2=="remove" && $4=="pushed-scaffold-only"{f=1} END{exit !f}' "$FX/plan2.tsv" \
  && ok "B2 next plan sees the restored tree exactly as before" || bad "B2 re-plan: $(awk -F'\t' -v p="$RMFAIL" '$5==p' "$FX/plan2.tsv")"

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
