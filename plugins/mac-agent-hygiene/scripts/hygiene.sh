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
#   worktrees        linked git worktrees (.git is a FILE) up to HYG_WT_DEPTH levels under HYG_WT_ROOT:
#                    a direct child matching HYG_WT_GLOB, or anything below a top-level dir named in
#                    HYG_WT_NESTED (default "wt _worktrees": ~/code/wt/{sup,ref,pipe}-*/..., ~/code/_worktrees/...).
#                    No file newer than
#                    HYG_WT_AGE_DAYS, clean, nobody's cwd, and HEAD on a remote ref, or a merged PR for
#                    the branch: exact head SHA, or (rebased / force-pushed heads) every local-only
#                    commit subject matches one of the PR's commits. Dirty / unpushed / in-use: KEPT.
#                    Note: "clean" is `git status --porcelain`, so gitignored files (a local .env,
#                    node_modules) go with the worktree. The branch ref stays — nothing is unrecoverable.
#   session-dirs     EVERY folder directly under HYG_SESSION_ROOT (~/code/wt) that is not a linked worktree
#                    (those are the worktrees pass): plain session folders AND full clones. Nothing touched
#                    for HYG_SESSION_AGE_HOURS, nobody's cwd, the session not alive in HYG_SESSIONS_JSON,
#                    and the folder's own clone plus EVERY git repo or worktree nested inside is clean and
#                    pushed (same git_safe test as worktrees). One dirty or unpushed repo keeps the whole
#                    folder; a folder holding no repo at all is kept (no-nested-repo), and so is a plain folder
#                    with ANY regular file beside its repos (notes, prompts, scripts, archives; __pycache__ and
#                    .DS_Store excepted). "Held by a parent-repo
#                    branch" counts only when HYG_SESSION_PARENT_BRANCH_OK=1 (default 0).
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
VARS="HYG_LOG HYG_DERIVED_DATA HYG_PLUGIN_CACHE HYG_PLUGIN_CLONE_MIN_AGE_MIN HYG_PW_GLOB HYG_MODEL_CACHES HYG_MODEL_CACHE_AGE_DAYS HYG_WT_ROOT HYG_WT_GLOB HYG_WT_NESTED HYG_WT_DEPTH HYG_WT_AGE_DAYS HYG_WT_MERGED_PR_CHECK HYG_GIT HYG_GH HYG_GH_SHA_CHECK_MAX HYG_SESSION_ROOT HYG_SESSION_AGE_HOURS HYG_SESSION_PARENT_BRANCH_OK HYG_GRADLE_HOME HYG_GRADLE_AGE_DAYS HYG_DEVICE_SUPPORT HYG_DEVICE_SUPPORT_AGE_DAYS HYG_SIM_DEVICES HYG_ANDROID_HOME HYG_ANDROID_CACHE_AGE_DAYS HYG_ANDROID_SDK HYG_PKG_CACHES HYG_PKG_CACHE_AGE_DAYS HYG_LOCK HYG_SESSIONS_JSON HYG_ARTIFACT_IDLE_HOURS HYG_ARTIFACT_DEPTH HYG_JQ HYG_LSOF HYG_PLAN_BUDGET_MIN HYG_REPORT_AGE_DAYS HYG_STATE_DIR"
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
HYG_WT_NESTED="${HYG_WT_NESTED-wt _worktrees}"   # set to "" to scan direct children only
HYG_WT_DEPTH="${HYG_WT_DEPTH:-3}"
HYG_WT_AGE_DAYS="${HYG_WT_AGE_DAYS:-7}"
HYG_WT_MERGED_PR_CHECK="${HYG_WT_MERGED_PR_CHECK:-1}"
HYG_GH_SHA_CHECK_MAX="${HYG_GH_SHA_CHECK_MAX:-500}"   # gh compare calls per run for in_github_default; over it ⇒ KEEP
HYG_SESSION_ROOT="${HYG_SESSION_ROOT:-$HOME/code/wt}"; HYG_SESSION_ROOT="${HYG_SESSION_ROOT%/}"
HYG_SESSION_AGE_HOURS="${HYG_SESSION_AGE_HOURS:-24}"
HYG_SESSIONS_JSON="${HYG_SESSIONS_JSON:-$HOME/.local/state/opsagents-routines/sessions.json}"
HYG_ARTIFACT_IDLE_HOURS="${HYG_ARTIFACT_IDLE_HOURS:-24}"
HYG_ARTIFACT_DEPTH="${HYG_ARTIFACT_DEPTH:-6}"
HYG_SESSION_PARENT_BRANCH_OK="${HYG_SESSION_PARENT_BRANCH_OK:-0}"   # 1 = a session worktree held only by a parent-repo branch counts as safe
HYG_PLAN_BUDGET_MIN="${HYG_PLAN_BUDGET_MIN:-12}"   # worktrees + build-artifacts + session-dirs wall clock; what is left waits for the next run. 0 = no limit
HYG_REPORT_AGE_DAYS="${HYG_REPORT_AGE_DAYS:-7}"
HYG_STATE_DIR="${HYG_STATE_DIR:-$HOME/.local/state/mac-agent-hygiene}"
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
HYG_LOCK="${HYG_LOCK:-${TMPDIR:-/tmp}/mac-agent-hygiene-$(/usr/bin/id -u).lock}"   # per user: /tmp is shared when TMPDIR is unset
HYG_DERIVED_DATA="${HYG_DERIVED_DATA%/}"; HYG_PLUGIN_CACHE="${HYG_PLUGIN_CACHE%/}"
case "$HYG_WT_AGE_DAYS$HYG_MODEL_CACHE_AGE_DAYS$HYG_PLUGIN_CLONE_MIN_AGE_MIN$HYG_WT_DEPTH$HYG_SESSION_AGE_HOURS$HYG_GRADLE_AGE_DAYS$HYG_DEVICE_SUPPORT_AGE_DAYS$HYG_ANDROID_CACHE_AGE_DAYS$HYG_PKG_CACHE_AGE_DAYS$HYG_GH_SHA_CHECK_MAX$HYG_ARTIFACT_IDLE_HOURS$HYG_ARTIFACT_DEPTH$HYG_PLAN_BUDGET_MIN$HYG_REPORT_AGE_DAYS" in *[!0-9]*) echo "age settings must be integers" >&2; exit 2;; esac
case "$HYG_SESSION_PARENT_BRANCH_OK" in 0|1) ;; *) echo "HYG_SESSION_PARENT_BRANCH_OK must be 0 or 1" >&2; exit 2;; esac

