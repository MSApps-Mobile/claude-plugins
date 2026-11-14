#!/bin/bash
# hygiene-wt-ancestor-repo.test.sh — card w1t7IqUt, PR #80 CTO review 5817427258 B4.
# Real scripts/hygiene.sh, a throwaway HOME per scenario, nothing touches the real home.
#
# A session folder with no repo of its own: git discovery climbs past it to an ANCESTOR repo (a dotfiles
# repo at ~, a ~/code repo), whose .gitignore then answers for build/ and dist/ that exist nowhere else.
#
#   B4  KNOWN-NEGATIVE  ~/.git ignoring `*`, and ~/code/.git ignoring `wt/`: plain/build, plain/dist and
#                       plainpkg/node_modules (beside a package.json) read keep/repo-above-session-folder,
#                       and a hand-written apply of all three removes nothing (report.bin survives)
#   B4  KNOWN-POSITIVE  under the same ancestor repo, a session folder that IS a clone, and a repo nested in
#                       a session folder, still have their ignored dist/ removed (the bound is "at or below
#                       the session folder", not "no repo above")
#   B4  CONTROL         no ancestor repo: plain/build keeps not-provably-regenerable, plainpkg/node_modules
#                       is removed node-artifact-beside-package-json (unchanged behaviour)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HYG="${HYG_UNDER_TEST:-$HERE/../scripts/hygiene.sh}"
[ "$(uname -s)" = Darwin ] || { echo "SKIP: hygiene.sh is macOS-only (uname=$(uname -s))"; exit 0; }
FX="$(mktemp -d "${TMPDIR:-/tmp}/hygiene-ancestor.XXXXXX")" || exit 1
FX="$(cd -P "$FX" && pwd -P)"
trap 'chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES

PASS=0; FAILN=0
ok(){ PASS=$((PASS+1)); echo "ok   - $1"; }
bad(){ FAILN=$((FAILN+1)); echo "FAIL - $1"; }
old(){ /usr/bin/find "$@" -exec touch -h -t 202601010000 {} + 2>/dev/null; }
row(){ /usr/bin/awk -F'\t' -v c="$2" -v p="$3" '$1==c && $5==p{print $2"/"$4}' "$1"; }
expect(){ local got; got="$(row "$P" build-artifacts "$1")"; if [ "$got" = "$2" ]; then ok "$3"; else bad "$3 (want $2, got [$got])"; fi; }

# setup <scenario>: a fresh HOME, the ancestor repo the scenario names, and the session folders
setup(){ local s="$1"
  export HOME="$FX/$s/home" XDG_CONFIG_HOME="$FX/$s/home/.config"; W="$HOME/code/wt"; mkdir -p "$W"
  export HYG_LOG="$FX/$s/hygiene.log" HYG_DERIVED_DATA="$HOME/dd-none" HYG_PLUGIN_CACHE="$HOME/pc-none"
  export HYG_PW_GLOB="$HOME/pw-none-*" HYG_MODEL_CACHES="$HOME/mc-none" HYG_WT_ROOT="$HOME/code"
  export HYG_WT_MERGED_PR_CHECK=0 HYG_GH=/usr/bin/false HYG_GIT=/usr/bin/git HYG_LOCK="$FX/$s/lock"
  export HYG_SESSION_ROOT="$W" HYG_GRADLE_HOME="$HOME/gradle-none" HYG_DEVICE_SUPPORT="$HOME/ds-none"
  export HYG_SIM_DEVICES="$HOME/sims-none" HYG_ANDROID_HOME="$HOME/android-none" HYG_PKG_CACHES=""
  export HYG_SESSIONS_JSON="$FX/$s/sessions.json"; echo '[]' > "$HYG_SESSIONS_JSON"
  case "$s" in
    home) git init -q "$HOME" && printf '*\n' > "$HOME/.gitignore";;               # the common dotfiles setup
    code) git init -q "$HOME/code" && printf 'wt/\n' > "$HOME/code/.gitignore";;
  esac
  # a plain session folder: no repo of its own, build/ and dist/ hold the only copy of their files
  mkdir -p "$W/plain/build" "$W/plain/dist"; echo only-copy > "$W/plain/build/report.bin"; echo only-copy > "$W/plain/dist/out.bin"
  # a plain session folder with a package.json: outside any repo its node_modules is removable
  mkdir -p "$W/plainpkg/node_modules/p"; echo '{}' > "$W/plainpkg/package.json"; echo x > "$W/plainpkg/node_modules/p/i.js"
  # the session folder IS a repo that ignores dist/
  git init -q "$W/own" && (cd "$W/own" && printf 'dist/\n' > .gitignore && git add .gitignore && git commit -qm own)
  mkdir -p "$W/own/dist"; echo x > "$W/own/dist/o.js"
  # a repo nested one level down in a plain session folder, ignoring dist/
  git init -q "$W/wrap/sub" && (cd "$W/wrap/sub" && printf 'dist/\n' > .gitignore && git add .gitignore && git commit -qm sub)
  mkdir -p "$W/wrap/sub/dist"; echo x > "$W/wrap/sub/dist/o.js"
  old "$W"
}

