#!/bin/bash
# mac-agent-hygiene — keeps a Mac that runs Claude Code agents from filling its disk.
#
#   hygiene.sh status            key<TAB>value lines (read-only)
#   hygiene.sh plan              category<TAB>action<TAB>kb<TAB>reason<TAB>path<TAB>age<TAB>blocker  (read-only dry run)
#                                age = idle bucket of the top-level folder (<1d, 1-7d, >7d; - outside ~/code/wt);
#                                blocker = the path that decided a keep, relative to the folder: the nested repo, the
#                                first HEAD of a bare or separate git-dir, the path a failed walk could not read
#                                (repo-walk-failed); . = the folder itself (alive, in use, its own clone, touched);
#                                kb is 0 on a keep younger than the report window: sizing it costs a full walk
#   hygiene.sh report [planfile] keep and remove rows grouped by age and reason, then every folder over the
#                                window that is kept, with its exact blocker (default: the last scheduled plan)
#   hygiene.sh apply <planfile>  re-checks every "category<TAB>path" line in <planfile> and removes
#                                only the ones that STILL qualify; prints result lines
#   hygiene.sh run               plan + apply everything eligible (what the LaunchAgent calls)
#
# It only ever removes things that regenerate themselves or that already live somewhere else:
#   derived-data     ~/Library/Developer/Xcode/DerivedData/*       skipped while Xcode builds
#   plugin-clones    ~/.claude/plugins/cache/temp_git_*            leftover plugin-install clones >24h
#   browser-caches   cache subfolders INSIDE ~/.cache/playwright-* persistent profiles — the
#                    profiles are logins; Cookies / Local Storage / IndexedDB / Login Data stay
#   model-caches     whole directories listed in HYG_MODEL_CACHES, not MODIFIED for HYG_MODEL_CACHE_AGE_DAYS
#                    (directory mtime — a model that is only read is still removed after the window and
#                    re-downloaded on next use; raise the window for models that must stay warm)
#   worktrees        linked git worktrees under HYG_WT_ROOT matching HYG_WT_GLOB with no file newer
#                    than HYG_WT_AGE_DAYS, clean, nobody's cwd, HEAD on a remote ref or a merged-PR
#                    head. Dirty / unpushed / in-use: KEPT. Note: "clean" is `git status --porcelain`,
#                    so gitignored files (a local .env, node_modules) go with the worktree.
#                    HYG_WT_ROOTS adds more "dir:glob" roots (default also ~/code/wt:*).
#   session-dirs     EVERY folder directly under HYG_SESSION_ROOT (~/code/wt) that is not a linked worktree
#                    (those are the worktrees pass): plain session folders AND full clones. Nothing touched
#                    for HYG_SESSION_AGE_HOURS, nobody's cwd, the session not alive in HYG_SESSIONS_JSON,
#                    and the folder's own clone plus EVERY git repo or worktree nested inside is clean and
#                    pushed (same test as worktrees). One dirty or unpushed repo keeps the whole folder.
#                    Retention (HYG_RETENTION_DAYS, off by default): a direct child of HYG_SESSION_ROOT idle that long is
#                    removed even when dirty or unpushed, ONLY after HYG_RESCUE_CMD has verified an archive of its
#                    commits, patches and small untracked files. See rescue_build; ignored files are NOT archived.
#   build-artifacts  node_modules, .next, dist, build, .turbo, coverage dirs inside any ~/code/wt/<session>
#                    folder (down to HYG_ARTIFACT_DEPTH) when the session folder is idle HYG_ARTIFACT_IDLE_HOURS,
#                    nobody's cwd is inside it, the session is not alive in HYG_SESSIONS_JSON, the dir holds
#                    no .git, bare repo or separate git-dir, and is git-IGNORED with no tracked file (outside a repo: only node_modules /
#                    .next / .turbo beside a package.json). The repo and its branches are never touched.
#   gradle           ~/.gradle/wrapper/dists/* and ~/.gradle/daemon/* versions older than
#                    HYG_GRADLE_AGE_DAYS, never the newest two, never one a running Gradle uses
#   ios              ~/Library/Developer/Xcode/iOS DeviceSupport/* older than HYG_DEVICE_SUPPORT_AGE_DAYS
#                    (never the newest; Xcode re-copies it from the device) and simulators whose runtime
#                    is gone (`simctl delete`); skipped while Xcode / Simulator runs. Archives are NEVER touched.
#   android          ~/.android/cache/* older than HYG_ANDROID_CACHE_AGE_DAYS. AVDs and SDK system images
#                    are user data: reported by `status`, never removed.
#   pkg-caches       ~/Library/Caches/CocoaPods, untouched for HYG_PKG_CACHE_AGE_DAYS (pod install refills it)
#
# Config: ~/.config/mac-agent-hygiene/config.env (optional). Environment variables win over the
# config file, so an MCP call can override one value for one run.
# Never sudo. Never /System, /Library, ~/Library/Application Support, keychains, mail, ~/.ssh.
set -u
umask 077

# ---------- configuration: defaults < config file < environment ----------
VARS="HYG_LOG HYG_DERIVED_DATA HYG_PLUGIN_CACHE HYG_PLUGIN_CLONE_MIN_AGE_MIN HYG_PW_GLOB HYG_MODEL_CACHES HYG_MODEL_CACHE_AGE_DAYS HYG_WT_ROOT HYG_WT_GLOB HYG_WT_ROOTS HYG_WT_AGE_DAYS HYG_WT_MERGED_PR_CHECK HYG_GH_SHA_CHECK_MAX HYG_GIT HYG_GH HYG_SESSION_ROOT HYG_SESSION_AGE_HOURS HYG_GRADLE_HOME HYG_GRADLE_AGE_DAYS HYG_DEVICE_SUPPORT HYG_DEVICE_SUPPORT_AGE_DAYS HYG_SIM_DEVICES HYG_ANDROID_HOME HYG_ANDROID_CACHE_AGE_DAYS HYG_ANDROID_SDK HYG_PKG_CACHES HYG_PKG_CACHE_AGE_DAYS HYG_LOCK HYG_SESSIONS_JSON HYG_ARTIFACT_IDLE_HOURS HYG_ARTIFACT_DEPTH HYG_JQ HYG_PLAN_BUDGET_MIN HYG_REPORT_AGE_DAYS HYG_STATE_DIR HYG_RETENTION_DAYS HYG_RETENTION_MAX_PER_RUN HYG_RESCUE_CMD"
for v in $VARS; do eval "ENV_$v=\"\${$v-}\""; done
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/mac-agent-hygiene/config.env"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"
for v in $VARS; do eval "e=\"\${ENV_$v}\""; [ -n "$e" ] && eval "$v=\"\$e\""; done

HYG_LOG="${HYG_LOG:-$HOME/Library/Logs/mac-agent-hygiene.log}"
HYG_DERIVED_DATA="${HYG_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"
HYG_PLUGIN_CACHE="${HYG_PLUGIN_CACHE:-$HOME/.claude/plugins/cache}"
HYG_PLUGIN_CLONE_MIN_AGE_MIN="${HYG_PLUGIN_CLONE_MIN_AGE_MIN:-1440}"
HYG_PW_GLOB="${HYG_PW_GLOB:-$HOME/.cache/playwright-*}"
HYG_MODEL_CACHES="${HYG_MODEL_CACHES:-$HOME/.cache/whisper $HOME/.cache/codex-runtimes}"
HYG_MODEL_CACHE_AGE_DAYS="${HYG_MODEL_CACHE_AGE_DAYS:-7}"
HYG_WT_ROOT="${HYG_WT_ROOT:-$HOME/code}"; HYG_WT_ROOT="${HYG_WT_ROOT%/}"
HYG_WT_GLOB="${HYG_WT_GLOB:-*wt-*}"
HYG_WT_AGE_DAYS="${HYG_WT_AGE_DAYS:-7}"
HYG_WT_MERGED_PR_CHECK="${HYG_WT_MERGED_PR_CHECK:-1}"
HYG_GH_SHA_CHECK_MAX="${HYG_GH_SHA_CHECK_MAX:-500}"   # gh compare calls per run for in_github_default; over it ⇒ KEEP
HYG_WT_ROOTS="${HYG_WT_ROOTS-$HYG_WT_ROOT:$HYG_WT_GLOB $HOME/code/wt:*}"   # space-separated dir:glob pairs
HYG_SESSION_ROOT="${HYG_SESSION_ROOT:-$HOME/code/wt}"; HYG_SESSION_ROOT="${HYG_SESSION_ROOT%/}"
HYG_SESSION_AGE_HOURS="${HYG_SESSION_AGE_HOURS:-24}"
HYG_SESSIONS_JSON="${HYG_SESSIONS_JSON:-$HOME/.local/state/opsagents-routines/sessions.json}"
HYG_ARTIFACT_IDLE_HOURS="${HYG_ARTIFACT_IDLE_HOURS:-24}"
HYG_ARTIFACT_DEPTH="${HYG_ARTIFACT_DEPTH:-6}"
HYG_PLAN_BUDGET_MIN="${HYG_PLAN_BUDGET_MIN:-12}"   # worktrees + build-artifacts + session-dirs wall clock; what is left waits for the next run. 0 = no limit
HYG_REPORT_AGE_DAYS="${HYG_REPORT_AGE_DAYS:-7}"
HYG_STATE_DIR="${HYG_STATE_DIR:-$HOME/.local/state/mac-agent-hygiene}"
HYG_RETENTION_DAYS="${HYG_RETENTION_DAYS:-}"          # unset = no retention: dirty or unpushed work is simply kept
HYG_RETENTION_MAX_PER_RUN="${HYG_RETENTION_MAX_PER_RUN:-10}"
HYG_RESCUE_CMD="${HYG_RESCUE_CMD:-}"                  # <dir> <object-prefix>; exit 0 = every file in <dir> stored and verified. Unset = keep
RESCUE_MAX_BYTES=$((20*1024*1024)); RESCUE_FILE_MAX_BYTES=$((5*1024*1024)); RESCUE_PART_BYTES=3145728; RESCUE_MAX_PARTS=9
# Never leaves this Mac, by name (S1, review 5748468367). A loose or untracked file with one of these names is
# dropped and listed; one inside the patch or in an unpushed commit keeps the WHOLE folder (rescue-denied-name-*).
# Lower case: name_denied folds the name first (this Mac's disk ignores case, so Server.PEM is server.pem).
RESCUE_DENY_NAMES='.env .env.* .envrc *.pem *.key *.p8 *.p12 *.pfx *.jks *.keystore id_rsa* id_dsa* id_ecdsa* id_ed25519* .npmrc .netrc .pypirc .git-credentials credentials *.tfstate *.tfstate.* *credentials*.json *service-account*.json'
# Split once with globbing off: an unquoted `for p in $RESCUE_DENY_NAMES` expands `*.pem` against the cwd, so a
# decoy x.pem in the cwd turned the pattern into the literal name x.pem and server.pem went out.
set -f
# shellcheck disable=SC2206  # word splitting is the point; globbing is off
RESCUE_DENY=( $RESCUE_DENY_NAMES )
set +f
GRACE_REGISTRY_DAYS=14
HYG_GRADLE_HOME="${HYG_GRADLE_HOME:-${GRADLE_USER_HOME:-$HOME/.gradle}}"; HYG_GRADLE_HOME="${HYG_GRADLE_HOME%/}"
HYG_GRADLE_AGE_DAYS="${HYG_GRADLE_AGE_DAYS:-30}"
HYG_DEVICE_SUPPORT="${HYG_DEVICE_SUPPORT:-$HOME/Library/Developer/Xcode/iOS DeviceSupport}"; HYG_DEVICE_SUPPORT="${HYG_DEVICE_SUPPORT%/}"
HYG_DEVICE_SUPPORT_AGE_DAYS="${HYG_DEVICE_SUPPORT_AGE_DAYS:-90}"
HYG_SIM_DEVICES="${HYG_SIM_DEVICES:-$HOME/Library/Developer/CoreSimulator/Devices}"; HYG_SIM_DEVICES="${HYG_SIM_DEVICES%/}"
HYG_ANDROID_HOME="${HYG_ANDROID_HOME:-$HOME/.android}"; HYG_ANDROID_HOME="${HYG_ANDROID_HOME%/}"
HYG_ANDROID_CACHE_AGE_DAYS="${HYG_ANDROID_CACHE_AGE_DAYS:-7}"
HYG_ANDROID_SDK="${HYG_ANDROID_SDK:-$HOME/Library/Android/sdk}"
HYG_PKG_CACHES="${HYG_PKG_CACHES-$HOME/Library/Caches/CocoaPods}"
HYG_PKG_CACHE_AGE_DAYS="${HYG_PKG_CACHE_AGE_DAYS:-30}"
HYG_LOCK="${HYG_LOCK:-${TMPDIR:-/tmp}/mac-agent-hygiene.lock}"
HYG_DERIVED_DATA="${HYG_DERIVED_DATA%/}"; HYG_PLUGIN_CACHE="${HYG_PLUGIN_CACHE%/}"
case "$HYG_WT_AGE_DAYS$HYG_MODEL_CACHE_AGE_DAYS$HYG_PLUGIN_CLONE_MIN_AGE_MIN$HYG_SESSION_AGE_HOURS$HYG_GRADLE_AGE_DAYS$HYG_DEVICE_SUPPORT_AGE_DAYS$HYG_ANDROID_CACHE_AGE_DAYS$HYG_PKG_CACHE_AGE_DAYS$HYG_GH_SHA_CHECK_MAX$HYG_ARTIFACT_IDLE_HOURS$HYG_ARTIFACT_DEPTH$HYG_PLAN_BUDGET_MIN$HYG_REPORT_AGE_DAYS$HYG_RETENTION_DAYS$HYG_RETENTION_MAX_PER_RUN" in *[!0-9]*) echo "age settings must be integers" >&2; exit 2;; esac
# -mtime -0 matches nothing, so 0 would read every folder as idle and send dirty work after a day.
case "$HYG_RETENTION_DAYS" in ""|[1-9]*) ;; *) echo "HYG_RETENTION_DAYS must be at least 1 (unset = off)" >&2; exit 2;; esac