GIT="${HYG_GIT:-}"
if [ -z "$GIT" ]; then GIT=/usr/bin/git; [ -x "$HOME/.local/bin/git" ] && GIT="$HOME/.local/bin/git"; fi   # honour a user's git shim unless HYG_GIT is explicit
GH="${HYG_GH:-}"
if [ -z "$GH" ]; then
  for c in "$(command -v gh 2>/dev/null)" /opt/homebrew/bin/gh /usr/local/bin/gh; do
    [ -n "$c" ] && [ -x "$c" ] && { GH="$c"; break; }
  done
fi

first_exec(){ local c; for c in "$@"; do [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }; done; return 0; }
LSOF="${HYG_LSOF:-$(first_exec /usr/sbin/lsof /usr/bin/lsof)}"   # macOS: /usr/sbin; Linux CI: /usr/bin. Never a bare PATH lookup.

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
inuse(){ [ -x "$LSOF" ] || return 0; "$LSOF" +D "$1" >/dev/null 2>&1; }   # no lsof ⇒ cannot tell ⇒ in use
path_key(){ printf '%s' "$1" | /usr/bin/shasum | /usr/bin/cut -c1-16; }
# Answers that cost a tree walk are cached per run; apply drops them so its re-check reads the disk again.
drop_run_caches(){ /bin/rm -f "$TMPD"/inv-* "$TMPD"/idle-* "$TMPD"/inuse-* "$TMPD"/age-*; CWDS=""; ALIVE=""; ALIVE_LOADED=0; }
inuse_cached(){ local f; f="$TMPD/inuse-$(path_key "$1")"
  [ -f "$f" ] || { if inuse "$1"; then echo 1; else echo 0; fi > "$f"; }; [ "$(/bin/cat "$f")" = 1 ]; }
