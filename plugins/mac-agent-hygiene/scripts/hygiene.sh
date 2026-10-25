#!/bin/bash
# mac-agent-hygiene — keeps a Mac that runs Claude Code agents from filling its disk.
#
#   hygiene.sh status            key<TAB>value lines (read-only)
#   hygiene.sh plan              category<TAB>action<TAB>kb<TAB>reason<TAB>path  (read-only dry run)
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
#   session-dirs     plain (non-git) agent session folders directly under HYG_SESSION_ROOT (~/code/wt):
#                    nothing touched for HYG_SESSION_AGE_HOURS, nobody's cwd, and EVERY git repo or
#                    worktree nested inside is clean and pushed (same test as worktrees). One dirty or
#                    unpushed nested repo keeps the whole folder.
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
VARS="HYG_LOG HYG_DERIVED_DATA HYG_PLUGIN_CACHE HYG_PLUGIN_CLONE_MIN_AGE_MIN HYG_PW_GLOB HYG_MODEL_CACHES HYG_MODEL_CACHE_AGE_DAYS HYG_WT_ROOT HYG_WT_GLOB HYG_WT_ROOTS HYG_WT_AGE_DAYS HYG_WT_MERGED_PR_CHECK HYG_GH_SHA_CHECK_MAX HYG_GIT HYG_GH HYG_SESSION_ROOT HYG_SESSION_AGE_HOURS HYG_GRADLE_HOME HYG_GRADLE_AGE_DAYS HYG_DEVICE_SUPPORT HYG_DEVICE_SUPPORT_AGE_DAYS HYG_SIM_DEVICES HYG_ANDROID_HOME HYG_ANDROID_CACHE_AGE_DAYS HYG_ANDROID_SDK HYG_PKG_CACHES HYG_PKG_CACHE_AGE_DAYS HYG_LOCK"
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
case "$HYG_WT_AGE_DAYS$HYG_MODEL_CACHE_AGE_DAYS$HYG_PLUGIN_CLONE_MIN_AGE_MIN$HYG_SESSION_AGE_HOURS$HYG_GRADLE_AGE_DAYS$HYG_DEVICE_SUPPORT_AGE_DAYS$HYG_ANDROID_CACHE_AGE_DAYS$HYG_PKG_CACHE_AGE_DAYS$HYG_GH_SHA_CHECK_MAX" in *[!0-9]*) echo "age settings must be integers" >&2; exit 2;; esac

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
xcode_building(){ /usr/bin/pgrep -qx xcodebuild || /usr/bin/pgrep -qx Xcode || /usr/bin/pgrep -qx XCBBuildService; }
simulator_running(){ /usr/bin/pgrep -qx Simulator || /usr/bin/pgrep -qf 'CoreSimulator/.*launchd_sim'; }
older_than_days(){ [ -n "$(/usr/bin/find "$1" -maxdepth 0 -mtime +"$2" 2>/dev/null)" ]; }
has_dot_component(){ case "/$1/" in */./*|*/../*) return 0;; esac; return 1; }
# Every process's cwd, read ONCE per run; compared as fixed strings (never as a pattern).
CWDS=""; load_cwds(){ [ -n "$CWDS" ] || CWDS=$(/usr/sbin/lsof -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p'); }
cwd_inside(){ local c; load_cwds
  while IFS= read -r c; do [ -n "$c" ] || continue; [ "$c" = "$1" ] && return 0; case "$c" in "$1"/*) return 0;; esac; done <<< "$CWDS"; return 1; }
TMPD=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mac-agent-hygiene.XXXXXX") || { echo "mktemp failed" >&2; exit 2; }
trap '/bin/rm -rf "$TMPD"' EXIT

# ---------- enumerators (shared by status, plan and the candidate list) ----------
list_worktrees(){ local pair r g
  for pair in $HYG_WT_ROOTS; do r="${pair%%:*}"; r="${r%/}"; g="${pair#*:}"
    [ -d "$r" ] && /usr/bin/find "$r" -maxdepth 1 -mindepth 1 -type d -name "$g" 2>/dev/null
  done | /usr/bin/sort -u | while IFS= read -r d; do [ -f "$d/.git" ] && printf '%s\n' "$d"; done; }
wt_root_glob_ok(){ local pair r g; for pair in $HYG_WT_ROOTS; do r="${pair%%:*}"; r="${r%/}"; g="${pair#*:}"
    [ "$(dirname "$1")" = "$r" ] || continue; case "$(basename "$1")" in $g) return 0;; esac; done; return 1; }
list_sessions(){ [ -d "$HYG_SESSION_ROOT" ] && /usr/bin/find "$HYG_SESSION_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | /usr/bin/sort |
  while IFS= read -r d; do [ -e "$d/.git" ] || printf '%s\n' "$d"; done; }
# Every .git at any depth, nothing pruned: a repo the search skipped would be rm -rf'd unchecked, so the
# search fails closed (slower on a big node_modules, which only runs on folders already idle 24 h).
nested_repos(){ /usr/bin/find "$1" -mindepth 2 -name .git -print 2>/dev/null | /usr/bin/sed 's#/\.git$##'; }
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
      inuse "$prof" && { REASON=profile-in-use; return 1; }
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
  git_safe "$d" "$d"; }
# git run on repos an agent made: repo-local config must not be able to run a command while we only
# look (core.fsmonitor and hooks are the command-executing keys `status` would honour).
GITS(){ GIT_CONFIG_NOSYSTEM=1 "$GIT" --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null \
  -c core.untrackedCache=false -c diff.external= -c core.pager=cat "$@"; }
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
git_safe(){ # repo/worktree dir, deletion boundary (the dir apply would rm) → 0 clean and on a remote ref or merged-PR head (REASON=pushed|merged-pr-head)
  local d="$1" bound="${2:-$1}" b h repo f st br cdir rc rb wg
  repo_config_runs_commands "$d" && { REASON=repo-config-can-run-commands; return 1; }
  # status recurses into submodules under THEIR config, which the scan above never read: keep, unread.
  { [ -e "$d/.gitmodules" ] || [ -d "$(GITS -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/modules" ] \
    || [ -d "$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)/modules" ] \
    || GITS -C "$d" ls-files -s 2>/dev/null | /usr/bin/awk '$1=="160000"{f=1} END{exit !f}'; } \
    && { REASON=has-submodules; return 1; }   # gitlinks found by index mode 160000, not only by .gitmodules
  st=$(GITS -C "$d" -c diff.ignoreSubmodules=all status --porcelain --ignore-submodules=all 2>/dev/null) || { REASON=git-status-failed; return 1; }
  [ -z "$st" ] || { REASON=dirty-uncommitted-work; return 1; }
  # owner/name only from an anchored github.com URL; anything else ⇒ empty ⇒ no gh call ⇒ KEEP
  repo=$(GITS -C "$d" remote get-url origin 2>/dev/null | /usr/bin/sed -nE 's#^(https://|ssh://git@|git@)github\.com[:/]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$#\2#p' | /usr/bin/sed -E 's#\.git$##')
  case "$repo" in *..*|.*|*/.*) repo="";; esac
  if [ -d "$d/.git" ]; then   # a full clone owns its stash and every local branch; a linked worktree shares them with its parent
    [ -z "$(GITS -C "$d" stash list 2>/dev/null)" ] || { REASON=clone-has-stash; return 1; }
    while IFS= read -r br; do [ -n "$br" ] || continue
      [ -n "$(GITS -C "$d" branch -r --contains "$br" 2>/dev/null | /usr/bin/head -1)" ] || in_github_default "$repo" "$br" \
        || { REASON=clone-has-unpushed-branch; return 1; }
    done < <(GITS -C "$d" for-each-ref --format='%(objectname)' refs/heads 2>/dev/null)
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
    rc=$(cd -P -- "$cdir" 2>/dev/null && pwd -P); rb=$(cd -P -- "$bound" 2>/dev/null && pwd -P)
    wg=$(GITS -C "$d" rev-parse --path-format=absolute --git-dir 2>/dev/null)
    if [ -n "$rc" ] && [ -n "$rb" ] && case "$rc/" in "$rb"/*) false;; *) true;; esac \
       && case "$wg" in "$cdir"/worktrees/*) true;; *) false;; esac \
       && [ "$(cd -P -- "$(/usr/bin/dirname "$(/bin/cat "$wg/gitdir" 2>/dev/null)")" 2>/dev/null && pwd -P)" = "$(cd -P -- "$d" && pwd -P)" ] \
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

check_session(){ local d="$1" r
  [ "$(dirname "$d")" = "$HYG_SESSION_ROOT" ] || { REASON=outside-session-root; return 1; }
  [ -e "$d/.git" ] && { REASON=is-a-git-repo; return 1; }
  [ -n "$(/usr/bin/find "$d" \( -name .git -o -name node_modules -o -name .venv -o -name Pods \) -prune -o -type f -mmin -"$((HYG_SESSION_AGE_HOURS*60))" -print -quit 2>/dev/null)" ] && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  # nested_repos only finds `.git`; a bare repo or separate git-dir elsewhere in the folder would go
  # with the rm unchecked. Any HEAD file outside a .git path ⇒ keep the folder, unread.
  [ -n "$(/usr/bin/find "$d" -path '*/.git' -prune -o -type f -name HEAD -print -quit 2>/dev/null)" ] \
    && { REASON=contains-bare-or-separate-git-dir; return 1; }
  while IFS= read -r r; do [ -n "$r" ] || continue
    git_safe "$r" "$d" || { REASON="nested-$REASON"; return 1; }
  done < <(nested_repos "$d")
  REASON=stale-session-all-nested-pushed; return 0; }
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