GIT="${HYG_GIT:-}"
if [ -z "$GIT" ]; then GIT=/usr/bin/git; [ -x "$HOME/.local/bin/git" ] && GIT="$HOME/.local/bin/git"; fi   # honour a user's git shim unless HYG_GIT is explicit
GH="${HYG_GH:-}"
if [ -z "$GH" ]; then
  for c in "$(command -v gh 2>/dev/null)" /opt/homebrew/bin/gh /usr/local/bin/gh; do
    [ -n "$c" ] && [ -x "$c" ] && { GH="$c"; break; }
  done
fi

# Cache subfolders that Chromium regenerates. Fixed in code on purpose — not user-editable.
PW_CACHE_ALLOWLIST=(
  "Default/Cache" "Default/Code Cache" "Default/GPUCache"
  "Default/Service Worker/CacheStorage" "Default/Service Worker/ScriptCache"
  "Default/DawnGraphiteCache" "Default/DawnWebGPUCache"
  "GrShaderCache" "GraphiteDawnCache" "ShaderCache" "GPUPersistentCache"
)

mkdir -p "$(dirname "$HYG_LOG")" 2>/dev/null
DATA_VOL=/; [ -d /System/Volumes/Data ] && DATA_VOL=/System/Volumes/Data   # `/` is the sealed system volume on modern macOS
dfree(){ /bin/df -h "$DATA_VOL" | /usr/bin/tail -1 | /usr/bin/awk '{print $4}'; }
dpct(){ /bin/df -h "$DATA_VOL" | /usr/bin/tail -1 | /usr/bin/awk '{print $5}'; }
log(){ echo "$(/bin/date '+%F %T') $*" >> "$HYG_LOG"; }
kb(){ /usr/bin/du -sk "$1" 2>/dev/null | /usr/bin/cut -f1; }
emit(){ printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }   # category action kb reason path
inuse(){ /usr/sbin/lsof +D "$1" >/dev/null 2>&1; }
path_key(){ printf '%s' "$1" | /usr/bin/shasum | /usr/bin/cut -c1-16; }
# Answers that cost a tree walk are cached per run; apply drops them so its re-check reads the disk again.
# The registry is written by routines and rows freeze when its writer stops. For retention only, a non-terminal
# row counts as alive while its start date (first 10 characters) is within the grace window. No date ⇒ alive.
session_row_is_recent(){ local n rows row dt cutoff; n=$(/usr/bin/basename "$1"); load_alive
  [ "$ALIVE" = "*" ] && return 0
  cutoff=$(/bin/date -v-${GRACE_REGISTRY_DAYS}d +%F)
  rows=$("$JQ" -r '.[] | select(((.status // "") | IN("done","dead","stopped","failed","killed","finished")) | not) | [.session, ((.started_at // "") | tostring | .[0:10])] | @tsv' "$HYG_SESSIONS_JSON" 2>/dev/null) || return 0
  while IFS=$'\t' read -r row dt; do [ -n "$row" ] || continue
    case "$n" in "$row"|"$row"-*) ;; *) case "$row" in "$n"-*) ;; *) continue;; esac;; esac
    case "$dt" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) [ "$dt" \< "$cutoff" ] && continue;; esac
    return 0
  done <<< "$rows"; return 1; }
drop_run_caches(){ /bin/rm -f "$TMPD"/inv-* "$TMPD"/idle-* "$TMPD"/inuse-* "$TMPD"/age-*; CWDS=""; ALIVE=""; ALIVE_LOADED=0; }
inuse_cached(){ local f; f="$TMPD/inuse-$(path_key "$1")"
  [ -f "$f" ] || { if inuse "$1"; then echo 1; else echo 0; fi > "$f"; }; [ "$(/bin/cat "$f")" = 1 ]; }