for s in home code none; do
  setup "$s"
  # the fixture must really reach the ancestor repo, or the scenario proves nothing
  if [ "$s" != none ]; then
    tl=$(git -C "$W/plain" rev-parse --show-toplevel 2>/dev/null)
    case "$s" in home) want="$HOME";; code) want="$HOME/code";; esac
    [ "$(cd -P "$tl" 2>/dev/null && pwd -P)" = "$(cd -P "$want" && pwd -P)" ] && ok "$s: git resolves plain/ to the ancestor repo ($want)" \
      || bad "$s: git resolves plain/ to [$tl], not the ancestor repo"
    git -C "$W/plain" check-ignore -q -- build/ && ok "$s: the ancestor repo ignores plain/build/" || bad "$s: the ancestor repo does not ignore plain/build/"
  fi
  P="$FX/$s/plan.tsv"; bash "$HYG" plan > "$P" 2>"$P.err" || bad "$s: plan exited non-zero: $(cat "$P.err")"
  if [ "$s" = none ]; then
    expect "$W/plain/build" "keep/not-provably-regenerable" "none: no ancestor repo, plain/build → keep not-provably-regenerable"
    expect "$W/plain/dist" "keep/not-provably-regenerable" "none: no ancestor repo, plain/dist → keep not-provably-regenerable"
    expect "$W/plainpkg/node_modules" "remove/node-artifact-beside-package-json" "none: no ancestor repo, node_modules beside package.json → remove"
  else
    expect "$W/plain/build" "keep/repo-above-session-folder" "B4 $s: plain/build answered by an ancestor repo → keep"
    expect "$W/plain/dist" "keep/repo-above-session-folder" "B4 $s: plain/dist answered by an ancestor repo → keep"
    expect "$W/plainpkg/node_modules" "keep/repo-above-session-folder" "B4 $s: node_modules beside package.json under an ancestor repo → keep (it may track files there)"
  fi
  expect "$W/own/dist" "remove/gitignored-build-output" "$s: the session folder IS a repo ignoring dist/ → remove"
  expect "$W/wrap/sub/dist" "remove/gitignored-build-output" "$s: a repo nested in the session folder ignoring dist/ → remove"

  # apply: hand-written lines for the plain folders (the plan keeps them, so they are not in a remove-set)
  printf 'build-artifacts\t%s\nbuild-artifacts\t%s\nbuild-artifacts\t%s\n' "$W/plain/build" "$W/plain/dist" "$W/plainpkg/node_modules" > "$FX/$s/apply-plain.tsv"
  if [ "$s" != none ]; then
    bash "$HYG" apply "$FX/$s/apply-plain.tsv" > "$FX/$s/apply-plain.out" 2>&1
    [ "$(cat "$W/plain/build/report.bin" 2>/dev/null)" = only-copy ] && [ "$(cat "$W/plain/dist/out.bin" 2>/dev/null)" = only-copy ] \
      && [ -f "$W/plainpkg/node_modules/p/i.js" ] && [ "$(/usr/bin/grep -c '	removed	' "$FX/$s/apply-plain.out")" = 0 ] \
      && ok "B4 $s: apply removed none of the three; report.bin and out.bin survive" || bad "B4 $s apply: $(cat "$FX/$s/apply-plain.out")"
  fi
  # apply is not a no-op: the two controls the plan marked removable go
  printf 'build-artifacts\t%s\nbuild-artifacts\t%s\n' "$W/own/dist" "$W/wrap/sub/dist" > "$FX/$s/apply-ctl.tsv"
  bash "$HYG" apply "$FX/$s/apply-ctl.tsv" > "$FX/$s/apply-ctl.out" 2>&1
  [ ! -e "$W/own/dist" ] && [ ! -e "$W/wrap/sub/dist" ] && ok "$s: apply removed both controls' ignored dist/" || bad "$s control apply: $(cat "$FX/$s/apply-ctl.out")"
done

echo "# pass=$PASS fail=$FAILN"
[ "$FAILN" = 0 ]