xcode_building(){ /usr/bin/pgrep -qx xcodebuild || /usr/bin/pgrep -qx Xcode || /usr/bin/pgrep -qx XCBBuildService; }
simulator_running(){ /usr/bin/pgrep -qx Simulator || /usr/bin/pgrep -qf 'CoreSimulator/.*launchd_sim'; }
older_than_days(){ [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mtime +"$2" 2>/dev/null)" ]; }
physical(){ cd -P -- "$1" 2>/dev/null && pwd -P; }   # the real path, symlinks resolved; fails on a path that does not resolve
has_dot_component(){ case "/$1/" in */./*|*/../*) return 0;; esac; return 1; }
# Every process's cwd, read ONCE per run; compared as fixed strings (never as a pattern). lsof missing,
# exiting non-zero (a list cut short is not a full one, even when it printed rows: PR #80 review B1), or
# printing no cwd at all (it always sees at least this process), means we are blind: every folder then
# counts as having a process inside ⇒ KEEP, never "nobody is inside". cwd_inside answers that itself, so
# every caller (session-dirs, build-artifacts, worktrees) and any future one is safe by default.
CWDS=""; CWDS_LOADED=0; CWDS_BLIND=0
load_cwds(){ local raw rc; [ "$CWDS_LOADED" = 1 ] && return 0; CWDS_LOADED=1
  if [ -n "$LSOF" ] && [ -x "$LSOF" ]; then raw=$("$LSOF" -d cwd -Fn 2>/dev/null); rc=$?
    [ "$rc" = 0 ] && CWDS=$(printf '%s\n' "$raw" | /usr/bin/sed -n 's/^n//p'); fi
  [ -n "$CWDS" ] || CWDS_BLIND=1; }
cwd_inside(){ local c; load_cwds; [ "$CWDS_BLIND" = 1 ] && return 0
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
    if touched_within_min "$t" 1440 .git "${ARTIFACT_NAMES[@]}" .venv venv Pods DerivedData; then echo '<1d' > "$f"
    elif [ -n "$(/usr/bin/find "$t" \( "${e[@]}" \) -prune -o -type f -mtime -"$HYG_REPORT_AGE_DAYS" -print -quit 2>/dev/null)" ]; then echo "1-${HYG_REPORT_AGE_DAYS}d" > "$f"
    else echo ">${HYG_REPORT_AGE_DAYS}d" > "$f"; fi
  fi; /bin/cat "$f"; }

# ---------- enumerators (shared by status, plan and the candidate list) ----------
# Is $1 a place agent worktrees live? A direct child of HYG_WT_ROOT whose name matches HYG_WT_GLOB, or
# a path at most HYG_WT_DEPTH levels deep under a top-level dir listed in HYG_WT_NESTED (card SIDmENpf:
# phase sessions put them under ~/code/wt/{sup,ref,pipe}-*/..., 163 GB the direct-child scan never saw;
# card uO9PFYg8: ~/code/_worktrees/<card>/, 21 GB in 62 linked worktrees, the same gap).
# A human's own ~/code/project/feature worktree stays out of scope.
wt_in_scope(){ local rel top slashes n
  case "$1" in "$HYG_WT_ROOT"/*) ;; *) return 1;; esac
  rel="${1#"$HYG_WT_ROOT"/}"; top="${rel%%/*}"
  slashes="${rel//[!\/]/}"; [ $(( ${#slashes} + 1 )) -le "$HYG_WT_DEPTH" ] || return 1
  if [ "$rel" = "$top" ]; then case "$top" in $HYG_WT_GLOB) return 0;; esac; fi
  for n in $HYG_WT_NESTED; do [ "$top" = "$n" ] && [ "$rel" != "$top" ] && return 0; done
  return 1; }
# Linked worktrees only (.git is a FILE); a full clone's .git DIR is pruned, never listed.
list_worktrees(){ local g d
  [ -d "$HYG_WT_ROOT" ] || return 0
  /usr/bin/find "$HYG_WT_ROOT" -mindepth 2 -maxdepth $((HYG_WT_DEPTH+1)) \( -type d \( -name .git -o -name node_modules \) -prune \) \
      -o \( -type f -name .git -print \) 2>/dev/null | /usr/bin/sort |
  while IFS= read -r g; do d="${g%/.git}"; wt_in_scope "$d" && printf '%s\n' "$d"; done; }
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
# First regular file in $1 that lives OUTSIDE every nested repo (a directory holding a .git file or dir is
# pruned whole), or nothing. __pycache__ and .DS_Store regenerate and do not count.
loose_file_in(){ /usr/bin/find "$1" -mindepth 1 \( -type d \( -name __pycache__ -o -exec /bin/test -e '{}/.git' \; \) -prune \) \
  -o \( -type f ! -name .DS_Store -print -quit \); }
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
# git run on repos an agent made: repo-local config must not be able to run a command while we only
# look (core.fsmonitor and hooks are the command-executing keys `status` would honour; log.showSignature
# makes `log` / `stash list` run gpg.program, gpg.ssh.program or gpg.x509.program on a signed commit).
GITS(){ GIT_CONFIG_NOSYSTEM=1 "$GIT" --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null \
  -c core.untrackedCache=false -c diff.external= -c core.pager=cat -c log.showSignature=false "$@"; }
# Repo-local config is input an agent (or a cloned repo) wrote, and git reads it on EVERY call here. Keys that
# make a look-only call run a program are many: filter/diff/merge drivers, include/includeIf, core.sshCommand,
# remote.<n>.uploadpack with a promisor remote (lazy fetch spawns it), log.showSignature + gpg.program, ... A
# deny-list of them cannot be finished (card w1t7IqUt: both of the last two ran a canary during `plan` at
# 923f715 while the deny-list passed). So this is an ALLOW-list: a repo whose config holds ANY key outside
# CFG_ALLOW_RE, or whose config cannot be listed, is KEPT unread. -c overrides in GITS stay as a second layer.
CFG_ALLOW_RE='^(core\.(repositoryformatversion|filemode|bare|logallrefupdates|ignorecase|precomposeunicode|symlinks|worktree)|extensions\.worktreeconfig|remote\..+\.(url|pushurl|fetch|tagopt|prune|gh-resolved)|branch\..+\.(remote|merge|rebase|description|vscode-merge-base|github-pr-owner-number)|user\.(name|email)|init\.defaultbranch|pull\.(rebase|ff)|push\.(default|autosetupremote)|fetch\.prune)$'
repo_config_unvetted(){ local gd wd f out
  gd=$(GITS -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  wd=$(GITS -C "$1" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 0
  [ -f "$gd/config" ] || return 0
  for f in "$gd/config" "$wd/config.worktree"; do
    [ -f "$f" ] || continue
    out=$("$GIT" config --file "$f" --name-only --list 2>/dev/null) || return 0
    printf '%s\n' "$out" | /usr/bin/grep -viE "$CFG_ALLOW_RE" | /usr/bin/grep -q . && return 0
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
# Every subject in file $1 equals a headline in file $2, or starts with a headline gh truncated ("…").
subjects_all_in(){ local s p pp hit
  while IFS= read -r s; do hit=1
    while IFS= read -r p; do [ -n "$p" ] || continue
      [ "$s" = "$p" ] && { hit=0; break; }
      case "$p" in *…) ;; *) continue;; esac
      pp="${p%…}"; pp="${pp%"${pp##*[! ]}"}"                       # drop the ellipsis and trailing blanks
      [ ${#pp} -ge 20 ] || continue                                   # never match on a stub prefix
      case "$s" in "$pp"*) hit=0; break;; esac
    done < "$2"
    [ $hit = 0 ] || return 1
  done < "$1"; return 0; }
# A rebased / force-pushed branch: its MERGED PR's head SHA is not our HEAD, but every commit we hold
# that no remote has must appear among the PR's commits by subject. Any doubt (no commits, gh failure,
# one subject without a match) ⇒ 1 ⇒ KEEP.
merged_pr_commits_match(){ local d="$1" repo="$2" f="$3" b="$4" ls="$TMPD/local-subjects" rb ro rn pf
  GITS -C "$d" log --no-show-signature --format=%s HEAD --not --remotes > "$ls" 2>/dev/null || return 1
  [ -s "$ls" ] || return 1
  [ "$(/usr/bin/wc -l < "$ls")" -le 200 ] || return 1
  while read -r rb ro rn; do
    [ "$rb" = "$b" ] && [ -n "$rn" ] || continue
    case "$rn" in *[!0-9]*) continue;; esac
    pf="$f.pr$rn"
    [ -f "$pf" ] || "$GH" pr view "$rn" --repo "$repo" --json commits --jq '.commits[].messageHeadline' > "$pf" 2>/dev/null || : > "$pf"
    subjects_all_in "$ls" "$pf" && return 0
  done < "$f"
  return 1; }
# Physical path of an existing directory, or empty.
realdir(){ physical "$1"; }   # same as `physical` (B8: one real-path helper)
# Worktree directory a registered admin dir ($1 = <common>/worktrees/<name>) points at. `gitdir` holds an
# absolute path, or a path relative to the admin dir when worktree.useRelativePaths=true (git >= 2.48).
# Prints the (possibly unresolved) directory; rc 1 when the file is missing, unreadable or empty.
wt_path_of_admin(){ local g
  g=$(/bin/cat "$1/gitdir" 2>/dev/null) || return 1; [ -n "$g" ] || return 1
  case "$g" in /*) ;; *) g="$1/$g";; esac
  /usr/bin/dirname "$g"; }
# owner/name of $1's origin, or empty (⇒ no gh call ⇒ KEEP). strict: only an anchored github.com URL.
# loose: any URL ending in github.com[:/]owner/name (main's fixtures use a local .../github.com/acme/demo.git).
gh_repo_of(){ local url r
  url=$(GITS -C "$1" remote get-url origin 2>/dev/null)
  if [ "$2" = strict ]; then
    r=$(printf '%s\n' "$url" | /usr/bin/sed -nE 's#^(https://|ssh://git@|git@)github\.com[:/]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$#\2#p' | /usr/bin/sed -E 's#\.git$##')
  else
    r=$(printf '%s\n' "$url" | /usr/bin/sed -E 's#.*github.com[:/]##; s#\.git$##')
    [[ "$r" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || r=""
  fi
  case "$r" in *..*|.*|*/.*) r="";; esac
  printf '%s' "$r"; }
# A full clone owns the object store of every worktree registered in $gd/worktrees/*. rm -rf of the
# clone orphans them (no HEAD, no index, no repo). 0 ⇒ a registered worktree resolves OUTSIDE the
# deletion boundary $2 and still exists (or is locked, e.g. on an unmounted volume, or its gitdir file is
# unreadable) ⇒ the clone must stay. Worktrees inside the boundary are nested repos checked on their own.
clone_has_live_worktree_outside(){ local gd rbound w wt rw
  gd=$(GITS -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  rbound=$(realdir "$2"); [ -n "$rbound" ] || return 0
  for w in "$gd"/worktrees/*; do [ -d "$w" ] || continue
    [ -f "$w/locked" ] && return 0
    wt=$(wt_path_of_admin "$w") || return 0                         # unreadable gitdir ⇒ treat as live
    [ -e "$wt" ] || continue                                        # gone: `git worktree prune` material
    rw=$(realdir "$wt"); [ -n "$rw" ] || return 0
    case "$rw/" in "$rbound"/*) ;; *) return 0;; esac
  done; return 1; }
# git_safe dir bound allow_parent_branch → 0 removable (REASON=pushed|in-github-default-branch|
# merged-pr-head|merged-pr-commits|branch-kept-in-parent-repo) / 1 keep. bound = the dir apply would rm.
# allow_parent_branch=1 only for session-dirs with HYG_SESSION_PARENT_BRANCH_OK=1: it loosens "unpushed ⇒
# KEPT", so the worktrees category always passes 0.
git_safe(){
  local d="$1" bound="${2:-$1}" allow_pb="${3:-0}" b h repo prrepo f st br cdir rc rbound wg pb po pn tl iv rd rb
  repo_config_unvetted "$d" && { REASON=repo-config-not-allowlisted; return 1; }
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
  # --untracked-files=all on the command line overrides a repo's status.showUntrackedFiles=no, which
  # would otherwise make untracked files read clean and go with the rm (PR #80 review B2).
  st=$(GITS -C "$d" -c diff.ignoreSubmodules=all status --porcelain --untracked-files=all --ignore-submodules=all 2>/dev/null) || { REASON=git-status-failed; return 1; }
  [ -z "$st" ] || { REASON=dirty-uncommitted-work; return 1; }
  # status never reports edits to a tracked file flagged assume-unchanged (lowercase tag in `ls-files -v`)
  # or skip-worktree (tag S), so they read clean and go with the rm (B4). Any flagged entry ⇒ KEEP, unread:
  # that includes a sparse checkout, whose out-of-cone entries all carry S.
  iv=$(GITS -C "$d" ls-files -v 2>/dev/null) || { REASON=git-ls-files-failed; return 1; }
  printf '%s\n' "$iv" | LC_ALL=C /usr/bin/grep -q '^[a-zS] ' && { REASON=index-hides-changes; return 1; }
  # owner/name only from an anchored github.com URL; anything else ⇒ empty ⇒ no gh compare call ⇒ KEEP
  repo=$(gh_repo_of "$d" strict)
  if [ -d "$d/.git" ]; then   # a full clone owns its stash, every local ref and its linked worktrees' git data
    [ -z "$(GITS -C "$d" stash list 2>/dev/null)" ] || { REASON=clone-has-stash; return 1; }
    clone_has_live_worktree_outside "$d" "$bound" && { REASON=clone-has-live-worktree-outside; return 1; }
    # Linked worktrees keep their HEAD, index and rebase state under $d/.git/worktrees/: the rm takes them
    # even when the worktree folder lives elsewhere. clone_has_live_worktree_outside (above) keeps the clone
    # for a live one outside the boundary; this stricter pass also keeps it when any registered worktree
    # cannot be resolved (missing/prunable) or the list cannot be read (B1).
    local wtl wp wr
    wtl=$(GITS -C "$d" worktree list --porcelain 2>/dev/null) || { REASON=git-worktree-list-failed; return 1; }
    [ -n "$wtl" ] || { REASON=git-worktree-list-failed; return 1; }
    rb=$(physical "$bound") || { REASON=boundary-unresolvable; return 1; }
    [ -n "$rb" ] || { REASON=boundary-unresolvable; return 1; }
    while IFS= read -r wp; do
      case "$wp" in "worktree "*) wp="${wp#worktree }";; *) continue;; esac
      wr=$(physical "$wp") || wr=""
      case "$wr/" in "$rb"/*) ;; *) REASON=has-linked-worktrees; return 1;; esac
    done <<< "$wtl"
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
  if [ "$HYG_WT_MERGED_PR_CHECK" = 1 ] && [ -n "$GH" ]; then
    b=$(GITS -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    prrepo=$(gh_repo_of "$d" loose)   # owner/name or nothing ⇒ no gh call
    if [ -n "$prrepo" ]; then
      f="$TMPD/$(echo "$prrepo" | tr / _)"
      [ -f "$f" ] || "$GH" pr list --repo "$prrepo" --state merged --limit 3000 --json headRefName,headRefOid,number \
          --jq '.[] | "\(.headRefName) \(.headRefOid) \(.number)"' > "$f" 2>/dev/null || : > "$f"   # gh failure ⇒ empty ⇒ KEEP
      while read -r pb po pn; do [ "$pb" = "$b" ] && [ "$po" = "$h" ] && { REASON=merged-pr-head; return 0; }; done < "$f"
      if [ -n "$b" ] && [ "$b" != HEAD ] && merged_pr_commits_match "$d" "$prrepo" "$f" "$b"; then REASON=merged-pr-commits; return 0; fi
    fi
  fi
  # Gated (HYG_SESSION_PARENT_BRANCH_OK, default 0): a clean linked worktree whose HEAD a local branch
  # holds loses nothing when the worktree goes — provided the parent survives the removal. So: the
  # parent's real path lies outside the deletion boundary, and the parent really registers this dir as
  # one of its worktrees ($cdir/worktrees/<name>/gitdir points back at $d/.git).
  if [ "$allow_pb" = 1 ] && [ -f "$d/.git" ]; then
    cdir=$(GITS -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    rc=$(realdir "$cdir"); rbound=$(realdir "$bound")
    wg=$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    if [ -n "$rc" ] && [ -n "$rbound" ] && case "$rc/" in "$rbound"/*) false;; *) true;; esac \
       && case "$wg" in "$cdir"/worktrees/*) true;; *) false;; esac \
       && [ "$(realdir "$(wt_path_of_admin "$wg")")" = "$(realdir "$d")" ] \
       && [ -n "$(GITS -C "$d" for-each-ref --contains "$h" --format=x refs/heads 2>/dev/null | /usr/bin/head -1)" ]; then
      REASON=branch-kept-in-parent-repo; return 0; fi
  fi
  REASON=unpushed-commits; return 1; }
check_worktree(){ local d="$1" gd cdir rel
  wt_in_scope "$d" || { REASON=outside-worktree-scope; return 1; }
  [ -f "$d/.git" ] || { REASON=not-a-linked-worktree; return 1; }        # a full clone has a .git DIR — left alone
  # B13: the same registry rule as every other pass. A worktree is a session's folder (or sits inside one):
  # name the worktree itself and the top-level session folder it lives under.
  session_alive "$d" && { REASON=session-alive-in-registry; return 1; }
  case "$d" in "$HYG_SESSION_ROOT"/*/*) rel="${d#"$HYG_SESSION_ROOT"/}"; session_alive "$HYG_SESSION_ROOT/${rel%%/*}" && { REASON=session-alive-in-registry; return 1; };; esac
  gd=$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)
  cdir=$(GITS -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  [ -n "$gd" ] && [ "$gd" != "$cdir" ] || { REASON=not-a-linked-worktree; return 1; }   # submodule / separate git-dir
  wt_recently_touched "$d" && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  git_safe "$d" "$d" 0; }

# THE idle walk (B16; same form as wt_recently_touched above). 0 ⇒ a regular file outside the directories named
# in "$3..." changed in the last $2 minutes, or find itself failed (unreadable ⇒ unmeasured ⇒ treat as touched).
# The two callers prune different sets ON PURPOSE:
#   check_session  deletes the WHOLE folder, so only .git and dependency trees (node_modules .venv Pods) are
#                  skipped: a fresh file in dist/ build/ .next/ coverage/ .turbo/ is recent work and counts.
#   session_idle   only strips the artifact dirs, so it also skips every ARTIFACT_NAMES dir: what is being
#                  removed is not evidence that a human is still working in the folder.
touched_within_min(){ local d="$1" mins="$2" n e=() out rc; shift 2
  while IFS= read -r n; do e+=( "$n" ); done < <(name_expr "$@")
  out=$(/usr/bin/find "$d" \( "${e[@]}" \) -prune -o -type f -mmin -"$mins" -print -quit 2>/dev/null); rc=$?
  [ -n "$out" ] || [ "$rc" != 0 ]; }
check_session(){ local d="$1" r n=0 loose
  [ "$(dirname "$d")" = "$HYG_SESSION_ROOT" ] || { REASON=outside-session-root; return 1; }
  [ -L "$d" ] && { REASON=is-a-symlink; return 1; }
  [ -f "$d/.git" ] && { REASON=linked-worktree-see-worktrees-pass; return 1; }
  [ -e "$d/.git" ] && [ ! -d "$d/.git" ] && { REASON=odd-git-entry; return 1; }
  session_alive "$d" && { REASON=session-alive-in-registry; return 1; }
  touched_within_min "$d" "$((HYG_SESSION_AGE_HOURS*60))" .git node_modules .venv Pods && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  # A walk that failed keeps the folder under its own reason, naming the path it could not read.
  walk_failed "$d" && return 1
  # A bare repo or separate git-dir elsewhere in the folder would go with the rm unchecked: keep, unread.
  holds_bare_or_separate_git_dir "$d" && { REASON=contains-bare-or-separate-git-dir; BLOCKER=$(first_inventory "$d" '/HEAD$'); return 1; }
  if [ -d "$d/.git" ]; then n=1; git_safe "$d" "$d" 0 || { REASON="clone-$REASON"; BLOCKER=.; return 1; }; fi   # the folder IS a clone (a repo git_safe vouched for)
  while IFS= read -r r; do [ -n "$r" ] || continue; n=$((n+1))
    git_safe "$r" "$d" "$HYG_SESSION_PARENT_BRANCH_OK" || { REASON="nested-$REASON"; BLOCKER="${r#"$d"/}"; return 1; }
  done < <(nested_repos "$d")
  # The category reclaims checkouts: with no repo there is nothing git_safe vouched for (research notes,
  # review outputs), so the folder stays.
  [ "$n" -gt 0 ] || { REASON=no-nested-repo; return 1; }
  # rm -rf takes the whole folder, but git_safe vouched only for the repos. A file beside them (a prompt,
  # notes, a script, an archive, JSON output) has no other copy: keep. A scan that errors keeps too.
  # A top-level clone is not scanned: git_safe already kept it for any tracked change or non-ignored
  # untracked file (status --untracked-files=all), so what still goes with the rm is its IGNORED files
  # (listed in safety-model.md "What these guards do not read").
  if [ ! -d "$d/.git" ]; then
    loose=$(loose_file_in "$d" 2>/dev/null) || { REASON=loose-file-scan-failed; return 1; }
    [ -z "$loose" ] || { REASON=loose-files-outside-repos; return 1; }
  fi
  REASON=stale-session-all-nested-pushed; return 0; }
# Session folder idle: no file (outside .git and the artifact dirs themselves) newer than the window.
# Cached per folder for the run.
session_idle(){ local t="$1" f; f="$TMPD/idle-$(path_key "$t")"
  if [ ! -f "$f" ]; then
    if touched_within_min "$t" "$((HYG_ARTIFACT_IDLE_HOURS*60))" .git "${ARTIFACT_NAMES[@]}" .venv Pods
    then echo 0 > "$f"; else echo 1 > "$f"; fi
  fi; [ "$(/bin/cat "$f")" = 1 ]; }
check_artifact(){ local p="$1" rel top name parent tracked tl l
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
    repo_config_unvetted "$parent" && { REASON=repo-config-not-allowlisted; return 1; }
    # With core.worktree elsewhere, the two answers below describe that other tree, not this dir (B5).
    tl=$(GITS -C "$parent" rev-parse --show-toplevel 2>/dev/null) && [ -n "$tl" ] || { REASON=worktree-not-this-folder; return 1; }
    tl=$(physical "$tl") && [ -n "$tl" ] || { REASON=worktree-not-this-folder; return 1; }
    case "$(physical "$parent")/" in "$tl"/*) ;; *) REASON=worktree-not-this-folder; return 1;; esac
    # B3 (sibling of B12): a nested repo git cannot read (lost HEAD, empty .git) is skipped by discovery,
    # which then answers from the OUTER repo, so the two answers below describe the outer repo, not the one
    # that tracked this dir. Any .git entry between the artifact's folder and the top level git found ⇒ KEEP.
    l=$(physical "$parent") && [ -n "$l" ] || { REASON=worktree-not-this-folder; return 1; }
    while [ "$l" != "$tl" ] && [ "$l" != / ]; do
      { [ -e "$l/.git" ] || [ -L "$l/.git" ]; } && { REASON=git-cannot-read-repo; return 1; }
      l=$(/usr/bin/dirname "$l")
    done
    tracked=$(GITS -C "$parent" ls-files -- "$name" 2>/dev/null | /usr/bin/head -1) || { REASON=git-ls-files-failed; return 1; }
    [ -z "$tracked" ] || { REASON=has-tracked-files; return 1; }
    GITS -C "$parent" check-ignore -q -- "$name/" 2>/dev/null || { REASON=not-gitignored; return 1; }
    REASON=gitignored-build-output; return 0
  fi
  # B12: git failing is not "there is no repo". Any .git entry (dir, file, even a dangling symlink) from the
  # artifact's folder up to the session folder is a repo git could not vouch for (unknown extensions.*, a
  # linked worktree whose parent is gone, a corrupt .git): a tracked file here may hold uncommitted work. KEEP.
  l="$parent"
  while :; do
    { [ -e "$l/.git" ] || [ -L "$l/.git" ]; } && { REASON=git-cannot-read-repo; return 1; }
    [ "$l" = "$top" ] || [ "$l" = / ] && break
    l=$(/usr/bin/dirname "$l")
  done
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

# L2: the path must be physical under its category's root: no symlink as the leaf or as any component, or
# `git worktree remove` / `rm -rf` act on whatever the link points at. Resolved in check_item (plan AND apply) and
# AGAIN in remove_item right before the removal. A path that does not exist passes (the category check says gone).
scope_root(){ case "$1" in worktrees) printf '%s' "$HYG_WT_ROOT";; session-dirs|build-artifacts) printf '%s' "$HYG_SESSION_ROOT";; esac; }
real_under_scope(){ local root rr rp; root=$(scope_root "$1"); [ -n "$root" ] || return 0
  [ -e "$2" ] || [ -L "$2" ] || return 0
  case "$2" in "$root"/*) ;; *) return 1;; esac
  rr=$(physical "$root") && rp=$(physical "$2") || return 1
  [ "$rp" = "$rr/${2#"$root"/}" ]; }
check_item(){ # category path → 0 removable (REASON=why) / 1 keep (REASON=why, BLOCKER=the path that decided it, . = the folder)
  BLOCKER=""; check_item_inner "$1" "$2" && return 0
  [ -n "$BLOCKER" ] || BLOCKER=.; return 1; }
check_item_inner(){
  case "$2" in "$HOME"/*) ;; *) REASON=outside-home; return 1;; esac
  has_dot_component "$2" && { REASON=dot-component-in-path; return 1; }
  real_under_scope "$1" "$2" || { REASON=path-has-symlink-component; return 1; }
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

remove_item(){ local cat="$1" p="$2" common r commons=""
  # Last look before the removal (L2). Every git call below goes through GITS: apply runs git on repos an agent made.
  real_under_scope "$cat" "$p" || { log "refused [$cat] path no longer physical under its root: $p"; return 1; }
  if [ "$cat" = worktrees ]; then
    common=$(GITS -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    GITS -C "$p" worktree remove "$p" >>"$HYG_LOG" 2>&1 || return 1
    [ -n "$common" ] && GITS --git-dir="$common" worktree prune >/dev/null 2>&1
  elif [ "$cat" = session-dirs ]; then
    # nested linked worktrees: remember their parent repos so their metadata is pruned after the rm
    while IFS= read -r r; do [ -f "$r/.git" ] || continue
      common=$(GITS -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && commons="$commons$common"$'\n'
    done < <(nested_repos "$p")
    /bin/rm -rf -- "$p" || return 1
    printf '%s' "$commons" | /usr/bin/sort -u | while IFS= read -r common; do
      [ -n "$common" ] && [ -d "$common" ] && GITS --git-dir="$common" worktree prune >/dev/null 2>&1; done
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
      else emit "$cat" refused "$k" remove-failed "$p"; refused=$((refused+1)); fi
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
  # than 6 h is a crashed run and is taken over. The lock is an EMPTY directory this script made: it is
  # released with rmdir (never rm -rf — HYG_LOCK can come from config), a non-empty or non-directory
  # HYG_LOCK is refused untouched, and a takeover re-creates the dir so its mtime restarts.
  if ! /bin/mkdir "$HYG_LOCK" 2>/dev/null; then
    if [ -L "$HYG_LOCK" ] || [ ! -d "$HYG_LOCK" ] || [ -n "$(/bin/ls -A "$HYG_LOCK" 2>/dev/null)" ]; then
      log "=== scheduled run refused: $HYG_LOCK exists and is not an empty lock directory"
      echo "run: HYG_LOCK $HYG_LOCK exists and is not an empty lock directory; refusing" >&2; return 2
    fi
    if [ ! -O "$HYG_LOCK" ]; then   # another user's lock (a shared /tmp): never take it over
      log "=== scheduled run refused: $HYG_LOCK is not owned by this user"
      echo "run: HYG_LOCK $HYG_LOCK is not owned by this user; refusing" >&2; return 2
    fi
    if [ -n "$(/usr/bin/find "$HYG_LOCK" -maxdepth 0 -mmin +360 2>/dev/null)" ]; then
      /bin/rmdir "$HYG_LOCK" 2>/dev/null && /bin/mkdir "$HYG_LOCK" 2>/dev/null \
        || { log "=== scheduled run skipped: could not take over stale lock $HYG_LOCK"; return 0; }
      log "stale lock $HYG_LOCK taken over"
    else log "=== scheduled run skipped: previous run still holds $HYG_LOCK"; return 0; fi
  fi
  trap '/bin/rm -rf "$TMPD"; /bin/rmdir "$HYG_LOCK" 2>/dev/null' EXIT
  log "=== scheduled run"
  /bin/mkdir -p "$HYG_STATE_DIR" 2>/dev/null
  # kept whole: `report` reads why each folder stayed. A plan that cannot be saved stops the run: applying the
  # previous run's plan would make every run a silent no-op on stale rows.
  { plan > "$lp.$$" && /bin/mv -f "$lp.$$" "$lp"; } || { /bin/rm -f "$lp.$$" 2>/dev/null; log "plan failed: cannot write $lp"; return 0; }
  report "$lp" 2>/dev/null | /usr/bin/awk -F'\t' '$1!="kept-over-window"' | while IFS= read -r l; do log "plan-report: $l"; done
  /usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$lp" > "$pf"
  apply "$pf"; }

case "${1:-}" in
  status) status;; plan) plan;; report) report "${2:-}";; apply) apply "${2:?plan file}";; run) run || exit $?;;
  *) echo "usage: hygiene.sh status|plan|report [planfile]|apply <planfile>|run" >&2; exit 2;;
esac
exit 0