xcode_building(){ /usr/bin/pgrep -qx xcodebuild || /usr/bin/pgrep -qx Xcode || /usr/bin/pgrep -qx XCBBuildService; }
simulator_running(){ /usr/bin/pgrep -qx Simulator || /usr/bin/pgrep -qf 'CoreSimulator/.*launchd_sim'; }
older_than_days(){ [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mtime +"$2" 2>/dev/null)" ]; }
physical(){ cd -P -- "$1" 2>/dev/null && pwd -P; }   # the real path, symlinks resolved; fails on a path that does not resolve
has_dot_component(){ case "/$1/" in */./*|*/../*) return 0;; esac; return 1; }
# Every process's cwd, read ONCE per run; compared as fixed strings (never as a pattern).
CWDS=""; load_cwds(){ [ -n "$CWDS" ] || CWDS=$(/usr/sbin/lsof -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p'); }
cwd_inside(){ local c; load_cwds
  while IFS= read -r c; do [ -n "$c" ] || continue; [ "$c" = "$1" ] && return 0; case "$c" in "$1"/*) return 0;; esac; done <<< "$CWDS"; return 1; }
JQ="${HYG_JQ:-}"; if [ -z "$JQ" ]; then for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do [ -x "$c" ] && { JQ="$c"; break; }; done; fi
# Sessions the routines registry does not call finished. Read ONCE per run. No registry ⇒ none alive
# (cwd + idle still bind). A registry we cannot read ⇒ the sentinel "*" ⇒ all alive: no jq, bad JSON, a
# truncated (0-byte) file, or any shape other than one array whose entries all carry a string .session.
ALIVE=""; ALIVE_LOADED=0
load_alive(){ [ "$ALIVE_LOADED" = 1 ] && return 0; ALIVE_LOADED=1
  [ -e "$HYG_SESSIONS_JSON" ] || return 0
  [ -n "$JQ" ] && ALIVE=$("$JQ" -rs 'if length == 1 and (.[0] | type) == "array" and (.[0] | all(type == "object" and (.session | type) == "string"))
      then .[0][] | select(((.status // "") | IN("done","dead","stopped","failed","killed","finished")) | not) | .session
      else error("unreadable registry") end' "$HYG_SESSIONS_JSON" 2>/dev/null) || ALIVE="*"; }
session_alive(){ local n s; n=$(/usr/bin/basename "$1"); load_alive
  [ "$ALIVE" = "*" ] && return 0
  while IFS= read -r s; do [ -n "$s" ] || continue
    [ "$n" = "$s" ] && return 0; case "$n" in "$s"-*) return 0;; esac; case "$s" in "$n"-*) return 0;; esac
  done <<< "$ALIVE"; return 1; }
TMPD=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mac-agent-hygiene.XXXXXX") || { echo "mktemp failed" >&2; exit 2; }
trap '/bin/rm -rf "$TMPD"' EXIT

# ---------- scan budget (card iTGD34Ub): a loaded Mac took 72 min; the plan now stops on the clock ----------
PLAN_T0=$SECONDS
# Seconds after PLAN_T0 at which a category stops being scanned; 0 = never. Each slow pass gets a share of what
# is LEFT when it starts, so a slow cache pass ahead of them can never read as "over budget at 0 s".
budget_deadline(){ local b=$((HYG_PLAN_BUDGET_MIN*60)) now=$((SECONDS-PLAN_T0)) left
  [ "$b" -gt 0 ] || { echo 0; return; }; left=$((b-now)); [ "$left" -gt 0 ] || left=0
  case "$1" in worktrees) echo $((now+left/3));; build-artifacts) echo $((now+left/2));; session-dirs) echo "$((now+left))";; *) echo 0;; esac; }
# Where the artifact walks stop. They run ahead of the plan loop, so they use a fixed share of the whole budget.
walk_deadline(){ echo $((HYG_PLAN_BUDGET_MIN*60*2/3)); }
# Longest unscanned first, then oldest: a run the budget cuts short resumes where it stopped.
fair_order(){ local st="$HYG_STATE_DIR/scanned-$1.tsv"; [ -f "$st" ] || st=/dev/null
  /usr/bin/tr '\n' '\0' | /usr/bin/xargs -0 /usr/bin/stat -f '%m%t%N' 2>/dev/null \
    | /usr/bin/awk -F'\t' 'FILENAME!="-"{seen[$1]=$2;next}{print ($2 in seen ? seen[$2] : 0) "\t" $1 "\t" $2}' "$st" - \
    | /usr/bin/sort -t$'\t' -k1,1n -k2,2n | /usr/bin/cut -f3-; }
mark_scanned(){ printf '%s\t%s\n' "$2" "$(/bin/date +%s)" >> "$TMPD/scanned-$1"; }
save_scanned(){ local c f st t; for c in worktrees build-artifacts session-dirs; do f="$TMPD/scanned-$c"; [ -f "$f" ] || continue
    /bin/mkdir -p "$HYG_STATE_DIR" 2>/dev/null; st="$HYG_STATE_DIR/scanned-$c.tsv"; t="$st.$$"
    /usr/bin/awk -F'\t' -v min="$(($(/bin/date +%s)-30*86400))" '{a[$1]=$2} END{for(k in a) if(a[k]>=min) print k "\t" a[k]}' \
      "$( [ -f "$st" ] && echo "$st" || echo /dev/null)" "$f" > "$t" 2>/dev/null && /bin/mv -f "$t" "$st"; done; }
top_folder(){ local rel="${1#"$HYG_SESSION_ROOT"/}"; printf '%s' "$HYG_SESSION_ROOT/${rel%%/*}"; }
# Idle bucket of a ~/code/wt top-level folder: dependency trees and .git do not count as a touch.
age_bucket(){ local t f e=() n; case "$1" in "$HYG_SESSION_ROOT"/*) ;; *) echo -; return;; esac
  t=$(top_folder "$1"); f="$TMPD/age-$(path_key "$t")"
  if [ ! -f "$f" ]; then
    while IFS= read -r n; do e+=( "$n" ); done < <(name_expr .git "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData)
    if [ -n "$(/usr/bin/find "$t" \( "${e[@]}" \) -prune -o -type f -mmin -1440 -print -quit 2>/dev/null)" ]; then echo '<1d' > "$f"
    elif [ -n "$(/usr/bin/find "$t" \( "${e[@]}" \) -prune -o -type f -mtime -"$HYG_REPORT_AGE_DAYS" -print -quit 2>/dev/null)" ]; then echo "1-${HYG_REPORT_AGE_DAYS}d" > "$f"
    else echo ">${HYG_REPORT_AGE_DAYS}d" > "$f"; fi
  fi; /bin/cat "$f"; }

# ---------- enumerators (shared by status, plan and the candidate list) ----------
list_worktrees(){ local pair r g
  for pair in $HYG_WT_ROOTS; do r="${pair%%:*}"; r="${r%/}"; g="${pair#*:}"
    [ -d "$r" ] && /usr/bin/find "$r" -maxdepth 1 -mindepth 1 -type d -name "$g" 2>/dev/null
  done | /usr/bin/sort -u | while IFS= read -r d; do [ -f "$d/.git" ] && printf '%s\n' "$d"; done; }
wt_root_glob_ok(){ local pair r g; for pair in $HYG_WT_ROOTS; do r="${pair%%:*}"; r="${r%/}"; g="${pair#*:}"
    [ "$(dirname "$1")" = "$r" ] || continue; case "$(basename "$1")" in $g) return 0;; esac; done; return 1; }
# Every top-level folder except a linked worktree (.git is a FILE: the worktrees pass owns it). A full
# clone (.git is a DIR) is a session folder too (card JsY0DY3A: 118 of 536 ~/code/wt folders were
# top-level clones that no pass ever evaluated).
list_sessions(){ [ -d "$HYG_SESSION_ROOT" ] && /usr/bin/find "$HYG_SESSION_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | /usr/bin/sort |
  while IFS= read -r d; do [ -f "$d/.git" ] || printf '%s\n' "$d"; done; }
ARTIFACT_NAMES=( node_modules .next dist build .turbo coverage )   # the ONE list: find expressions below are built from it
# -name a -o -name b ... for find, from one or more names.
name_expr(){ local n first=1; for n in "$@"; do [ "$first" = 1 ] || printf '%s\n' -o; first=0; printf '%s\n%s\n' -name "$n"; done; }
# Artifact dirs in every top-level folder (worktrees and clones included); prune at .git and at each hit.
list_artifacts(){ local t e=() dl; while IFS= read -r t; do e+=( "$t" ); done < <(name_expr "${ARTIFACT_NAMES[@]}")
  [ -d "$HYG_SESSION_ROOT" ] || return 0; dl=$(walk_deadline)
  /usr/bin/find "$HYG_SESSION_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | fair_order build-artifacts | while IFS= read -r t; do
    [ "$dl" = 0 ] || [ $((SECONDS-PLAN_T0)) -lt "$dl" ] || break
    session_idle "$t" || continue   # a folder in use has nothing to strip, so it costs no depth-6 walk
    /usr/bin/find "$t" -mindepth 1 -maxdepth "$HYG_ARTIFACT_DEPTH" -name .git -prune -o -type d \( "${e[@]}" \) -prune -print 2>/dev/null | /usr/bin/sort
  done; }
# One walk per folder per run, nothing pruned but .git itself: every .git, and every HEAD outside a .git (a bare
# repo or separate git-dir has no .git, and its HEAD gives it away; old-style repos make it a symlink). A repo
# the search skipped would be rm -rf'd unchecked, so a walk that fails reads as a bare repo, and keeps.
# The marker "<folder>/unreadable/HEAD" is that fail-closed answer. It is printed when find fails, and also when the
# cache cannot be written or read back whole (a full disk, a read-only $TMPD): an empty cache would read "no repo".
# find's stderr is kept beside the cache so walk_failed can name the path it could not read.
repo_inventory(){ local f out; f="$TMPD/inv-$(path_key "$1")"
  if [ ! -f "$f" ]; then
    if out=$( { /usr/bin/find "$1" -name .git -print -prune -o \( -type f -o -type l \) -name HEAD -print 2>"$f.err"; } 2>/dev/null ); then
      { { [ -z "$out" ] || printf '%s\n' "$out"; } > "$f.tmp" && [ "$(/bin/cat "$f.tmp")" = "$out" ] && /bin/mv -f "$f.tmp" "$f"; } 2>/dev/null \
        || { /bin/rm -f "$f.tmp" 2>/dev/null; printf '%s/unreadable/HEAD\n' "$1"; return 0; }
    else
      printf '%s/unreadable/HEAD\n' "$1" > "$f" 2>/dev/null || { printf '%s/unreadable/HEAD\n' "$1"; return 0; }
    fi
  fi
  /bin/cat "$f" 2>/dev/null || printf '%s/unreadable/HEAD\n' "$1"; }
nested_repos(){ repo_inventory "$1" | TOP="$1/.git" /usr/bin/awk '$0!=ENVIRON["TOP"] && /\/\.git$/' | /usr/bin/sed 's#/\.git$##'; }
holds_bare_or_separate_git_dir(){ repo_inventory "$1" | /usr/bin/grep -q '/HEAD$'; }
holds_a_repo(){ repo_inventory "$1" | /usr/bin/grep -q '/\.git$'; }
# The first entry of a kind, relative to the folder: the exact path a keep names as its blocker (AC 1).
first_inventory(){ local h; h=$(repo_inventory "$1" | /usr/bin/grep -m1 "$2"); printf '%s' "${h#"$1"/}"; }
# 0 when the inventory is the fail-closed marker rather than a real HEAD of that name. Sets REASON and BLOCKER:
#   repo-walk-failed            find could not read part of the folder; BLOCKER = the first path it named
#   repo-inventory-cache-failed the cache could not be written or read back; BLOCKER = . (nothing in the folder is at fault)
walk_failed(){ local f p; f="$TMPD/inv-$(path_key "$1")"
  repo_inventory "$1" | /usr/bin/grep -qxF "$1/unreadable/HEAD" || return 1
  [ -e "$1/unreadable/HEAD" ] && return 1
  if [ -f "$f" ] && /bin/cat "$f" >/dev/null 2>&1; then
    REASON=repo-walk-failed
    p=$(/usr/bin/sed -n '1s/^find: \(.*\): [^:]*$/\1/p' "$f.err" 2>/dev/null)
    case "$p" in "$1"/*) BLOCKER="${p#"$1"/}";; *) BLOCKER=.;; esac
  else REASON=repo-inventory-cache-failed; BLOCKER=.; fi
  return 0; }
# Newest-first listing helpers for "never the newest N" rules
newest_first(){ /bin/ls -1td "$@" 2>/dev/null; }
list_clones(){ [ -d "$HYG_PLUGIN_CACHE" ] && /usr/bin/find "$HYG_PLUGIN_CACHE" -maxdepth 1 -mindepth 1 -type d -name 'temp_git_*' 2>/dev/null | /usr/bin/sort; }
list_profiles(){ local p; for p in $HYG_PW_GLOB; do [ -d "$p" ] && printf '%s\n' "$p"; done; }
# Directories a human does not edit — dependency trees, VCS internals, build output. Pruned from the
# recency walk (card ugCwRX0v): a file under node_modules is not a human touch, and walking every idle
# worktree's node_modules is what kept the first scheduled run in plan for >50 min (355 worktrees).
WT_RECENCY_PRUNE=( .git node_modules .venv venv Pods build DerivedData )
wt_recently_touched(){  # any regular file (outside the pruned dirs) newer than the age → touched
  local n expr=()
  for n in "${WT_RECENCY_PRUNE[@]}"; do expr+=( -name "$n" -o ); done
  unset 'expr[${#expr[@]}-1]'
  [ -n "$(/usr/bin/find "$1" \( "${expr[@]}" \) -prune -o -type f -mtime -"$HYG_WT_AGE_DAYS" -print -quit 2>/dev/null)" ] ||
  [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mtime -"$HYG_WT_AGE_DAYS" 2>/dev/null)" ]; }

# ---------- eligibility (the SAME function decides in plan and in apply) ----------
REASON=""
check_derived(){ [ "$(dirname "$1")" = "$HYG_DERIVED_DATA" ] || { REASON=outside-derived-data; return 1; }
  xcode_building && { REASON=xcode-building; return 1; }; REASON=regenerable-build-output; return 0; }
check_clone(){ [ "$(dirname "$1")" = "$HYG_PLUGIN_CACHE" ] || { REASON=outside-plugin-cache; return 1; }
  case "$(basename "$1")" in temp_git_*) ;; *) REASON=not-a-temp-clone; return 1;; esac
  [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mmin +"$HYG_PLUGIN_CLONE_MIN_AGE_MIN" 2>/dev/null)" ] || { REASON=younger-than-24h; return 1; }
  REASON=leftover-install-clone; return 0; }
check_pwcache(){ local p="$1" prof sub ok=1
  while IFS= read -r prof; do
    case "$p" in "$prof"/*) sub="${p#"$prof"/}"
      for a in "${PW_CACHE_ALLOWLIST[@]}"; do [ "$sub" = "$a" ] && ok=0; done
      case "$sub" in BrowserMetrics*) [ "$(dirname "$sub")" = . ] && ok=0;; esac
      [ $ok = 0 ] || { REASON=not-in-cache-allowlist; return 1; }
      [ -L "$prof/SingletonLock" ] && { REASON=profile-has-singleton-lock; return 1; }
      inuse_cached "$prof" && { REASON=profile-in-use; return 1; }
      REASON=regenerable-browser-cache; return 0;; esac
  done < <(list_profiles); REASON=not-inside-a-profile; return 1; }
check_model(){ local m; for m in $HYG_MODEL_CACHES; do
    [ "$1" = "${m%/}" ] || continue
    inuse "$1" && { REASON=in-use; return 1; }
    [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mtime +"$HYG_MODEL_CACHE_AGE_DAYS" 2>/dev/null)" ] || { REASON=used-recently; return 1; }
    REASON=re-downloadable-model-cache; return 0; done
  REASON=not-a-listed-model-cache; return 1; }
check_worktree(){ local d="$1"
  wt_root_glob_ok "$d" || { REASON=outside-worktree-roots; return 1; }
  [ -f "$d/.git" ] || { REASON=not-a-linked-worktree; return 1; }        # a full clone has a .git DIR — left alone
  wt_recently_touched "$d" && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  git_safe "$d" "$d" && return 0
  case "$(/usr/bin/dirname "$d")" in "$HYG_SESSION_ROOT") retention_decides "$d" "$REASON"; return;; esac; return 1; }
# git run on repos an agent made: repo-local config must not be able to run a command while we only
# look (core.fsmonitor and hooks are the command-executing keys `status` would honour). autoRefreshIndex:
# `git diff` otherwise rewrites a stat-dirty index, which is a write, and reads as a touch to retention_idle.
GITS(){ GIT_CONFIG_NOSYSTEM=1 "$GIT" --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null \
  -c core.untrackedCache=false -c diff.external= -c diff.autoRefreshIndex=false -c core.pager=cat -c log.showSignature=false "$@"; }
# Repo-local config keys that can make git run a program (filter drivers run during `status`). A repo
# carrying any of them is KEPT unread: fail closed rather than try to neutralise every driver.
CMD_CONFIG_RE='^(filter\.|include\.|includeif\.|core\.fsmonitor|core\.sshcommand|core\.gitproxy|core\.askpass|core\.editor|core\.pager|core\.hookspath|diff\.[^.]*\.(textconv|command)|merge\.[^.]*\.driver|credential\.|uploadpack\.|protocol\.)'
repo_config_runs_commands(){ local gd f
  gd=$(GITS -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  for f in "$gd/config" "$(GITS -C "$1" rev-parse --path-format=absolute --git-dir 2>/dev/null)/config.worktree"; do
    [ -f "$f" ] || continue
    "$GIT" config --file "$f" --name-only --list 2>/dev/null | /usr/bin/grep -qiE "$CMD_CONFIG_RE" && return 0
  done; return 1; }
# A clone's remote-tracking refs go stale (nobody fetches a finished session), so a local `main` a pull
# moved past origin/main looks unpushed. Ask GitHub instead: the SHA is safe when the repo's default
# branch already contains it (compare SHA...default is "ahead" or "identical"). One gh call per SHA,
# cached across the run; no gh, gh failure, a non-github origin, or over HYG_GH_SHA_CHECK_MAX ⇒ KEEP.
in_github_default(){ local repo="$1" sha="$2" key f n def
  [ "$HYG_WT_MERGED_PR_CHECK" = 1 ] && [ -n "$GH" ] || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] && [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 1
  key=$(echo "$repo" | tr / _); f="$TMPD/gh-sha-$key-$sha"
  if [ ! -f "$f" ]; then
    n=$(/bin/cat "$TMPD/gh-sha-calls" 2>/dev/null || echo 0)
    [ "$n" -lt "$HYG_GH_SHA_CHECK_MAX" ] || return 1
    echo $((n+1)) > "$TMPD/gh-sha-calls"
    [ -f "$TMPD/gh-default-$key" ] || "$GH" api "repos/$repo" --jq '.default_branch' > "$TMPD/gh-default-$key" 2>/dev/null || : > "$TMPD/gh-default-$key"
    def=$(/bin/cat "$TMPD/gh-default-$key")
    [[ "$def" =~ ^[A-Za-z0-9_./-]+$ ]] || { echo 0 > "$f"; return 1; }
    "$GH" api "repos/$repo/compare/$sha...$def" --jq 'if type=="object" and (.status=="ahead" or .status=="identical") then 1 else 0 end' \
      > "$f" 2>/dev/null || echo 0 > "$f"
  fi
  [ "$(/bin/cat "$f")" = 1 ]; }
# Can git's answers about this repo be trusted at all? Shared by git_safe and retention: a failure here
# can never be rescued, because the archive would read the same repo through the same git.
repo_trusted(){ local d="$1" tl rd
  repo_config_runs_commands "$d" && { REASON=repo-config-can-run-commands; return 1; }
  # status only inspects the work tree git resolves. A repo's core.worktree (or a broken .git that sends
  # discovery up to an outer repo) puts that somewhere other than $d: $d's own files are then checked
  # nowhere and go with the rm (PR #80 review B5). KEEP unless it physically IS $d.
  tl=$(GITS -C "$d" rev-parse --show-toplevel 2>/dev/null) || { REASON=worktree-not-this-folder; return 1; }
  rd=$(physical "$d") || { REASON=worktree-not-this-folder; return 1; }
  [ -n "$tl" ] && [ -n "$rd" ] && [ "$(physical "$tl")" = "$rd" ] || { REASON=worktree-not-this-folder; return 1; }
  # status recurses into submodules under THEIR config, which the scan above never read: keep, unread.
  { [ -e "$d/.gitmodules" ] || [ -d "$(GITS -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/modules" ] \
    || [ -d "$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)/modules" ] \
    || GITS -C "$d" ls-files -s 2>/dev/null | /usr/bin/awk '$1=="160000"{f=1} END{exit !f}'; } \
    && { REASON=has-submodules; return 1; }   # gitlinks found by index mode 160000, not only by .gitmodules
  return 0; }
worktrees_inside(){ local d="$1" bound="$2" wtl wp wr rb
    # Linked worktrees keep their HEAD, index and rebase state under $d/.git/worktrees/: the rm takes them
    # even when the worktree folder lives elsewhere. KEEP when any registered worktree is outside the
    # deletion boundary, or cannot be resolved (missing/prunable), or the list cannot be read (B1).
    wtl=$(GITS -C "$d" worktree list --porcelain 2>/dev/null) || { REASON=git-worktree-list-failed; return 1; }
    [ -n "$wtl" ] || { REASON=git-worktree-list-failed; return 1; }
    rb=$(physical "$bound") || { REASON=boundary-unresolvable; return 1; }
    [ -n "$rb" ] || { REASON=boundary-unresolvable; return 1; }
    while IFS= read -r wp; do
      case "$wp" in "worktree "*) wp="${wp#worktree }";; *) continue;; esac
      wr=$(physical "$wp") || wr=""
      case "$wr/" in "$rb"/*) ;; *) REASON=has-linked-worktrees; return 1;; esac
    done <<< "$wtl"
  return 0; }
git_safe(){ # repo/worktree dir, deletion boundary (the dir apply would rm) → 0 clean and on a remote ref or merged-PR head (REASON=pushed|merged-pr-head)
  local d="$1" bound="${2:-$1}" b h repo f st br cdir rc rb wg tl iv rd
  repo_trusted "$d" || return 1
  # --untracked-files=all on the command line overrides a repo's status.showUntrackedFiles=no, which
  # would otherwise make untracked files read clean and go with the rm (PR #80 review B2).
  st=$(GITS -C "$d" -c diff.ignoreSubmodules=all status --porcelain --untracked-files=all --ignore-submodules=all 2>/dev/null) || { REASON=git-status-failed; return 1; }
  [ -z "$st" ] || { REASON=dirty-uncommitted-work; return 1; }
  # status never reports edits to a tracked file flagged assume-unchanged (lowercase tag in `ls-files -v`)
  # or skip-worktree (tag S), so they read clean and go with the rm (B4). Any flagged entry ⇒ KEEP, unread:
  # that includes a sparse checkout, whose out-of-cone entries all carry S.
  iv=$(GITS -C "$d" ls-files -v 2>/dev/null) || { REASON=git-ls-files-failed; return 1; }
  printf '%s\n' "$iv" | LC_ALL=C /usr/bin/grep -q '^[a-zS] ' && { REASON=index-hides-changes; return 1; }
  # owner/name only from an anchored github.com URL; anything else ⇒ empty ⇒ no gh call ⇒ KEEP
  repo=$(GITS -C "$d" remote get-url origin 2>/dev/null | /usr/bin/sed -nE 's#^(https://|ssh://git@|git@)github\.com[:/]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$#\2#p' | /usr/bin/sed -E 's#\.git$##')
  case "$repo" in *..*|.*|*/.*) repo="";; esac
  if [ -d "$d/.git" ]; then   # a full clone owns its stash, every local ref and its linked worktrees' git data
    [ -z "$(GITS -C "$d" stash list 2>/dev/null)" ] || { REASON=clone-has-stash; return 1; }
    worktrees_inside "$d" "$bound" || return 1
    # Every local ref, not only branches: a commit held only by a tag (or notes, replace, bisect, ...)
    # is lost with the clone (B3). Remote-tracking refs are the yardstick, not candidates. A tag is
    # peeled to its commit; a ref that is not a commit fails --contains ⇒ KEEP.
    local refs rn o pe kind
    refs=$(GITS -C "$d" for-each-ref --format='%(refname)%09%(objectname)%09%(*objectname)' 2>/dev/null) \
      || { REASON=git-for-each-ref-failed; return 1; }
    while IFS=$'\t' read -r rn o pe; do [ -n "$rn" ] || continue
      case "$rn" in refs/remotes/*) continue;; refs/heads/*) kind=branch;; refs/tags/*) kind=tag;; *) kind=ref;; esac
      br="${pe:-$o}"
      [ -n "$(GITS -C "$d" branch -r --contains "$br" 2>/dev/null | /usr/bin/head -1)" ] || in_github_default "$repo" "$br" \
        || { REASON=has-unpushed-$kind; return 1; }
    done <<< "$refs"
  fi
  h=$(GITS -C "$d" rev-parse HEAD 2>/dev/null) || { REASON=no-head; return 1; }
  if [ -n "$(GITS -C "$d" branch -r --contains "$h" 2>/dev/null | /usr/bin/head -1)" ]; then REASON=pushed; return 0; fi
  in_github_default "$repo" "$h" && { REASON=in-github-default-branch; return 0; }
  # A clean linked worktree whose HEAD a local branch holds loses nothing: removing the worktree leaves
  # that branch (and its unpushed commits) in the parent repo — provided the parent survives the removal.
  # So: the parent's real path lies outside the deletion boundary (the whole session folder for a
  # session-dir; a bare parent there is not found by nested_repos), and the parent really registers
  # this dir as one of its worktrees ($cdir/worktrees/<name>/gitdir points back at $d/.git).
  if [ -f "$d/.git" ]; then
    cdir=$(GITS -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    rc=$(physical "$cdir"); rb=$(physical "$bound")
    wg=$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    if [ -n "$rc" ] && [ -n "$rb" ] && case "$rc/" in "$rb"/*) false;; *) true;; esac \
       && case "$wg" in "$cdir"/worktrees/*) true;; *) false;; esac \
       && [ "$(physical "$(/usr/bin/dirname "$(/bin/cat "$wg/gitdir" 2>/dev/null)")")" = "$(physical "$d")" ] \
       && [ -n "$(GITS -C "$d" for-each-ref --contains "$h" --format=x refs/heads 2>/dev/null | /usr/bin/head -1)" ]; then
      REASON=branch-kept-in-parent-repo; return 0; fi
  fi
  if [ "$HYG_WT_MERGED_PR_CHECK" = 1 ] && [ -n "$GH" ]; then
    b=$(GITS -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$repo" ]; then
      f="$TMPD/$(echo "$repo" | tr / _)"
      [ -f "$f" ] || "$GH" pr list --repo "$repo" --state merged --limit 3000 --json headRefName,headRefOid \
          --jq '.[] | "\(.headRefName) \(.headRefOid)"' > "$f" 2>/dev/null || : > "$f"   # gh failure ⇒ empty ⇒ KEEP
      /usr/bin/grep -qxF "$b $h" "$f" && { REASON=merged-pr-head; return 0; }
    fi
  fi
  REASON=unpushed-commits; return 1; }

# The registry answer for a ~/code/wt top-level folder, shared by check_session and retention_decides (B3, review
# 5748468367: the worktrees path reached retention without it). 0 = the registry keeps it (REASON set). FROZEN=1 when
# a row names it but, with retention on, the row is older than the grace window: only retention may then act.
FROZEN=0
registry_keeps(){ FROZEN=0; session_alive "$1" || return 1
  if retention_on && ! session_row_is_recent "$1"; then FROZEN=1; return 1; fi
  REASON=session-alive-in-registry; BLOCKER=.; return 0; }
check_session(){ local d="$1" r failed="" fblock="" frozen=0
  [ "$(dirname "$d")" = "$HYG_SESSION_ROOT" ] || { REASON=outside-session-root; return 1; }
  [ -L "$d" ] && { REASON=is-a-symlink; return 1; }
  [ -f "$d/.git" ] && { REASON=linked-worktree-see-worktrees-pass; return 1; }
  [ -e "$d/.git" ] && [ ! -d "$d/.git" ] && { REASON=odd-git-entry; return 1; }
  registry_keeps "$d" && return 1; frozen=$FROZEN
  [ -n "$(/usr/bin/find "$d" \( -name .git -o -name node_modules -o -name .venv -o -name Pods \) -prune -o -type f -mmin -"$((HYG_SESSION_AGE_HOURS*60))" -print -quit 2>/dev/null)" ] && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  # A walk that failed keeps the folder under its own reason, naming the path it could not read.
  walk_failed "$d" && return 1
  # A bare repo or separate git-dir elsewhere in the folder would go with the rm unchecked: keep, unread.
  holds_bare_or_separate_git_dir "$d" && { REASON=contains-bare-or-separate-git-dir; BLOCKER=$(first_inventory "$d" '/HEAD$'); return 1; }
  if [ -d "$d/.git" ]; then git_safe "$d" "$d" || { failed="clone-$REASON"; fblock=.; }; fi   # the folder IS a clone
  if [ -z "$failed" ]; then while IFS= read -r r; do [ -n "$r" ] || continue
    git_safe "$r" "$d" || { failed="nested-$REASON"; fblock="${r#"$d"/}"; break; }
  done < <(nested_repos "$d"); fi
  if [ -z "$failed" ] && [ "$frozen" = 0 ]; then REASON=stale-session-all-nested-pushed; return 0; fi
  [ "$frozen" = 1 ] && [ -z "$failed" ] && failed=session-alive-in-registry
  retention_decides "$d" "$failed" && return 0
  [ -n "$BLOCKER" ] || BLOCKER="$fblock"; return 1; }

# ---------- retention (card iTGD34Ub, CTO ruling 6ae7919566f264486f337e8e) ----------
retention_on(){ [ -n "$HYG_RETENTION_DAYS" ] && [ -n "$HYG_RESCUE_CMD" ] && [ -x "$HYG_RESCUE_CMD" ] && [ -n "$JQ" ]; }
# The repo folders inside a top-level folder, itself included when it is one.
repos_in(){ { [ -e "$1/.git" ] && printf '%s\n' "$1"; } ; nested_repos "$1"; }
# Idle = no working file AND no repo metadata touched for the window: the walks above prune .git, so a session
# that only commits would otherwise look idle.
retention_idle(){ local d="$1" r gd f e=() n
  while IFS= read -r n; do e+=( "$n" ); done < <(name_expr .git "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData)
  [ -z "$(/usr/bin/find "$d" \( "${e[@]}" \) -prune -o -type f -mtime -"$HYG_RETENTION_DAYS" -print -quit 2>/dev/null)" ] || return 1
  while IFS= read -r r; do [ -n "$r" ] || continue
    gd=$(GITS -C "$r" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 1
    for f in "$gd/index" "$gd/HEAD" "$gd/logs/HEAD"; do
      [ -e "$f" ] && [ -n "$(/usr/bin/find "$f" -maxdepth 0 -mtime -"$HYG_RETENTION_DAYS" 2>/dev/null)" ] && return 1
    done
  done < <(repos_in "$d"); return 0; }
# Called when a folder failed the plain test. 0 = it may go once rescued (RESCUE_NEEDED=1, REASON says why);
# 1 = keep, with REASON and BLOCKER naming what stops it.
RESCUE_NEEDED=0
# Every folder-level guard lives HERE, so each caller (check_session, check_worktree) gets all of them (B3, B4).
retention_decides(){ local d="$1" why="$2" r
  REASON="$why"
  retention_on || return 1
  case "$why" in
    *dirty-uncommitted-work|*index-hides-changes|*has-stash|*has-unpushed-*|*unpushed-commits|session-alive-in-registry) ;;
    *) return 1;; esac
  [ "$(/usr/bin/dirname "$d")" = "$HYG_SESSION_ROOT" ] || { REASON=retention-blocked-outside-session-root; BLOCKER=.; return 1; }
  [ -L "$d" ] && { REASON=retention-blocked-is-a-symlink; BLOCKER=.; return 1; }
  if [ -L "$d/.git" ] || { [ -e "$d/.git" ] && [ ! -d "$d/.git" ] && [ ! -f "$d/.git" ]; }; then REASON=retention-blocked-odd-git-entry; BLOCKER=.git; return 1; fi
  # B3: a live session keeps, whichever pass found it. A frozen row (older than the grace) lets retention act.
  registry_keeps "$d" && { REASON="retention-blocked-$REASON"; return 1; }
  # B4: a bare repo or separate git-dir is plain untracked files to the archive (objects over the file cap drop):
  # keep, unread. A walk that failed reads the same way.
  walk_failed "$d" && { REASON="retention-blocked-$REASON"; return 1; }
  holds_bare_or_separate_git_dir "$d" && { REASON=retention-blocked-contains-bare-or-separate-git-dir; BLOCKER=$(first_inventory "$d" '/HEAD$'); return 1; }
  REASON="$why"
  retention_idle "$d" || return 1
  while IFS= read -r r; do [ -n "$r" ] || continue
    repo_trusted "$r" || { REASON="retention-blocked-$REASON"; BLOCKER="${r#"$d"}"; BLOCKER="${BLOCKER#/}"; return 1; }
    if [ -d "$r/.git" ]; then worktrees_inside "$r" "$d" || { REASON="retention-blocked-$REASON"; BLOCKER="${r#"$d"}"; BLOCKER="${BLOCKER#/}"; return 1; }; fi
  done < <(repos_in "$d")
  RESCUE_NEEDED=1; REASON="retention-rescue-$why"; return 0; }

name_denied(){ local b p; b=$(/usr/bin/basename "$1" | /usr/bin/tr '[:upper:]' '[:lower:]'); for p in "${RESCUE_DENY[@]}"; do case "$b" in $p) return 0;; esac; done; return 1; }
under_artifact_dir(){ local n; for n in "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData; do case "/$1/" in */"$n"/*) return 0;; esac; done; return 1; }
# One manifest line. A failed append (a full disk) fails the rescue: a silent gap is a lost file (B2).
man(){ printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$RESCUE_OUT/manifest.tsv" || { REASON=rescue-manifest-write-failed; return 1; }; }
sha_of(){ /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d' ' -f1; }
# Queue one working file for the tar. 1 = fail closed (REASON, BLOCKER set). Name-denied, symlinks, special files and
# over-cap files are listed, never copied. A listed path that is not on disk means we misread a list: keep (B1).
rescue_queue(){ local base="$1" rel="$2" f="$1/$2" sz
  case "$rel" in *$'\n'*|*$'\t'*) REASON=rescue-path-unrepresentable; BLOCKER="$rel"; return 1;; esac   # the manifest is TSV
  if [ -L "$f" ]; then man symlink-not-archived "$rel" "$(/usr/bin/readlink "$f")"; return; fi
  [ -e "$f" ] || { REASON=rescue-path-unresolved; BLOCKER="$rel"; return 1; }
  # A symlinked parent puts the file outside the folder: the rm never reaches it, so it is listed, not archived.
  case "$(physical "$(/usr/bin/dirname "$f")")/" in "$(physical "$base")"/*) ;; *) man outside-folder-not-archived "$rel"; return;; esac
  if [ -d "$f" ]; then [ -e "$f/.git" ] && return 0; REASON=rescue-path-unresolved; BLOCKER="$rel"; return 1; fi   # a nested repo is archived as a repo
  [ -f "$f" ] || { man special-file-not-archived "$rel"; return; }
  name_denied "$f" && { man denied-by-name "$rel"; return; }
  under_artifact_dir "$rel" && { man dropped-artifact "$rel"; return; }
  sz=$(/usr/bin/stat -f %z "$f" 2>/dev/null) || { REASON=rescue-stat-failed; BLOCKER="$rel"; return 1; }
  [ "$sz" -le "$RESCUE_FILE_MAX_BYTES" ] || { man dropped-over-file-cap "$rel" "$sz $(sha_of "$f")"; return; }
  printf '%s\t%s\n' "$sz" "$rel" >> "$RESCUE_OUT/queue.tsv" || { REASON=rescue-queue-write-failed; return 1; }; }
# A git list into a file, its exit read (a list read through a pipe loses both the status and the loop's failures).
git_list(){ local out="$1"; shift; GITS "$@" > "$out" 2>/dev/null || { REASON=rescue-git-list-failed; return 1; }; }
# The temporary stash refs go whatever happens: left behind they read as has-unpushed-ref and keep the folder forever.
drop_rescue_refs(){ local ref; GITS -C "$1" for-each-ref --format='%(refname)' refs/hygiene-rescue/ 2>/dev/null |
  while IFS= read -r ref; do GITS -C "$1" update-ref -d "$ref" >/dev/null 2>&1; done; }
# One repo: patches of everything except deletions (listed instead), bundle of what no remote holds. 1 = fail closed.
# Every list is NUL-separated (B1: with core.quotePath a Hebrew or quoted name arrived as "\327..." and was skipped).
rescue_repo(){ local d="$1" r="$2" rel="$3" n="$4" dir="$RESCUE_OUT/payload/repo-$4" pre st url f e i L="$RESCUE_OUT/list"
  pre="${rel}${rel:+/}"; REASON=rescue-repo-read-failed
  /bin/mkdir -p "$dir" || return 1
  url=$(GITS -C "$r" remote get-url origin 2>/dev/null | /usr/bin/sed -E 's#^(https?://)[^/@]*@#\1#')
  man repo "${rel:-.}" "repo-$n ${url:-no-remote} $(GITS -C "$r" rev-parse HEAD 2>/dev/null)" || return 1
  st=$(GITS -C "$r" status --porcelain --untracked-files=no --ignore-submodules=all) || return 1
  # S1: a denied name among the changed tracked paths would leave inside a patch: keep the folder. Read from status, which
  # compares content: `diff --name-only` without an index refresh also names every file whose stat alone changed.
  git_list "$L" -C "$r" status --porcelain -z --untracked-files=no --ignore-submodules=all || return 1
  while IFS= read -r -d '' e; do f="${e:3}"; i=""
    case "$e" in [RC]*) IFS= read -r -d '' i;; esac   # a rename or copy carries its source as the next entry
    case "$e" in " D"*|"D "*) continue;; esac           # a deletion carries no content
    for f in "$f" ${i:+"$i"}; do name_denied "$f" && { REASON=rescue-denied-name-in-patch; BLOCKER="$pre$f"; return 1; }; done
  done < "$L"
  REASON=rescue-repo-read-failed
  GITS -C "$r" diff --no-ext-diff --no-textconv --binary --diff-filter=d HEAD > "$dir/changes.patch" || return 1
  # diff HEAD carries only the working copy of a file edited again after `git add` (MM): keep the staged side too.
  GITS -C "$r" diff --cached --no-ext-diff --no-textconv --binary --diff-filter=d > "$dir/staged.patch" || return 1
  if printf '%s\n' "$st" | /usr/bin/grep -qE '^( M|M |MM|A |AM|R |RM|C |T | T)' && [ ! -s "$dir/changes.patch" ]; then return 1; fi
  man archived "repo-$n/changes.patch" "$(sha_of "$dir/changes.patch")" && man archived "repo-$n/staged.patch" "$(sha_of "$dir/staged.patch")" || return 1
  git_list "$L" -C "$r" diff --no-ext-diff --name-only -z --diff-filter=D HEAD || return 1
  while IFS= read -r -d '' f; do man deleted-in-worktree "$pre$f" || return 1; done < "$L"
  git_list "$L" -C "$r" ls-files -z -o --exclude-standard || return 1
  while IFS= read -r -d '' f; do rescue_queue "$d" "$pre$f" || return 1; done < "$L"
  git_list "$L" -C "$r" ls-files -z -v || return 1   # assume-unchanged (lower-case tag) and skip-worktree (S) hide edits from diff
  while IFS= read -r -d '' e; do case "$e" in [hsmrck]" "*|"S "*) rescue_queue "$d" "$pre${e#??}" || return 1;; esac; done < "$L"
  git_list "$L" -C "$r" ls-files -z -o -i --exclude-standard --directory || return 1
  i=0; while [ "$i" -lt 200 ] && IFS= read -r -d '' f; do i=$((i+1)); man ignored-not-archived "$pre$f" || return 1; done < "$L"
  drop_rescue_refs "$r"; rescue_bundle "$d" "$r" "$rel" "$n" "$dir"; i=$?; drop_rescue_refs "$r"; return "$i"; }
rescue_bundle(){ local d="$1" r="$2" rel="$3" n="$4" dir="$5" pre cd cdk h i bcount f revs L="$RESCUE_OUT/list"
  pre="${rel}${rel:+/}"; REASON=rescue-repo-read-failed
  cd=$(GITS -C "$r" rev-parse --path-format=absolute --git-common-dir) || return 1
  cdk=$(path_key "$cd"); [ -e "$RESCUE_OUT/seen-$cdk" ] && return 0; : > "$RESCUE_OUT/seen-$cdk" || return 1
  if case "$(physical "$cd")/" in "$(physical "$d")"/*) true;; *) false;; esac; then
    # F4: stash entries past the tip are invisible to a bundle: give each its own ref, for the bundle only
    git_list "$L" -C "$r" stash list --format=%H || return 1
    i=0; while IFS= read -r h; do [ -n "$h" ] || continue; GITS -C "$r" update-ref "refs/hygiene-rescue/stash-$i" "$h" >/dev/null 2>&1; i=$((i+1)); done < "$L"
    # B5: a failed update-ref leaves that stash out of the bundle and `bundle verify` still passes: count them.
    [ "$(GITS -C "$r" for-each-ref --format=x refs/hygiene-rescue/ 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')" = "$i" ] \
      || { REASON=rescue-stash-refs-failed; BLOCKER="${rel:-.}"; return 1; }
    revs=( --all --not --remotes )
  else   # the parent repo survives outside the folder and keeps every branch: only an otherwise unheld HEAD is at stake
    [ -z "$(GITS -C "$r" for-each-ref --contains HEAD --format=x refs/heads refs/remotes 2>/dev/null | /usr/bin/head -1)" ] || return 0
    revs=( HEAD --not --remotes )
  fi
  # S1: a denied name among the objects the bundle would carry keeps the folder. rev-list --objects is what the bundle
  # packs, and no repo config can narrow it (a `log` scan skips a root commit's files under log.showRoot=false).
  git_list "$L" -C "$r" rev-list --objects "${revs[@]}" || return 1
  while IFS= read -r e; do case "$e" in *" "*) f="${e#* }";; *[!0-9a-f]*) f="$e";; *) continue;; esac; [ -n "$f" ] || continue   # a bare non-hex line is the tail of a name holding a newline
    name_denied "$f" && { REASON=rescue-denied-name-in-commits; BLOCKER="$pre$f"; return 1; }; done < "$L"
  REASON=rescue-repo-read-failed
  bcount=$(GITS -C "$r" rev-list --count "${revs[@]}") || return 1
  [ "$bcount" -gt 0 ] || return 0
  GITS -C "$r" bundle create "$dir/local.bundle" "${revs[@]}" >/dev/null 2>&1 || return 1
  GITS -C "$r" bundle verify "$dir/local.bundle" >/dev/null 2>&1 || return 1
  man archived "repo-$n/local.bundle" "$(sha_of "$dir/local.bundle")"; }
payload_bytes(){ /usr/bin/du -sk "$RESCUE_OUT/payload" 2>/dev/null | /usr/bin/awk '{print $1*1024}'; }
# Build, split and hand to HYG_RESCUE_CMD. 0 only when every queued file is in the archive (or listed as dropped), the
# parts decode to the archive's sha256, and HYG_RESCUE_CMD verified the upload. REASON (and BLOCKER) name a failure.
rescue_build(){ local d="$1" r rel n=0 f sz total sha prefix q=0 e=() a=() R=()
  BLOCKER=""
  [ -n "${RESCUE_ROOT:-}" ] || { RESCUE_ROOT="$TMPD/rescue"; /bin/mkdir -p "$RESCUE_ROOT"; }
  RESCUE_OUT="$RESCUE_ROOT/$(path_key "$d")"; /bin/rm -rf "$RESCUE_OUT"; /bin/mkdir -p "$RESCUE_OUT/payload/files" "$RESCUE_OUT/out" || { REASON=rescue-tmp-failed; return 1; }
  { : > "$RESCUE_OUT/manifest.tsv" && : > "$RESCUE_OUT/queue.tsv" && repos_in "$d" > "$RESCUE_OUT/repos"; } 2>/dev/null || { REASON=rescue-tmp-failed; return 1; }
  while IFS= read -r r; do [ -n "$r" ] && R+=( "$r" ); done < "$RESCUE_OUT/repos"
  for r in ${R[@]+"${R[@]}"}; do n=$((n+1)); rel="${r#"$d"}"; rel="${rel#/}"
    rescue_repo "$d" "$r" "$rel" "$n" || { [ -n "$BLOCKER" ] || BLOCKER="${rel:-.}"; return 1; }
  done
  # loose files, outside every repo; artifact dirs there are listed, not archived
  while IFS= read -r f; do e+=( "$f" ); done < <(name_expr .git "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData)
  while IFS= read -r f; do a+=( "$f" ); done < <(name_expr "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData)
  /usr/bin/find "$d" \( "${e[@]}" \) -prune -o ! -type d -print0 > "$RESCUE_OUT/loose" 2>/dev/null \
    && /usr/bin/find "$d" -name .git -prune -o -type d \( "${a[@]}" \) -prune -print0 > "$RESCUE_OUT/loose-art" 2>/dev/null \
    || { REASON=rescue-walk-failed; BLOCKER=.; return 1; }
  while IFS= read -r -d '' f; do
    for r in ${R[@]+"${R[@]}"}; do case "$f" in "$r"/*) continue 2;; esac; done
    rescue_queue "$d" "${f#"$d"/}" || return 1
  done < "$RESCUE_OUT/loose"
  while IFS= read -r -d '' f; do
    for r in ${R[@]+"${R[@]}"}; do case "$f" in "$r"/*) continue 2;; esac; done
    man dropped-artifact "${f#"$d"/}/" || return 1
  done < "$RESCUE_OUT/loose-art"
  total=$(payload_bytes); [ -n "$total" ] && [ "$total" -le "$RESCUE_MAX_BYTES" ] || { REASON=rescue-commits-and-patches-over-cap; return 1; }
  # smallest first; what does not fit is dropped and listed, and the commits and patches are never dropped
  /usr/bin/sort -t$'\t' -k1,1n "$RESCUE_OUT/queue.tsv" > "$RESCUE_OUT/queue.sorted" || { REASON=rescue-tmp-failed; return 1; }
  while IFS=$'\t' read -r sz rel; do [ -n "$rel" ] || continue
    if [ $((total + sz)) -gt "$RESCUE_MAX_BYTES" ]; then man dropped-over-archive-cap "$rel" "$sz $(sha_of "$d/$rel")" || return 1; continue; fi
    # B2: a copy that fails (unreadable file, full disk) keeps the folder instead of losing the file.
    { /bin/mkdir -p "$RESCUE_OUT/payload/files/$(/usr/bin/dirname "$rel")" && /bin/cp -p "$d/$rel" "$RESCUE_OUT/payload/files/$rel"; } 2>/dev/null \
      || { REASON=rescue-copy-failed; BLOCKER="$rel"; return 1; }
    [ "$(/usr/bin/stat -f %z "$RESCUE_OUT/payload/files/$rel" 2>/dev/null)" = "$sz" ] || { REASON=rescue-copy-size-changed; BLOCKER="$rel"; return 1; }
    man archived "files/$rel" "$(sha_of "$RESCUE_OUT/payload/files/$rel")" || return 1
    total=$((total + sz))
  done < "$RESCUE_OUT/queue.sorted"
  # B2: every queued file is archived or listed as dropped, read back from the manifest rather than trusted from the loop.
  q=$(/usr/bin/awk -F'\t' 'FILENAME==ARGV[1]{ if($1=="archived" && substr($2,1,6)=="files/") ok[substr($2,7)]=1; if($1=="dropped-over-archive-cap") ok[$2]=1; next }
      !($2 in ok){ m++ } END{ print m+0 }' "$RESCUE_OUT/manifest.tsv" "$RESCUE_OUT/queue.tsv") || q=x
  [ "$q" = 0 ] || { REASON=rescue-queue-not-in-archive; return 1; }
  /usr/bin/tar -czf "$RESCUE_OUT/archive.tgz" -C "$RESCUE_OUT/payload" . 2>/dev/null || { REASON=rescue-tar-failed; return 1; }
  sha=$(sha_of "$RESCUE_OUT/archive.tgz"); [ -n "$sha" ] || { REASON=rescue-tar-failed; return 1; }
  /usr/bin/base64 -i "$RESCUE_OUT/archive.tgz" -o "$RESCUE_OUT/archive.b64" || { REASON=rescue-base64-failed; return 1; }
  ( cd "$RESCUE_OUT/out" && /usr/bin/split -b "$RESCUE_PART_BYTES" -a 4 "$RESCUE_OUT/archive.b64" part- ) || { REASON=rescue-split-failed; return 1; }
  for f in "$RESCUE_OUT"/out/part-*; do /bin/mv "$f" "$f.b64" || { REASON=rescue-split-failed; return 1; }; done
  [ "$(/bin/ls "$RESCUE_OUT/out" | /usr/bin/wc -l | /usr/bin/tr -d ' ')" -le "$RESCUE_MAX_PARTS" ] || { REASON=rescue-too-many-parts; return 1; }
  # B2: the parts the uploader receives must decode to exactly the archive built above.
  [ "$(/bin/cat "$RESCUE_OUT"/out/part-*.b64 | /usr/bin/base64 -D 2>/dev/null | /usr/bin/shasum -a 256 | /usr/bin/cut -d' ' -f1)" = "$sha" ] \
    || { REASON=rescue-parts-do-not-match-archive; return 1; }
  "$JQ" -Rs --arg folder "$(/usr/bin/basename "$d")" --arg sha "$sha" \
    --arg at "$(/bin/date -u +%FT%TZ)" --arg host "$(/bin/hostname -s)" \
    '{folder:$folder, host:$host, archived_at:$at, archive_sha256:$sha, format:"base64 of a .tgz, cat part-*.b64 in order", entries:(split("\n") | map(select(length>0) | split("\t") | {kind:.[0], path:.[1], detail:.[2]}))}' \
    "$RESCUE_OUT/manifest.tsv" > "$RESCUE_OUT/out/manifest.json" || { REASON=rescue-manifest-failed; return 1; }
  prefix="$(/bin/hostname -s)/$(/bin/date +%F)/$(/usr/bin/basename "$d")"
  "$HYG_RESCUE_CMD" "$RESCUE_OUT/out" "$prefix" >>"$HYG_LOG" 2>&1 || { REASON=rescue-upload-unverified; return 1; }
  # The archive ledger: written once the upload is verified, before the final re-check (a refused rm still has its archive).
  /bin/mkdir -p "$HYG_STATE_DIR" && printf '%s\t%s\t%s\t%s\n' "$(/bin/date -u +%FT%TZ)" "$d" "$prefix" "$sha" >> "$HYG_STATE_DIR/archived.tsv" \
    || { REASON=rescue-ledger-failed; return 1; }
  /bin/rm -rf "$RESCUE_OUT"; return 0; }
# Session folder idle: no file (outside .git and the artifact dirs themselves) newer than the window.
# Cached per folder for the run.
session_idle(){ local t="$1" f n e=(); f="$TMPD/idle-$(path_key "$t")"
  if [ ! -f "$f" ]; then
    while IFS= read -r n; do e+=( "$n" ); done < <(name_expr .git "${ARTIFACT_NAMES[@]}" .venv Pods)
    if [ -n "$(/usr/bin/find "$t" \( "${e[@]}" \) -prune -o -type f -mmin -"$((HYG_ARTIFACT_IDLE_HOURS*60))" -print -quit 2>/dev/null)" ]
    then echo 0 > "$f"; else echo 1 > "$f"; fi
  fi; [ "$(/bin/cat "$f")" = 1 ]; }
check_artifact(){ local p="$1" rel top name parent tracked tl
  case "$p" in "$HYG_SESSION_ROOT"/*/*) ;; *) REASON=outside-session-root; return 1;; esac
  has_dot_component "$p" && { REASON=dot-path; return 1; }
  rel="${p#"$HYG_SESSION_ROOT"/}"; top="$HYG_SESSION_ROOT/${rel%%/*}"; name=$(/usr/bin/basename "$p"); parent=$(/usr/bin/dirname "$p")
  case " ${ARTIFACT_NAMES[*]} " in *" $name "*) ;; *) REASON=not-an-artifact-name; return 1;; esac
  [ -d "$p" ] || { REASON=gone; return 1; }
  [ -L "$p" ] && { REASON=is-a-symlink; return 1; }
  case "/$rel/" in */.git/*) REASON=inside-git-dir; return 1;; esac
  # resolved path must stay inside the session folder (no symlinked parent leading elsewhere)
  case "$(physical "$p")/" in "$(physical "$top")"/*) ;; *) REASON=resolves-outside-session; return 1;; esac
  session_alive "$top" && { REASON=session-alive-in-registry; return 1; }
  cwd_inside "$top" && { REASON=a-process-is-inside; return 1; }
  session_idle "$top" || { REASON=session-touched-recently; return 1; }
  walk_failed "$p" && return 1
  holds_a_repo "$p" && { REASON=contains-a-repo; BLOCKER=$(first_inventory "$p" '/\.git$'); return 1; }
  holds_bare_or_separate_git_dir "$p" && { REASON=contains-bare-or-separate-git-dir; BLOCKER=$(first_inventory "$p" '/HEAD$'); return 1; }   # B6: the only copy of a commit can sit here
  if GITS -C "$parent" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_config_runs_commands "$parent" && { REASON=repo-config-can-run-commands; return 1; }
    # With core.worktree elsewhere, the two answers below describe that other tree, not this dir (B5).
    tl=$(GITS -C "$parent" rev-parse --show-toplevel 2>/dev/null) && [ -n "$tl" ] || { REASON=worktree-not-this-folder; return 1; }
    tl=$(physical "$tl") && [ -n "$tl" ] || { REASON=worktree-not-this-folder; return 1; }
    case "$(physical "$parent")/" in "$tl"/*) ;; *) REASON=worktree-not-this-folder; return 1;; esac
    tracked=$(GITS -C "$parent" ls-files -- "$name" 2>/dev/null | /usr/bin/head -1) || { REASON=git-ls-files-failed; return 1; }
    [ -z "$tracked" ] || { REASON=has-tracked-files; return 1; }
    GITS -C "$parent" check-ignore -q -- "$name/" 2>/dev/null || { REASON=not-gitignored; return 1; }
    REASON=gitignored-build-output; return 0
  fi
  case "$name" in node_modules|.next|.turbo) [ -f "$parent/package.json" ] && { REASON=node-artifact-beside-package-json; return 0; };; esac
  REASON=not-provably-regenerable; return 1; }
check_gradle(){ local p="$1" parent n
  parent="$(dirname "$p")"
  case "$parent" in "$HYG_GRADLE_HOME/wrapper/dists"|"$HYG_GRADLE_HOME/daemon") ;; *) REASON=outside-gradle-home; return 1;; esac
  n="$(basename "$p")"
  newest_first "$parent"/*/ | /usr/bin/head -2 | /usr/bin/grep -qxF "$p/" && { REASON=one-of-newest-two; return 1; }
  older_than_days "$p" "$HYG_GRADLE_AGE_DAYS" || { REASON=used-recently; return 1; }
  /bin/ps -axo command= 2>/dev/null | /usr/bin/grep -v grep | /usr/bin/grep -qF "$n" && { REASON=gradle-running-this-version; return 1; }
  REASON=old-gradle-version-redownloadable; return 0; }
