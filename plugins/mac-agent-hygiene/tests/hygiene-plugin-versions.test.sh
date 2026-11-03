#!/bin/bash
# hygiene-plugin-versions.test.sh — the plugin-versions category of card 2frXvtE1, against the REAL
# scripts/hygiene.sh, with a fixture ~/.claude/plugins/cache and installed_plugins.json.
#
#   KNOWN-POSITIVE  an old, idle, superseded version is planned as remove and apply removes it
#   KNOWN-NEGATIVE  the installed version (old, idle) is kept: installed-version
#   KNOWN-NEGATIVE  the newest 2 by version are kept, and a version with the newest mtime is kept too
#   KNOWN-NEGATIVE  an old version with a file held open by a live process is kept (needs lsof)
#   KNOWN-NEGATIVE  an old version a live process has as its cwd is kept (needs lsof)
#   KNOWN-NEGATIVE  an old dir with a file modified inside the age window is kept: touched-within-age
#   KNOWN-NEGATIVE  a plugin missing from installed_plugins.json is never removed
#   KNOWN-NEGATIVE  temp_git_* clones are not listed as plugin-versions
#   FAIL-CLOSED     unparseable / missing installed_plugins.json, lsof timeout, lsof error, no lsof ⇒ keep
#   FAIL-CLOSED     apply refuses hand-written lines for installed / newest / open versions
#
# Needs jq and perl (prints SKIP without them). Without lsof the open-file and removal cases are
# skipped, but the fail-closed check (no lsof ⇒ keep) still runs. Nothing here touches the real HOME.
# shellcheck disable=SC2015  # ok()/bad() always return 0, so A && ok || bad is safe here
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
for b in /usr/bin/find /usr/bin/du /usr/bin/sort /usr/bin/sed /usr/bin/awk /usr/bin/wc /bin/df /bin/rm /usr/bin/mktemp /usr/bin/perl; do
  [ -x "$b" ] || { echo "SKIP: $b not found"; exit 0; }
done
JQBIN=""; for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq "$(command -v jq 2>/dev/null)"; do [ -n "$c" ] && [ -x "$c" ] && { JQBIN="$c"; break; }; done
[ -n "$JQBIN" ] || { echo "SKIP: jq not found"; exit 0; }
LSOFBIN=""; for c in /usr/sbin/lsof /usr/bin/lsof; do [ -x "$c" ] && { LSOFBIN="$c"; break; }; done
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-pv-test.XXXXXX")" || exit 1
FX="$(cd "$FX" && pwd -P)"
PIDS=""
cleanup(){ local pid; for pid in $PIDS; do kill "$pid" 2>/dev/null; done; rm -rf "$FX"; }
trap cleanup EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
PLUG="$HOME/.claude/plugins"; CACHE="$PLUG/cache"; INST="$PLUG/installed_plugins.json"
mkdir -p "$CACHE"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PW_GLOB="$HOME/pw-none-*"
export HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/code-none" HYG_PLUGIN_CACHE="$CACHE" HYG_JQ="$JQBIN"
export HYG_LSOF_TIMEOUT_S=20
[ -n "$LSOFBIN" ] && export HYG_LSOF="$LSOFBIN"

PASS=0; FAILN=0; SKIPN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
skip(){ SKIPN=$((SKIPN+1)); echo "skip - $1"; }

