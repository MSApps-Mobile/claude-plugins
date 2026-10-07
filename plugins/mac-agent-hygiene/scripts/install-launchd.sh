#!/bin/bash
# Install / inspect / remove the daily LaunchAgent for mac-agent-hygiene.
#   install-launchd.sh install [--hour H] [--minute M]   render plist from THIS plugin's path, bootout+bootstrap
#   install-launchd.sh status                             loaded? which script path? next run time
#   install-launchd.sh uninstall                          bootout + remove the plist (nothing else)
# The plist carries an explicit PATH (launchd gives none worth having) and absolute paths rendered
# from $HOME — nothing is hardcoded to one user. Reinstall = bootout + bootstrap; `kickstart` alone
# would run the OLD job.
set -u
LABEL="com.msapps.mac-agent-hygiene"
LEGACY_LABEL="com.opsagents.dev-cache-cleanup"      # the hand-rolled predecessor; adopted on install
HERE="$(cd "$(dirname "$0")" && pwd -P)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_N=$(id -u)
HOUR=4; MINUTE=30
ACTION="${1:-status}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --hour) HOUR="$2"; shift 2;; --minute) MINUTE="$2"; shift 2;; *) shift;; esac; done

brew_bin=""; for b in /opt/homebrew/bin /usr/local/bin; do [ -x "$b/gh" ] && { brew_bin="$b"; break; }; done
PATH_LINE="/usr/bin:/bin:/usr/sbin:/sbin${brew_bin:+:$brew_bin}"

render(){ /usr/bin/sed -e "s#__LABEL__#$LABEL#g" -e "s#__SCRIPT__#$HERE/hygiene.sh#g" -e "s#__HOME__#$HOME#g" \
    -e "s#__HOUR__#$HOUR#g" -e "s#__MINUTE__#$MINUTE#g" -e "s#__PATH__#$PATH_LINE#g" "$HERE/launchagent.plist.template"; }

case "$ACTION" in
  status)
    if /bin/launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then echo "loaded	yes"; else echo "loaded	no"; fi
    [ -f "$PLIST" ] && { echo "plist	$PLIST"; echo "script	$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:1' "$PLIST" 2>/dev/null)";
      echo "schedule	$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:Hour' "$PLIST" 2>/dev/null):$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:Minute' "$PLIST" 2>/dev/null)"; } || echo "plist	absent"
    /bin/launchctl print "gui/$UID_N/$LEGACY_LABEL" >/dev/null 2>&1 && echo "legacy_agent	$LEGACY_LABEL still loaded — run install to adopt it"
    ;;
  install)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    render > "$PLIST.tmp" && /usr/bin/plutil -lint "$PLIST.tmp" >/dev/null && mv "$PLIST.tmp" "$PLIST" || { echo "render failed" >&2; exit 1; }
    /bin/launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
    if /bin/launchctl print "gui/$UID_N/$LEGACY_LABEL" >/dev/null 2>&1; then
      /bin/launchctl bootout "gui/$UID_N/$LEGACY_LABEL" 2>/dev/null && echo "adopted	$LEGACY_LABEL (unloaded; its plist left in place for you to delete)"
    fi
    /bin/launchctl bootstrap "gui/$UID_N" "$PLIST" || { echo "bootstrap failed" >&2; exit 1; }
    # drift check: the loaded job must point at the file we just wrote
    loaded_path=$(/bin/launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | /usr/bin/awk '/path = /{print $3; exit}')
    [ "$loaded_path" = "$PLIST" ] && echo "installed	$LABEL daily at $HOUR:$MINUTE" || { echo "drift	loaded job path '$loaded_path' != '$PLIST'" >&2; exit 1; }
    echo "script	$HERE/hygiene.sh"; echo "log	$HOME/Library/Logs/mac-agent-hygiene.log"
    ;;
  uninstall)
    /bin/launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null; /bin/rm -f "$PLIST"; echo "removed	$LABEL"
    ;;
  *) echo "usage: install-launchd.sh install [--hour H --minute M] | status | uninstall" >&2; exit 2;;
esac
exit 0