sim_unavailable_udids(){ /usr/bin/xcrun simctl list devices unavailable 2>/dev/null | /usr/bin/sed -nE 's/.*\(([0-9A-F-]{36})\).*\(unavailable.*/\1/p'; }
check_ios(){ local p="$1"
  xcode_building && { REASON=xcode-running; return 1; }
  case "$(dirname "$p")" in
    "$HYG_DEVICE_SUPPORT")
      [ "$(newest_first "$HYG_DEVICE_SUPPORT"/*/ | /usr/bin/head -1)" = "$p/" ] && { REASON=newest-device-support; return 1; }
      older_than_days "$p" "$HYG_DEVICE_SUPPORT_AGE_DAYS" || { REASON=used-recently; return 1; }
      REASON=old-device-support-recopied-on-connect; return 0;;
    "$HYG_SIM_DEVICES")
      simulator_running && { REASON=simulator-running; return 1; }
      sim_unavailable_udids | /usr/bin/grep -qxF "$(basename "$p")" || { REASON=simulator-runtime-still-installed; return 1; }
      REASON=simulator-runtime-gone; return 0;;
  esac; REASON=outside-ios-dirs; return 1; }
check_android(){ local p="$1"
  [ "$(dirname "$p")" = "$HYG_ANDROID_HOME/cache" ] || { REASON=outside-android-cache; return 1; }
  older_than_days "$p" "$HYG_ANDROID_CACHE_AGE_DAYS" || { REASON=used-recently; return 1; }
  REASON=regenerable-android-cache; return 0; }