# ---- fixture ---------------------------------------------------------------------------------------
# acme/demo: 1.0.0 old idle (remove) · 1.0.1 old dir, file touched now · 1.1.0 old, file held open
#            1.1.5 old, a process's cwd · 1.2.0 installed · 1.3.0 + 1.4.0 newest by version
#            0.9.0 lowest version but newest mtime
# acme/ghost: not in installed_plugins.json — three old versions, all kept
# temp_git_123/x/y: an install clone, not a plugin version
D="$CACHE/acme/demo"
mkv(){ mkdir -p "$1/bin"; echo "#!/bin/sh" > "$1/bin/run"; echo '{"name":"x"}' > "$1/plugin.json"; }
for v in 0.9.0 1.0.0 1.0.1 1.1.0 1.1.5 1.2.0 1.3.0 1.4.0; do mkv "$D/$v"; done
for v in 1.0.0 1.1.0 1.2.0; do mkv "$CACHE/acme/ghost/$v"; done
mkv "$CACHE/temp_git_123/x/y"
stamp(){ find "$1" -exec touch -t "$2" {} +; }
stamp "$D/1.0.0" 202001010000; stamp "$D/1.0.1" 202001010100; stamp "$D/1.1.0" 202001020000
stamp "$D/1.1.5" 202001020100; stamp "$D/1.2.0" 202001030000; stamp "$D/1.3.0" 202001040000
stamp "$D/1.4.0" 202001050000; stamp "$D/0.9.0" 202101010000
stamp "$CACHE/acme/ghost" 202001010000; stamp "$CACHE/temp_git_123" 202001010000
touch "$D/1.0.1/plugin.json"   # a file inside touched now; the dir mtime stays old

cat > "$INST" <<EOF
{"version": 2, "plugins": {
  "demo@acme": [{"scope": "user", "installPath": "$D/1.2.0", "version": "1.2.0"}],
  "other@elsewhere": [{"scope": "user", "installPath": "$CACHE/elsewhere/other/3.0.0", "version": "3.0.0"}]
}}
EOF

PLAN="$FX/plan.tsv"
runplan(){ bash "$HYG" plan > "$PLAN" 2>"$FX/plan.err" || bad "plan exited non-zero: $(cat "$FX/plan.err")"; }
row(){ awk -F'\t' -v p="$1" '$1=="plugin-versions" && $5==p {print $2" "$4}' "$PLAN"; }
expect(){ local got; got="$(row "$1")"
  if [ "$got" = "$2" ]; then ok "$3: $2"; else bad "$3: expected '$2', got '${got:-<not listed>}'"; fi; }

# ---- 1. normal plan, real lsof ----------------------------------------------------------------------
if [ -n "$LSOFBIN" ]; then
  ( exec 9<"$D/1.1.0/plugin.json"; exec sleep 300 ) & PIDS="$PIDS $!"
  ( cd "$D/1.1.5" && exec sleep 300 ) & PIDS="$PIDS $!"
  sleep 1
fi
runplan
expect "$D/1.2.0" "keep installed-version"       "installed version"
expect "$D/1.3.0" "keep newest-2"                "2nd-newest by version"
expect "$D/1.4.0" "keep newest-2"                "newest by version"
expect "$D/0.9.0" "keep newest-2"                "lowest version with the newest mtime"
expect "$D/1.0.1" "keep touched-within-age"      "old dir with a file touched inside the window"
for v in 1.0.0 1.1.0 1.2.0; do expect "$CACHE/acme/ghost/$v" "keep plugin-not-in-installed-list" "ghost/$v"; done
[ -z "$(awk -F'\t' '$1=="plugin-versions" && index($5,"/temp_git_")' "$PLAN")" ] && ok "temp_git_* clones not listed as plugin-versions" \
  || bad "a temp_git_* path was listed as plugin-versions"
if [ -n "$LSOFBIN" ]; then
  expect "$D/1.0.0" "remove superseded-plugin-version" "old idle superseded version"
  expect "$D/1.1.0" "keep open-by-live-process"         "old version with an open file"
  got="$(row "$D/1.1.5")"
  case "$got" in "keep a-process-is-inside"|"keep open-by-live-process") ok "old version that is a process cwd: $got";;
    *) bad "process cwd version: expected keep, got '${got:-<not listed>}'";; esac
  n="$(awk -F'\t' '$1=="plugin-versions" && $2=="remove"' "$PLAN" | wc -l | tr -d ' ')"
  [ "$n" = 1 ] && ok "exactly one plugin-versions removal planned" || bad "expected 1 removal, got $n"
else
  skip "lsof not found: open-file, cwd and removal cases"
fi

