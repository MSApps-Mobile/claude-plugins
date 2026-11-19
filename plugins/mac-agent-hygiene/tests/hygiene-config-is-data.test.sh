#!/bin/bash
# hygiene-config-is-data.test.sh — config.env is DATA, never run (Giora outside review 2026-11-05, finding 3).
#
# The LaunchAgent runs hygiene.sh hourly and it holds `rm -rf`. It used to `. "$CONF"`, so any process that
# could write ~/.config/mac-agent-hygiene/config.env got code execution inside the cleaner. Against the REAL
# scripts/hygiene.sh, under /bin/bash (macOS bash 3.2, what launchd runs):
#
#   KNOWN-NEGATIVE  a bare command line in config.env does not run (canary file never appears)
#   KNOWN-NEGATIVE  KEY=$(cmd) and KEY=`cmd` do not run, and are refused on stderr
#   KNOWN-NEGATIVE  a key outside the HYG_ settings is ignored (named on stderr)
#   KNOWN-POSITIVE  a plain HYG_ value is still read: HYG_WT_AGE_DAYS=abc makes the script exit 2
#                   ("age settings must be integers"), which proves the file was loaded
#   KNOWN-POSITIVE  quoted values and `export KEY=...` are read the same way
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="$HERE/../scripts/hygiene.sh"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
[ -f "$HYG" ] || { echo "FAIL: $HYG not found"; exit 1; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-conf.XXXXXX")" || exit 1
trap 'rm -rf "$FX"' EXIT
export HOME="$FX/home" XDG_CONFIG_HOME="$FX/home/.config"
mkdir -p "$XDG_CONFIG_HOME/mac-agent-hygiene"
CONF="$XDG_CONFIG_HOME/mac-agent-hygiene/config.env"
export HYG_LOG="$FX/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/wt-none"
export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false
unset HYG_WT_AGE_DAYS

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
run(){ /bin/bash "$HYG" status >"$FX/out" 2>"$FX/err"; echo $?; }

cat > "$CONF" <<EOF
touch "$FX/pwned-bare"
HYG_MODEL_CACHES=\$(touch "$FX/pwned-subst")
HYG_PW_GLOB=\`touch "$FX/pwned-tick"\`
HYG_GH=/usr/bin/false; touch "$FX/pwned-semi"
EVIL_KEY=1
EOF
rc=$(run)
for c in bare subst tick semi; do
  [ -e "$FX/pwned-$c" ] && bad "config line ran ($c)" || ok "config line did not run ($c)"
done
grep -q "config value refused for HYG_MODEL_CACHES" "$FX/err" && ok "\$(…) value refused and named" || bad "\$(…) not named on stderr"
grep -q "config key ignored (not one of the HYG_ settings): EVIL_KEY" "$FX/err" && ok "unknown key named" || bad "unknown key not named"
grep -q "not KEY=VALUE" "$FX/err" && ok "bare command line named" || bad "bare command line not named"

printf 'HYG_WT_AGE_DAYS=abc\n' > "$CONF"
rc=$(run)
[ "$rc" = 2 ] && grep -q "age settings must be integers" "$FX/err" && ok "plain HYG_ value is read (exit 2 on abc)" || bad "plain value not read (rc=$rc)"

printf 'export HYG_WT_AGE_DAYS="abc"\n' > "$CONF"
rc=$(run)
[ "$rc" = 2 ] && ok "export + quoted value is read" || bad "export/quoted value not read (rc=$rc)"

printf "# comment\n\nHYG_WT_AGE_DAYS='3'\n" > "$CONF"
rc=$(run)
[ "$rc" != 2 ] && ok "a valid quoted integer passes (rc=$rc)" || bad "valid value rejected: $(head -c 200 "$FX/err")"

echo "# $PASS passed, $FAILN failed"
[ "$FAILN" = 0 ]