check_pkg(){ local m; for m in $HYG_PKG_CACHES; do
    [ "$1" = "${m%/}" ] || continue
    [ -n "$(/usr/bin/find "$1" -type f -mtime -"$HYG_PKG_CACHE_AGE_DAYS" -print -quit 2>/dev/null)" ] && { REASON=used-recently; return 1; }
    REASON=refetchable-package-cache; return 0; done
  REASON=not-a-listed-package-cache; return 1; }

check_item(){ # category path → 0 removable (REASON=why) / 1 keep (REASON=why, BLOCKER=the path that decided it, . = the folder)
  BLOCKER=""; RESCUE_NEEDED=0; check_item_inner "$1" "$2" && return 0
  [ -n "$BLOCKER" ] || BLOCKER=.; return 1; }
check_item_inner(){
  case "$2" in "$HOME"/*) ;; *) REASON=outside-home; return 1;; esac
  has_dot_component "$2" && { REASON=dot-component-in-path; return 1; }
  case "$1" in
    derived-data) check_derived "$2";; plugin-clones) check_clone "$2";; browser-caches) check_pwcache "$2";;
    model-caches) check_model "$2";; worktrees) check_worktree "$2";; session-dirs) check_session "$2";; build-artifacts) check_artifact "$2";;
    gradle) check_gradle "$2";; ios) check_ios "$2";; android) check_android "$2";; pkg-caches) check_pkg "$2";;
    *) REASON=unknown-category; return 1;; esac; }

# ---------- candidates ----------
candidates(){  # category<TAB>path
  local d p prof a
  [ -d "$HYG_DERIVED_DATA" ] && for d in "$HYG_DERIVED_DATA"/*; do [ -e "$d" ] && printf 'derived-data\t%s\n' "$d"; done
  list_clones | while IFS= read -r d; do printf 'plugin-clones\t%s\n' "$d"; done
  list_profiles | while IFS= read -r prof; do
    for a in "${PW_CACHE_ALLOWLIST[@]}"; do [ -e "$prof/$a" ] && printf 'browser-caches\t%s\n' "$prof/$a"; done
    for p in "$prof"/BrowserMetrics*; do [ -e "$p" ] && printf 'browser-caches\t%s\n' "$p"; done
  done
  for d in $HYG_MODEL_CACHES; do [ -d "$d" ] && printf 'model-caches\t%s\n' "${d%/}"; done
  list_worktrees | fair_order worktrees | while IFS= read -r d; do printf 'worktrees\t%s\n' "$d"; done
  list_artifacts | while IFS= read -r d; do printf 'build-artifacts\t%s\n' "$d"; done
  list_sessions | fair_order session-dirs | while IFS= read -r d; do printf 'session-dirs\t%s\n' "$d"; done
  for d in "$HYG_GRADLE_HOME/wrapper/dists"/*/ "$HYG_GRADLE_HOME/daemon"/*/; do [ -d "$d" ] && printf 'gradle\t%s\n' "${d%/}"; done
  for d in "$HYG_DEVICE_SUPPORT"/*/; do [ -d "$d" ] && printf 'ios\t%s\n' "${d%/}"; done
  [ -x /usr/bin/xcrun ] && sim_unavailable_udids | while IFS= read -r u; do [ -d "$HYG_SIM_DEVICES/$u" ] && printf 'ios\t%s\n' "$HYG_SIM_DEVICES/$u"; done
  for d in "$HYG_ANDROID_HOME/cache"/*; do [ -e "$d" ] && printf 'android\t%s\n' "$d"; done
  for d in $HYG_PKG_CACHES; do [ -d "$d" ] && printf 'pkg-caches\t%s\n' "${d%/}"; done
}

plan(){ local cat p k prev="" n=0 r=0 t0=$SECONDS dl=0 cut=0 action age
  # One log line per category as it finishes (card ugCwRX0v), so a slow or stuck plan is visible
  # from `log_tail` / hygiene_status instead of a silent gap after "=== scheduled run".
  plan_mark(){ [ -n "$prev" ] && log "plan: $prev $n candidates ($r remove, $cut over budget) in $((SECONDS-t0))s"; }
  PLAN_T0=$SECONDS
  while IFS=$'\t' read -r cat p; do
    [ -n "$p" ] || continue
    if [ "$cat" != "$prev" ]; then plan_mark; prev="$cat"; n=0; r=0; cut=0; t0=$SECONDS; dl=$(budget_deadline "$cat"); fi
    n=$((n+1))
    if [ "$dl" != 0 ] && [ $((SECONDS-PLAN_T0)) -ge "$dl" ]; then cut=$((cut+1))
      printf '%s\tkeep\t0\tscan-budget-exceeded\t%s\t?\t\n' "$cat" "$p"; continue; fi
    if check_item "$cat" "$p"; then action=remove; r=$((r+1)); else action=keep; fi
    case "$cat" in worktrees|session-dirs) mark_scanned "$cat" "$p";; build-artifacts) mark_scanned "$cat" "$(top_folder "$p")";; esac
    age=$(age_bucket "$p")
    # Decide first, size after: a du of every candidate was the largest single cost of a plan.
    k=0; case "$action/$age" in remove/*|keep/-|keep/\>*) k=$(kb "$p"); [ -n "$k" ] || k=0;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$cat" "$action" "$k" "$REASON" "$p" "$age" "$BLOCKER"
  done < <(candidates)
  plan_mark; save_scanned
}

report(){ local f="${1:-$HYG_STATE_DIR/last-plan.tsv}"; [ -f "$f" ] || { echo "report: no plan at $f" >&2; exit 2; }
  /usr/bin/awk -F'\t' '$6!="" && $6!="-"{ k=$6"\t"$2"\t"$1"\t"$4; c[k]++; kb[k]+=$3 }
    END{ for(k in c) printf "%s\t%d\t%.1f GB\n", k, c[k], kb[k]/1048576 }' "$f" | /usr/bin/sort
  /usr/bin/awk -F'\t' -v old=">${HYG_REPORT_AGE_DAYS}d" '$2=="keep" && $6==old && $1!="build-artifacts"{ printf "kept-over-window\t%s\t%s\t%s\n", $4, ($7==""?"-":$7), $5 }' "$f"; }

RETENTION_DONE=0
# The ONLY path that removes dirty or unpushed work. Everything fails to keep: a folder leaves only after its
# archive is verified and the ledger line is written, and after idle and cwd are read once more.
remove_rescued(){ local p="$1" r common commons=""
  [ "$RETENTION_DONE" -lt "$HYG_RETENTION_MAX_PER_RUN" ] || { REASON=retention-cap-reached; return 1; }
  rescue_build "$p" || return 1
  drop_run_caches
  retention_idle "$p" || { REASON=touched-during-rescue; return 1; }
  CWDS=""; cwd_inside "$p" && { REASON=a-process-is-inside; return 1; }
  while IFS= read -r r; do [ -f "$r/.git" ] || continue
    common=$("$GIT" -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && commons="$commons$common"$'\n'
  done < <(repos_in "$p")
  /bin/rm -rf -- "$p" || return 1
  RETENTION_DONE=$((RETENTION_DONE+1)); log "retention: rescued and removed $p"
  printf '%s' "$commons" | /usr/bin/sort -u | while IFS= read -r common; do
    [ -n "$common" ] && [ -d "$common" ] && "$GIT" --git-dir="$common" worktree prune >/dev/null 2>&1; done
  return 0; }
remove_item(){ local cat="$1" p="$2" common r commons=""
  if [ "$RESCUE_NEEDED" = 1 ]; then remove_rescued "$p"; return
  elif [ "$cat" = worktrees ]; then
    common=$("$GIT" -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    "$GIT" -C "$p" worktree remove "$p" >>"$HYG_LOG" 2>&1 || return 1
    [ -n "$common" ] && "$GIT" --git-dir="$common" worktree prune >/dev/null 2>&1
  elif [ "$cat" = session-dirs ]; then
    # nested linked worktrees: remember their parent repos so their metadata is pruned after the rm
    while IFS= read -r r; do [ -f "$r/.git" ] || continue
      common=$("$GIT" -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && commons="$commons$common"$'\n'
    done < <(nested_repos "$p")
    /bin/rm -rf -- "$p" || return 1
    printf '%s' "$commons" | /usr/bin/sort -u | while IFS= read -r common; do
      [ -n "$common" ] && [ -d "$common" ] && "$GIT" --git-dir="$common" worktree prune >/dev/null 2>&1; done
  elif [ "$cat" = ios ] && [ "$(dirname "$p")" = "$HYG_SIM_DEVICES" ]; then
    /usr/bin/xcrun simctl delete "$(basename "$p")" >>"$HYG_LOG" 2>&1 || return 1
  else /bin/rm -rf -- "$p" || return 1; fi; return 0; }

apply(){ local file="$1" cat p k freed=0 n=0 refused=0
  [ -f "$file" ] || { echo "apply: plan file not found" >&2; exit 2; }
  drop_run_caches
  while IFS=$'\t' read -r cat p; do
    [ -n "$p" ] || continue
    if check_item "$cat" "$p"; then k=$(kb "$p"); [ -n "$k" ] || k=0
      if remove_item "$cat" "$p"; then emit "$cat" removed "$k" "$REASON" "$p"; log "removed [$cat] $((k/1024))MB $REASON $p"; freed=$((freed+k)); n=$((n+1))
      else emit "$cat" refused "$k" "${REASON:-remove-failed}" "$p"; log "refused [$cat] $REASON $p"; refused=$((refused+1)); fi
    else emit "$cat" refused 0 "$REASON" "$p"; refused=$((refused+1)); fi
  done < "$file"
  log "apply done: $n removed, ~$((freed/1024))MB freed, $refused refused"
  emit summary done "$freed" "removed=$n refused=$refused" "$(dfree) free"
}

status(){ local prof lock=0 inu=0 nprof=0 d stale=0 total=0
  printf 'disk_free\t%s\ndisk_used_pct\t%s\n' "$(dfree)" "$(dpct)"
  printf 'derived_data_kb\t%s\n' "$( [ -d "$HYG_DERIVED_DATA" ] && kb "$HYG_DERIVED_DATA" || echo 0)"
  printf 'plugin_clones\t%s\n' "$(list_clones | /usr/bin/wc -l | tr -d ' ')"
  while IFS= read -r prof; do [ -n "$prof" ] || continue; nprof=$((nprof+1)); [ -L "$prof/SingletonLock" ] && lock=$((lock+1)); inuse "$prof" && inu=$((inu+1)); done < <(list_profiles)
  printf 'browser_profiles\t%s\nbrowser_profiles_locked\t%s\nbrowser_profiles_in_use\t%s\n' "$nprof" "$lock" "$inu"
  while IFS= read -r d; do [ -n "$d" ] || continue; total=$((total+1)); wt_recently_touched "$d" || stale=$((stale+1)); done < <(list_worktrees)
  printf 'worktrees_total\t%s\nworktrees_idle_over_%sd\t%s\n' "$total" "$HYG_WT_AGE_DAYS" "$stale"
  total=0; stale=0
  while IFS= read -r d; do [ -n "$d" ] || continue; total=$((total+1)); done < <(list_sessions)
  printf 'session_dirs\t%s\n' "$total"
  printf 'retention\t%s\n' "$(retention_on && echo "on ${HYG_RETENTION_DAYS}d" || echo off)"
  # Kept past twice the window: only an owner decision moves these.
  if retention_on && [ -f "$HYG_STATE_DIR/last-plan.tsv" ]; then stale=0
    while IFS= read -r d; do [ -d "$d" ] || continue
      [ -n "$(/usr/bin/find "$d" \( -name .git -o -name node_modules \) -prune -o -type f -mtime -$((HYG_RETENTION_DAYS*2)) -print -quit 2>/dev/null)" ] || stale=$((stale+1))
    done < <(/usr/bin/awk -F'\t' -v old=">${HYG_REPORT_AGE_DAYS}d" '$1=="session-dirs" && $2=="keep" && $6==old{print $5}' "$HYG_STATE_DIR/last-plan.tsv")
    printf 'retention_overdue\t%s\n' "$stale"; fi
  printf 'gradle_kb\t%s\n' "$( [ -d "$HYG_GRADLE_HOME" ] && kb "$HYG_GRADLE_HOME" || echo 0)"
  printf 'ios_device_support_kb\t%s\nios_simulators_kb\t%s\n' "$( [ -d "$HYG_DEVICE_SUPPORT" ] && kb "$HYG_DEVICE_SUPPORT" || echo 0)" "$( [ -d "$HYG_SIM_DEVICES" ] && kb "$HYG_SIM_DEVICES" || echo 0)"
  printf 'android_avd_kb\t%s\nandroid_sdk_kb\t%s\n' "$( [ -d "$HYG_ANDROID_HOME/avd" ] && kb "$HYG_ANDROID_HOME/avd" || echo 0)" "$( [ -d "$HYG_ANDROID_SDK" ] && kb "$HYG_ANDROID_SDK" || echo 0)"
  printf 'xcode_building\t%s\n' "$(xcode_building && echo yes || echo no)"
  printf 'gh\t%s\ngit\t%s\n' "${GH:-not-found}" "$GIT"
  printf 'cleanup_period_days\t%s\n' "$(/usr/bin/grep -o '"cleanupPeriodDays": *[0-9]*' "$HOME/.claude/settings.json" 2>/dev/null | /usr/bin/grep -o '[0-9]*$' || echo default-30)"
  printf 'launchagent\t%s\n' "$(/bin/launchctl print "gui/$(id -u)/com.msapps.mac-agent-hygiene" >/dev/null 2>&1 && echo loaded || echo not-loaded)"
  printf 'log\t%s\n' "$HYG_LOG"
  [ -f "$HYG_LOG" ] && /usr/bin/tail -5 "$HYG_LOG" | while IFS= read -r l; do printf 'log_tail\t%s\n' "$l"; done
}

run(){ local pf="$TMPD/plan.tsv" lp="$HYG_STATE_DIR/last-plan.tsv"
  # Runs every few hours: a slow run must never overlap the next one. mkdir is atomic; a lock older
  # than 6 h is a crashed run and is taken over.
  if ! /bin/mkdir "$HYG_LOCK" 2>/dev/null; then
    if [ -n "$(/usr/bin/find "$HYG_LOCK" -maxdepth 0 -mmin +360 2>/dev/null)" ]; then
      log "stale lock $HYG_LOCK taken over"; else log "=== scheduled run skipped: previous run still holds $HYG_LOCK"; return 0; fi
  fi
  trap '/bin/rm -rf "$TMPD" "$HYG_LOCK"' EXIT
  log "=== scheduled run"
  /bin/mkdir -p "$HYG_STATE_DIR" 2>/dev/null
  # kept whole: `report` reads why each folder stayed. A plan that cannot be saved stops the run: applying the
  # previous run's plan would make every run a silent no-op on stale rows.
  { plan > "$lp.$$" && /bin/mv -f "$lp.$$" "$lp"; } || { /bin/rm -f "$lp.$$" 2>/dev/null; log "plan failed: cannot write $lp"; return 0; }
  report "$lp" 2>/dev/null | /usr/bin/awk -F'\t' '$1!="kept-over-window"' | while IFS= read -r l; do log "plan-report: $l"; done
  /usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$lp" > "$pf"
  apply "$pf"; }

case "${1:-}" in
  status) status;; plan) plan;; report) report "${2:-}";; apply) apply "${2:?plan file}";; run) run;;
  *) echo "usage: hygiene.sh status|plan|report [planfile]|apply <planfile>|run" >&2; exit 2;;
esac
exit 0