# ---- 2. fail closed ---------------------------------------------------------------------------------
cp "$INST" "$FX/inst.good"
printf '{"version": 2, "plugins": ' > "$INST"; runplan
expect "$D/1.0.0" "keep installed-list-unparseable" "truncated installed_plugins.json"
echo '{"version": 2, "plugins": []}' > "$INST"; runplan
expect "$D/1.0.0" "keep installed-list-unparseable" "plugins is not an object"
rm -f "$INST"; runplan
expect "$D/1.0.0" "keep installed-list-unreadable" "missing installed_plugins.json"
cp "$FX/inst.good" "$INST"
HYG_JQ="$FX/no-such-jq" runplan
expect "$D/1.0.0" "keep installed-list-no-jq" "no jq"

mkdir -p "$FX/bin"
printf '#!/bin/sh\nexec sleep 30\n' > "$FX/bin/lsof-hang"
# shellcheck disable=SC2016  # $4 belongs to the stub script
printf '#!/bin/sh\necho "lsof: status error on $4: Permission denied" >&2\nexit 1\n' > "$FX/bin/lsof-err"
printf '#!/bin/sh\necho 4242\nexit 0\n' > "$FX/bin/lsof-busy"
chmod +x "$FX/bin/"lsof-*
HYG_LSOF="$FX/bin/lsof-hang" HYG_LSOF_TIMEOUT_S=1 runplan
expect "$D/1.0.0" "keep lsof-timeout"          "lsof that hangs past the alarm"
HYG_LSOF="$FX/bin/lsof-err" runplan
expect "$D/1.0.0" "keep lsof-error"            "lsof that errors"
HYG_LSOF="$FX/bin/lsof-busy" runplan
expect "$D/1.0.0" "keep open-by-live-process"  "stub lsof reporting a pid"
HYG_LSOF="$FX/no-such-lsof" runplan
expect "$D/1.0.0" "keep lsof-unavailable"      "no lsof"

# ---- 3. apply refuses hand-written lines, then removes exactly the planned version ------------------
printf 'plugin-versions\t%s\n' "$D/1.2.0" "$D/1.4.0" "$D/1.1.0" "$CACHE/acme/ghost/1.0.0" > "$FX/evil.tsv"
OUT="$(HYG_LSOF="${LSOFBIN:-$FX/no-such-lsof}" bash "$HYG" apply "$FX/evil.tsv" 2>&1)"
n="$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="refused"' | wc -l | tr -d ' ')"
[ "$n" = 4 ] && ok "apply refuses installed / newest / open / unlisted-plugin lines" || bad "apply did not refuse all four: $OUT"
for v in 1.2.0 1.4.0 1.1.0; do [ -d "$D/$v" ] && ok "kept $v" || bad "removed $v"; done
if [ -n "$LSOFBIN" ]; then
  runplan
  awk -F'\t' '$2=="remove"{print $1"\t"$5}' "$PLAN" > "$FX/real.tsv"
  bash "$HYG" apply "$FX/real.tsv" > "$FX/apply.out" 2>&1
  [ ! -e "$D/1.0.0" ] && ok "apply removed 1.0.0" || bad "1.0.0 still present: $(cat "$FX/apply.out")"
  for v in 0.9.0 1.0.1 1.1.0 1.1.5 1.2.0 1.3.0 1.4.0; do [ -d "$D/$v" ] && ok "kept $v after apply" || bad "removed $v"; done
  [ -d "$CACHE/acme/ghost/1.0.0" ] && ok "unlisted plugin's versions intact" || bad "ghost/1.0.0 removed"
  ! awk -F'\t' '$1=="plugin-versions"' "$FX/apply.out" | grep -q temp_git_ && ok "plugin-versions apply never touched temp_git_*" \
    || bad "plugin-versions apply touched temp_git_*"
else
  skip "lsof not found: real apply"
fi

echo "---"; echo "pass=$PASS fail=$FAILN skip=$SKIPN"
[ "$FAILN" = 0 ]
