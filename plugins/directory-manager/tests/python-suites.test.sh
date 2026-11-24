#!/bin/bash
# Runs directory-manager's Python unit suites (listing-lint rules, parse_usage) so CI shows them.
# validate-pr.yml only executes plugins/<name>/tests/*.test.sh; the suites under skills/*/tests
# were never reached. Run: bash plugins/directory-manager/tests/python-suites.test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "::error::python3 not found; the directory-manager suites cannot run"
  exit 1
fi
echo "python: $(python3 --version 2>&1)"

FAIL=0
for suite in listing-lint directory-stats; do
  echo "== unittest: skills/$suite/tests"
  if python3 -m unittest discover -v -s "$PLUGIN/skills/$suite/tests"; then
    echo "  ✓ $suite suite passed"
  else
    echo "  ✗ $suite suite failed"
    FAIL=1
  fi
done
exit "$FAIL"
