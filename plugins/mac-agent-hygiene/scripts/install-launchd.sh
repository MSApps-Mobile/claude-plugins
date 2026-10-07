#!/bin/bash
# Install / inspect / remove the daily LaunchAgent for mac-agent-hygiene.
#   install-launchd.sh install [--hour H] [--minute M]   copy hygiene.sh to a STABLE path, render the plist, bootout+bootstrap, verify
#   install-launchd.sh status                             loaded? which script? schedule? legacy agent present?
#   install-launchd.sh uninstall                          bootout + remove the plist and the stable copy (nothing else)
#
# Why a stable copy: a plugin's install path carries a version hash and moves on every plugin update,
# which would leave the loaded job pointing at a deleted file. `install` (re)copies hygiene.sh to
# ~/.local/share/mac-agent-hygiene/ so the plist never points into the plugin cache; re-run install
# after a plugin update to pick up a new script version.
# The plist carries an explicit PATH (launchd gives none worth having) and absolute paths rendered
# from $HOME. Reinstall = bootout + bootstrap; `kickstart` alone would run the OLD job.
set -u
LABEL="com.msapps.mac-agent-hygiene"
LEGACY_LABEL="com.opsagents.dev-cache-cleanup"      # the hand-rolled predecessor; adopted on install
HERE="$(cd "$(dirname "$0")" && pwd -P)"
SHARE="$HOME/.local/share/mac-agent-hygiene"
STABLE_SCRIPT="$SHARE/hygiene.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
UID_N=$(id -u)
HOUR=4; MINUTE=30
ACTION="${1:-status}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --hour) HOUR="${2:-}"; shift 2;; --minute) MINUTE="${2:-}"; shift 2;; *) shift;; esac; done
case "$HOUR" in ''|*[!0-9]*) echo "--hour must be 0-23" >&2; exit 2;; esac; [ "$HOUR" -le 23 ] || { echo "--hour must be 0-23" >&2; exit 2; }
case "$MINUTE" in ''|*[!0-9]*) echo "--minute must be 0-59" >&2; exit 2;; esac; [ "$MINUTE" -le 59 ] || { echo "--minute must be 0-59" >&2; exit 2; }

brew_bin=""; for b in /opt/homebrew/bin /usr/local/bin; do [ -x "$b/gh" ] && { brew_bin="$b"; break; }; done
PATH_LINE="/usr/bin:/bin:/usr/sbin:/sbin${brew_bin:+:$brew_bin}"

render(){ # pure bash substitution — no sed, so '&', '#' or '/' in $HOME cannot corrupt the plist
  local t; t=$(/bin/cat "$HERE/launchagent.plist.template")
  t=${t//__LABEL__/$LABEL}; t=${t//__SCRIPT__/$STABLE_SCRIPT}; t=${t//__HOME__/$HOME}
  t=${t//__HOUR__/$HOUR}; t=${t//__MINUTE__/$MINUTE}; t=${t//__PATH__/$PATH_LINE}
  printf '%s\n' "$t"; }
loaded(){ /bin/launchctl print "gui/$UID_N/$1" >/dev/null 2>&1; }

case "$ACTION" in
  status)
    if loaded "$LABEL"; then echo "loaded	yes"; else echo "loaded	no"; fi
    if [ -f "$PLIST" ]; then echo "plist	$PLIST"; echo "script	$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:1' "$PLIST" 2>/dev/null)"
      echo "schedule	$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:Hour' "$PLIST" 2>/dev/null):$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:Minute' "$PLIST" 2>/dev/null)"
    else echo "plist	absent"; fi
    [ -f "$STABLE_SCRIPT" ] && { if /usr/bin/cmp -s "$STABLE_SCRIPT" "$HERE/hygiene.sh"; then echo "script_copy	current"; else echo "script_copy	STALE — run install to refresh"; fi; }
    loaded "$LEGACY_LABEL" && echo "legacy_agent	$LEGACY_LABEL still loaded — run install to adopt it"
    ;;
  install)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$SHARE" || exit 1
    /bin/cp "$HERE/hygiene.sh" "$STABLE_SCRIPT" && chmod 700 "$STABLE_SCRIPT" || { echo "copy failed" >&2; exit 1; }
    tmp="$PLIST.tmp"; render > "$tmp" && /usr/bin/plutil -lint "$tmp" >/dev/null && mv "$tmp" "$PLIST" || { /bin/rm -f "$tmp"; echo "render failed" >&2; exit 1; }
    loaded "$LABEL" && /bin/launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
    if loaded "$LEGACY_LABEL"; then
      /bin/launchctl bootout "gui/$UID_N/$LEGACY_LABEL" 2>/dev/null
      [ -f "$LEGACY_PLIST" ] && /bin/mv "$LEGACY_PLIST" "$LEGACY_PLIST.adopted-by-mac-agent-hygiene"
      echo "adopted	$LEGACY_LABEL (unloaded; plist renamed *.adopted-by-mac-agent-hygiene so it does not reload at login)"
    fi
    i=0; until /bin/launchctl bootstrap "gui/$UID_N" "$PLIST" 2>/dev/null; do i=$((i+1)); [ $i -ge 5 ] && { echo "bootstrap failed" >&2; exit 1; }; /bin/sleep 1; done
    loaded_path=$(/bin/launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | /usr/bin/sed -n 's/^[[:space:]]*path = //p' | /usr/bin/head -1)
    [ "$loaded_path" = "$PLIST" ] && echo "installed	$LABEL daily at $HOUR:$(printf '%02d' "$MINUTE")" || { echo "drift	loaded job path '$loaded_path' != '$PLIST'" >&2; exit 1; }
    echo "script	$STABLE_SCRIPT"; echo "log	$HOME/Library/Logs/mac-agent-hygiene.log"
    ;;
  uninstall)
    loaded "$LABEL" && /bin/launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null; /bin/rm -f "$PLIST" "$STABLE_SCRIPT"; echo "removed	$LABEL"
    ;;
  *) echo "usage: install-launchd.sh install [--hour H --minute M] | status | uninstall" >&2; exit 2;;
esac
exit 0