check_item(){ # category path → 0 removable (REASON=why) / 1 keep (REASON=why)
  case "$2" in "$HOME"/*) ;; *) REASON=outside-home; return 1;; esac
  has_dot_component "$2" && { REASON=dot-component-in-path; return 1; }
  case "$1" in
    derived-data) check_derived "$2";; plugin-clones) check_clone "$2";; browser-caches) check_pwcache "$2";;
    model-caches) check_model "$2";; worktrees) check_worktree "$2";; session-dirs) check_session "$2";;
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
  list_worktrees | while IFS= read -r d; do printf 'worktrees\t%s\n' "$d"; done
  list_sessions | while IFS= read -r d; do printf 'session-dirs\t%s\n' "$d"; done
  for d in "$HYG_GRADLE_HOME/wrapper/dists"/*/ "$HYG_GRADLE_HOME/daemon"/*/; do [ -d "$d" ] && printf 'gradle\t%s\n' "${d%/}"; done
  for d in "$HYG_DEVICE_SUPPORT"/*/; do [ -d "$d" ] && printf 'ios\t%s\n' "${d%/}"; done
  [ -x /usr/bin/xcrun ] && sim_unavailable_udids | while IFS= read -r u; do [ -d "$HYG_SIM_DEVICES/$u" ] && printf 'ios\t%s\n' "$HYG_SIM_DEVICES/$u"; done
  for d in "$HYG_ANDROID_HOME/cache"/*; do [ -e "$d" ] && printf 'android\t%s\n' "$d"; done
  for d in $HYG_PKG_CACHES; do [ -d "$d" ] && printf 'pkg-caches\t%s\n' "${d%/}"; done
}

plan(){ local cat p k prev="" n=0 r=0 t0=$SECONDS
  # One log line per category as it finishes (card ugCwRX0v), so a slow or stuck plan is visible
  # from `log_tail` / hygiene_status instead of a silent gap after "=== scheduled run".
  plan_mark(){ [ -n "$prev" ] && log "plan: $prev $n candidates ($r remove) in $((SECONDS-t0))s"; }
  while IFS=$'\t' read -r cat p; do
    [ -n "$p" ] || continue
    if [ "$cat" != "$prev" ]; then plan_mark; prev="$cat"; n=0; r=0; t0=$SECONDS; fi
    n=$((n+1)); k=$(kb "$p"); [ -n "$k" ] || k=0
    if check_item "$cat" "$p"; then r=$((r+1)); emit "$cat" remove "$k" "$REASON" "$p"; else emit "$cat" keep "$k" "$REASON" "$p"; fi
  done < <(candidates)
  plan_mark
}

remove_item(){ local cat="$1" p="$2" common r commons=""
  if [ "$cat" = worktrees ]; then
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

run(){ local pf="$TMPD/plan.tsv"
  # Runs every few hours: a slow run must never overlap the next one. mkdir is atomic; a lock older
  # than 6 h is a crashed run and is taken over.
  if ! /bin/mkdir "$HYG_LOCK" 2>/dev/null; then
    if [ -n "$(/usr/bin/find "$HYG_LOCK" -maxdepth 0 -mmin +360 2>/dev/null)" ]; then
      log "stale lock $HYG_LOCK taken over"; else log "=== scheduled run skipped: previous run still holds $HYG_LOCK"; return 0; fi
  fi
  trap '/bin/rm -rf "$TMPD" "$HYG_LOCK"' EXIT
  log "=== scheduled run"
  plan | /usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' > "$pf"
  apply "$pf"; }

case "${1:-}" in
  status) status;; plan) plan;; apply) apply "${2:?plan file}";; run) run;;
  *) echo "usage: hygiene.sh status|plan|apply <planfile>|run" >&2; exit 2;;
esac
exit 0
