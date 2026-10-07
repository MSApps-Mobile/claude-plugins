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
#
# Config: ~/.config/mac-agent-hygiene/config.env (optional). Environment variables win over the
# config file, so an MCP call can override one value for one run.
# Never sudo. Never /System, /Library, ~/Library/Application Support, keychains, mail, ~/.ssh.
set -u
umask 077

# ---------- configuration: defaults < config file < environment ----------
VARS="HYG_LOG HYG_DERIVED_DATA HYG_PLUGIN_CACHE HYG_PLUGIN_CLONE_MIN_AGE_MIN HYG_PW_GLOB HYG_MODEL_CACHES HYG_MODEL_CACHE_AGE_DAYS HYG_WT_ROOT HYG_WT_GLOB HYG_WT_AGE_DAYS HYG_WT_MERGED_PR_CHECK HYG_GIT HYG_GH"
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
HYG_DERIVED_DATA="${HYG_DERIVED_DATA%/}"; HYG_PLUGIN_CACHE="${HYG_PLUGIN_CACHE%/}"
case "$HYG_WT_AGE_DAYS$HYG_MODEL_CACHE_AGE_DAYS$HYG_PLUGIN_CLONE_MIN_AGE_MIN" in *[!0-9]*) echo "age settings must be integers" >&2; exit 2;; esac

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
has_dot_component(){ case "/$1/" in */./*|*/../*) return 0;; esac; return 1; }
# Every process's cwd, read ONCE per run; compared as fixed strings (never as a pattern).
CWDS=""; load_cwds(){ [ -n "$CWDS" ] || CWDS=$(/usr/sbin/lsof -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p'); }
cwd_inside(){ local c; load_cwds
  while IFS= read -r c; do [ -n "$c" ] || continue; [ "$c" = "$1" ] && return 0; case "$c" in "$1"/*) return 0;; esac; done <<< "$CWDS"; return 1; }
TMPD=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mac-agent-hygiene.XXXXXX") || { echo "mktemp failed" >&2; exit 2; }
trap '/bin/rm -rf "$TMPD"' EXIT

# ---------- enumerators (shared by status, plan and the candidate list) ----------
list_worktrees(){ [ -d "$HYG_WT_ROOT" ] && /usr/bin/find "$HYG_WT_ROOT" -maxdepth 1 -mindepth 1 -type d -name "$HYG_WT_GLOB" 2>/dev/null | /usr/bin/sort; }
list_clones(){ [ -d "$HYG_PLUGIN_CACHE" ] && /usr/bin/find "$HYG_PLUGIN_CACHE" -maxdepth 1 -mindepth 1 -type d -name 'temp_git_*' 2>/dev/null | /usr/bin/sort; }
list_profiles(){ local p; for p in $HYG_PW_GLOB; do [ -d "$p" ] && printf '%s\n' "$p"; done; }
wt_recently_touched(){  # any regular file (outside .git) newer than the age → touched
  [ -n "$(/usr/bin/find "$1" -path '*/.git' -prune -o -type f -mtime -"$HYG_WT_AGE_DAYS" -print -quit 2>/dev/null)" ] ||
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
check_worktree(){ local d="$1" b h repo f st
  [ "$(dirname "$d")" = "$HYG_WT_ROOT" ] || { REASON=outside-worktree-root; return 1; }
  case "$(basename "$d")" in $HYG_WT_GLOB) ;; *) REASON=name-does-not-match-glob; return 1;; esac
  [ -f "$d/.git" ] || { REASON=not-a-linked-worktree; return 1; }        # a full clone has a .git DIR — left alone
  wt_recently_touched "$d" && { REASON=touched-recently; return 1; }
  cwd_inside "$d" && { REASON=a-process-is-inside; return 1; }
  st=$("$GIT" -C "$d" status --porcelain 2>/dev/null) || { REASON=git-status-failed; return 1; }
  [ -z "$st" ] || { REASON=dirty-uncommitted-work; return 1; }
  h=$("$GIT" -C "$d" rev-parse HEAD 2>/dev/null) || { REASON=no-head; return 1; }
  if [ -n "$("$GIT" -C "$d" branch -r --contains "$h" 2>/dev/null | /usr/bin/head -1)" ]; then REASON=pushed; return 0; fi
  if [ "$HYG_WT_MERGED_PR_CHECK" = 1 ] && [ -n "$GH" ]; then
    b=$("$GIT" -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    repo=$("$GIT" -C "$d" remote get-url origin 2>/dev/null | /usr/bin/sed -E 's#.*github.com[:/]##; s#\.git$##')
    if [ -n "$repo" ]; then
      f="$TMPD/$(echo "$repo" | tr / _)"
      [ -f "$f" ] || "$GH" pr list --repo "$repo" --state merged --limit 3000 --json headRefName,headRefOid \
          --jq '.[] | "\(.headRefName) \(.headRefOid)"' > "$f" 2>/dev/null || : > "$f"   # gh failure ⇒ empty ⇒ KEEP
      /usr/bin/grep -qxF "$b $h" "$f" && { REASON=merged-pr-head; return 0; }
    fi
  fi
  REASON=unpushed-commits; return 1; }

