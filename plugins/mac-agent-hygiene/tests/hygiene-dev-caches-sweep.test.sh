#!/bin/bash
# hygiene-dev-caches-sweep.test.sh — the dev-caches category (what /mac-cleanup cleared by hand every run),
# against the REAL scripts/hygiene.sh in a throwaway HOME:
#
#   KNOWN-POSITIVE  an idle entry inside a listed cache root (pip, npm _cacache, Chrome) is planned remove and removed
#   KNOWN-NEGATIVE  an entry with a file written within HYG_DEV_CACHE_IDLE_HOURS is kept (used-recently)
#   KNOWN-POSITIVE  an idle ~/Library/Caches/com.*.ShipIt leftover is removed
#   KNOWN-NEGATIVE  ~/.npm/_npx, a playwright profile and an unlisted ~/Library/Caches dir are never candidates
#   KNOWN-NEGATIVE  the cache ROOT itself is never removed, only its entries
#   KNOWN-NEGATIVE  a symlinked entry is kept
#   KNOWN-POSITIVE  the uv cache is pruned through `uv cache prune` (a fake uv records the call), never rm'd
#   KNOWN-NEGATIVE  ~/.gradle/caches entries are kept while a Gradle daemon runs
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-devc.XXXXXX")" || exit 1
GPID=""; trap '[ -n "$GPID" ] && kill "$GPID" 2>/dev/null; rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"; mkdir -p "$HOME"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/.cache/playwright-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none" HYG_WT_NESTED=""
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/lock"
export HYG_SESSION_ROOT="$HOME/code/wt" HYG_GRADLE_HOME="$HOME/.gradle" HYG_SESSIONS_JSON="$FX/none.json"
export HYG_DEVICE_SUPPORT="$HOME/ds" HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/.android" HYG_PKG_CACHES=""
PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
act(){ /usr/bin/awk -F'\t' -v p="$1" '$5==p{print $2"/"$4}' "$FX/plan.tsv"; }
C="$HOME/Library/Caches"
mkdir -p "$C/pip/http" "$C/pip/wheels" "$HOME/.npm/_cacache/content-v2" "$HOME/.npm/_npx/abc" "$C/Google/Chrome" \
  "$C/com.example.app.ShipIt" "$C/unlisted/x" "$HOME/.cache/playwright-li/Default/Cache" "$HOME/.gradle/caches/modules-2" "$FX/elsewhere"
for d in "$C/pip/http" "$C/pip/wheels" "$HOME/.npm/_cacache/content-v2" "$HOME/.npm/_npx/abc" "$C/Google/Chrome" "$C/com.example.app.ShipIt" \
  "$C/unlisted/x" "$HOME/.gradle/caches/modules-2" "$FX/elsewhere"; do echo data > "$d/f"; done
ln -s "$FX/elsewhere" "$C/pip/linked"
old "$HOME"; echo fresh > "$C/pip/wheels/new.whl"          # wheels written now
mkdir -p "$HOME/.cache/uv/archive-v0"; echo u > "$HOME/.cache/uv/archive-v0/x"
cat > "$FX/uv" <<FAKE
#!/bin/bash
case "\$1 \$2" in "cache dir") echo "$HOME/.cache/uv";; "cache prune") echo "\$UV_LOCK_TIMEOUT \$*" >> "$FX/uv-calls"; rm -rf "$HOME/.cache/uv/archive-v0";; *) exit 1;; esac
FAKE
chmod +x "$FX/uv"; export HYG_UV="$FX/uv"

bash "$HYG" plan > "$FX/plan.tsv" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"
case "$(act "$C/pip/http")" in remove/regenerable-dev-cache) ok "idle pip entry → remove";; *) bad "pip/http: $(act "$C/pip/http")";; esac
case "$(act "$HOME/.npm/_cacache/content-v2")" in remove/*) ok "idle npm _cacache entry → remove";; *) bad "npm: $(act "$HOME/.npm/_cacache/content-v2")";; esac
case "$(act "$C/Google/Chrome")" in remove/*) ok "idle Chrome disk cache → remove";; *) bad "chrome: $(act "$C/Google/Chrome")";; esac
case "$(act "$C/pip/wheels")" in keep/used-recently) ok "recently written entry → keep";; *) bad "wheels: $(act "$C/pip/wheels")";; esac
case "$(act "$C/com.example.app.ShipIt")" in remove/*) ok "idle ShipIt leftover → remove";; *) bad "shipit: $(act "$C/com.example.app.ShipIt")";; esac
case "$(act "$C/pip/linked")" in keep/*) ok "symlinked entry → keep";; *) bad "symlink: $(act "$C/pip/linked")";; esac
case "$(act "$HOME/.cache/uv")" in remove/uv-cache-prune-unused-only) ok "uv cache → prune planned";; *) bad "uv: $(act "$HOME/.cache/uv")";; esac
for n in "$HOME/.npm/_npx" "$HOME/.npm/_npx/abc" "$C/unlisted" "$C/unlisted/x" "$C/pip" "$HOME/.npm/_cacache" "$HOME/.cache/playwright-li"; do
  /usr/bin/awk -F'\t' -v p="$n" '$1=="dev-caches" && $5==p{f=1} END{exit f}' "$FX/plan.tsv" && ok "never a dev-caches candidate: ${n#$HOME/}" || bad "candidate: $n"; done

(exec -a GradleDaemon sleep 300) & GPID=$!; sleep 1
bash "$HYG" plan > "$FX/plan-g.tsv" 2>/dev/null
/usr/bin/awk -F'\t' -v p="$HOME/.gradle/caches/modules-2" '$5==p && $2=="keep" && $4=="gradle-running"{f=1} END{exit !f}' "$FX/plan-g.tsv" \
  && ok "gradle cache entry kept while a Gradle daemon runs" || bad "gradle: $(grep modules-2 "$FX/plan-g.tsv")"
kill "$GPID" 2>/dev/null; wait "$GPID" 2>/dev/null; GPID=""

/usr/bin/awk -F'\t' '$1=="dev-caches" && $2=="remove"{print $1"\t"$5}' "$FX/plan.tsv" > "$FX/apply.tsv"
bash "$HYG" apply "$FX/apply.tsv" > "$FX/apply.out" 2>&1
[ ! -e "$C/pip/http" ] && [ ! -e "$HOME/.npm/_cacache/content-v2" ] && [ ! -e "$C/com.example.app.ShipIt" ] && ok "apply removed the idle entries" || bad "apply left: $(ls "$C/pip" "$HOME/.npm/_cacache")"
[ -d "$C/pip" ] && [ -d "$HOME/.npm/_cacache" ] && [ -f "$C/pip/wheels/new.whl" ] && [ -f "$FX/elsewhere/f" ] && [ -f "$HOME/.npm/_npx/abc/f" ] && [ -f "$C/unlisted/x/f" ] \
  && ok "roots, recent entries, symlink target, _npx and unlisted caches survive" || bad "something collateral was removed"
[ -d "$HOME/.cache/uv" ] && grep -q '^15 cache prune' "$FX/uv-calls" 2>/dev/null && ! grep -q -- --force "$FX/uv-calls" \
  && ok "uv: pruned via 'uv cache prune' with a 15 s lock wait, dir kept, no --force" || bad "uv calls: $(cat "$FX/uv-calls" 2>/dev/null)"
echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
