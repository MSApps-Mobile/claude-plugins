#!/usr/bin/env bash
# Card tc0MIvhS - the negative control for the `claude plugin validate .` gate.
#
# A gate that has only ever seen passing input proves nothing, so this runs the
# real CLI against two committed fixtures and demands both outcomes:
#   good/                a clean marketplace            -> exit 0 (warnings allowed)
#   bad-reserved-name/   a plugin named "claude-x"      -> exit non-zero, and the
#                        output names the reserved-name rule
# Needs `claude` on PATH. Run: bash scripts/claude-plugin-validate.test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$HERE/fixtures/claude-plugin-validate"
command -v claude >/dev/null || { echo "FAIL: claude CLI not on PATH"; exit 2; }
echo "claude $(claude --version)"
FAILS=0

out=$(cd "$FIX/good" && claude plugin validate . 2>&1); rc=$?
if [[ "$rc" -eq 0 ]]; then echo "  ok  good fixture passes (rc=0)"
else echo "  FAIL good fixture: rc=$rc"; echo "$out"; FAILS=$((FAILS + 1)); fi

out=$(cd "$FIX/bad-reserved-name" && claude plugin validate . 2>&1); rc=$?
if [[ "$rc" -ne 0 ]] && grep -q 'is reserved' <<<"$out"; then
  echo "  ok  claude-x fixture is rejected (rc=$rc, reserved-name error)"
else
  echo "  FAIL claude-x fixture was NOT rejected: rc=$rc"; echo "$out"; FAILS=$((FAILS + 1))
fi

[[ "$FAILS" -eq 0 ]]