check_item(){ # category path → 0 removable (REASON=why) / 1 keep (REASON=why)
  case "$2" in "$HOME"/*) ;; *) REASON=outside-home; return 1;; esac
  has_dot_component "$2" && { REASON=dot-component-in-path; return 1; }
  case "$1" in
    derived-data) check_derived "$2";; plugin-clones) check_clone "$2";; browser-caches) check_pwcache "$2";;
    model-caches) check_model "$2";; worktrees) check_worktree "$2";; *) REASON=unknown-category; return 1;; esac; }

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
}

plan(){ local cat p k
  while IFS=$'\t' read -r cat p; do
    [ -n "$p" ] || continue; k=$(kb "$p"); [ -n "$k" ] || k=0
    if check_item "$cat" "$p"; then emit "$cat" remove "$k" "$REASON" "$p"; else emit "$cat" keep "$k" "$REASON" "$p"; fi
  done < <(candidates)
}

remove_item(){ local cat="$1" p="$2" common
  if [ "$cat" = worktrees ]; then
    common=$("$GIT" -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    "$GIT" -C "$p" worktree remove "$p" >>"$HYG_LOG" 2>&1 || return 1
    [ -n "$common" ] && "$GIT" --git-dir="$common" worktree prune >/dev/null 2>&1
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
  printf 'xcode_building\t%s\n' "$(xcode_building && echo yes || echo no)"
  printf 'gh\t%s\ngit\t%s\n' "${GH:-not-found}" "$GIT"
  printf 'cleanup_period_days\t%s\n' "$(/usr/bin/grep -o '"cleanupPeriodDays": *[0-9]*' "$HOME/.claude/settings.json" 2>/dev/null | /usr/bin/grep -o '[0-9]*$' || echo default-30)"
  printf 'launchagent\t%s\n' "$(/bin/launchctl print "gui/$(id -u)/com.msapps.mac-agent-hygiene" >/dev/null 2>&1 && echo loaded || echo not-loaded)"
  printf 'log\t%s\n' "$HYG_LOG"
  [ -f "$HYG_LOG" ] && /usr/bin/tail -5 "$HYG_LOG" | while IFS= read -r l; do printf 'log_tail\t%s\n' "$l"; done
}

run(){ local pf="$TMPD/plan.tsv"
  log "=== scheduled run"
  plan | /usr/bin/awk -F'\t' '$2=="remove"{print $1"\t"$5}' > "$pf"
  apply "$pf"; }

case "${1:-}" in
  status) status;; plan) plan;; apply) apply "${2:?plan file}";; run) run;;
  *) echo "usage: hygiene.sh status|plan|apply <planfile>|run" >&2; exit 2;;
esac
exit 0
