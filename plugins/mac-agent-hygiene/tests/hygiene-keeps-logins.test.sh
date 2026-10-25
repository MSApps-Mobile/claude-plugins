#!/bin/bash
# hygiene-keeps-logins.test.sh — the safety claim in references/safety-model.md, as a test.
#
# A Playwright profile under ~/.cache/playwright-* is a LOGIN. hygiene.sh may remove only the
# regenerable Chromium cache folders inside it. This builds a throwaway HOME with one profile and
# checks, against the REAL scripts/hygiene.sh:
#
#   KNOWN-POSITIVE  `plan` lists the cache folders (Default/Cache, Default/Code Cache, ...) as remove
#   KNOWN-NEGATIVE  `plan` never lists Cookies, Local Storage, IndexedDB, Login Data or Local State
#   KNOWN-NEGATIVE  `apply` REFUSES a hand-written plan line naming one of those login paths
#   KNOWN-NEGATIVE  a profile holding a SingletonLock is kept whole (its caches are not removed)
#   KNOWN-POSITIVE  after `apply` of the real plan the caches are gone and the logins are intact
#
# hygiene.sh calls macOS tools by absolute path (/usr/bin/du, /usr/sbin/lsof, /bin/df), so on any other
# OS this prints SKIP and exits 0. Nothing here touches the real HOME: HOME, XDG_CONFIG_HOME and every
# HYG_* path point inside the fixture.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-test.XXXXXX")" || exit 1
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$HOME"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/.cache/playwright-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }

mkprofile(){  # $1 = profile dir
  local p="$1"
  mkdir -p "$p/Default/Cache" "$p/Default/Code Cache" "$p/Default/GPUCache" "$p/GrShaderCache" \
           "$p/Default/Local Storage" "$p/Default/IndexedDB" "$p/Default/Service Worker/CacheStorage"
  echo cache > "$p/Default/Cache/data_0"; echo cc > "$p/Default/Code Cache/js_0"
  echo gpu > "$p/Default/GPUCache/data_0"; echo sh > "$p/GrShaderCache/data_0"
  echo cs > "$p/Default/Service Worker/CacheStorage/x"
  echo cookies > "$p/Default/Cookies"; echo login > "$p/Default/Login Data"
  echo ls > "$p/Default/Local Storage/leveldb_0"; echo idb > "$p/Default/IndexedDB/db_0"
  echo state > "$p/Local State"
}

PROF="$HOME/.cache/playwright-test"; mkprofile "$PROF"
LOCKED="$HOME/.cache/playwright-locked"; mkprofile "$LOCKED"; ln -s "host-123" "$LOCKED/SingletonLock"

PLAN="$FX/plan.tsv"
bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || { bad "plan exited non-zero: $(cat "$FX/plan.err")"; }

# --- KNOWN-POSITIVE: the caches of the unlocked profile are planned for removal -----------------
for c in "Default/Cache" "Default/Code Cache" "Default/GPUCache" "GrShaderCache" "Default/Service Worker/CacheStorage"; do
  if awk -F'\t' -v p="$PROF/$c" '$1=="browser-caches" && $2=="remove" && $5==p {f=1} END{exit !f}' "$PLAN"; then
    ok "plan lists $c as remove"
  else bad "plan does NOT list $c as remove (known-positive)"; fi
done

# --- KNOWN-NEGATIVE: no login path is ever a candidate, in either profile -----------------------
for l in "Default/Cookies" "Default/Login Data" "Default/Local Storage" "Default/IndexedDB" "Local State"; do
  if awk -F'\t' -v a="$PROF/$l" -v b="$LOCKED/$l" '$5==a || $5==b {f=1} END{exit f}' "$PLAN"; then
    ok "plan never lists $l"
  else bad "plan lists the login path $l"; fi
done
# nothing in plan may sit outside the allowlist, remove or keep
if awk -F'\t' '$5 ~ /\/(Cookies|Login Data|Local Storage|IndexedDB)(\/|$)/ {f=1} END{exit f}' "$PLAN"; then
  ok "no plan row at all names Cookies / Login Data / Local Storage / IndexedDB"
else bad "a plan row names a login path"; fi

# --- KNOWN-NEGATIVE: a SingletonLock profile is kept whole ---------------------------------------
if awk -F'\t' -v d="$LOCKED/" 'index($5,d)==1 && $2=="remove" {f=1} END{exit f}' "$PLAN"; then
  ok "locked profile: no cache is planned for removal"
else bad "locked profile has a cache planned for removal"; fi
if awk -F'\t' -v p="$LOCKED/Default/Cache" '$5==p && $2=="keep" && $4=="profile-has-singleton-lock" {f=1} END{exit !f}' "$PLAN"; then
  ok "locked profile: Default/Cache is kept with reason profile-has-singleton-lock"
else bad "locked profile: Default/Cache is not kept with the lock reason"; fi

# --- KNOWN-NEGATIVE: apply refuses a hand-written plan that names a login path -------------------
EVIL="$FX/evil.tsv"
printf 'browser-caches\t%s\nbrowser-caches\t%s\nbrowser-caches\t%s\nbrowser-caches\t%s\n' \
  "$PROF/Default/Cookies" "$PROF/Default/Login Data" "$PROF/Default/Local Storage" "$PROF/Default/IndexedDB" > "$EVIL"
OUT="$(bash "$HYG" apply "$EVIL" 2>&1)"
if [ -e "$PROF/Default/Cookies" ] && [ -e "$PROF/Default/Login Data" ] && [ -d "$PROF/Default/Local Storage" ] && [ -d "$PROF/Default/IndexedDB" ]; then
  ok "apply of a login-path plan removed nothing"
else bad "apply removed a login path"; fi
if [ "$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="refused"' | wc -l | tr -d ' ')" = 4 ]; then
  ok "apply reports all four login paths as refused"
else bad "apply did not refuse all four login paths: $OUT"; fi

# --- KNOWN-POSITIVE: apply of the REAL plan clears caches and leaves every login intact ----------
awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"
bash "$HYG" apply "$FX/real.tsv" >/dev/null 2>&1
if [ ! -e "$PROF/Default/Cache" ] && [ ! -e "$PROF/GrShaderCache" ]; then ok "apply removed the cache folders"
else bad "apply left a cache folder behind"; fi
if [ -f "$PROF/Default/Cookies" ] && [ -f "$PROF/Default/Login Data" ] && [ -f "$PROF/Local State" ] \
   && [ -f "$PROF/Default/Local Storage/leveldb_0" ] && [ -f "$PROF/Default/IndexedDB/db_0" ]; then
  ok "after apply Cookies, Login Data, Local State, Local Storage and IndexedDB are intact"
else bad "after apply a login file is missing"; fi
if [ -f "$LOCKED/Default/Cache/data_0" ] && [ -f "$LOCKED/Default/Cookies" ]; then ok "locked profile untouched by apply"
else bad "locked profile was modified"; fi

echo "---"; echo "pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
