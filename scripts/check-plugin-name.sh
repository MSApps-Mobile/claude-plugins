#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  check-plugin-name.sh                             ║
# ║  Refuses a plugin directory name that is not      ║
# ║  ^[a-z0-9-]+$ before a job uses it in a path      ║
# ╚═══════════════════════════════════════════════════╝
#
# Usage: bash scripts/check-plugin-name.sh "$PLUGIN"
# Exit:  0 = allowed · 1 = refused (prints a ::error:: annotation)
#
# Card IcsmluvI: a plugin name comes from the PR's own file paths, so it is
# attacker-controlled. The detect job in validate-pr.yml refuses any other
# name before the matrix is built; this is the defence in depth each matrix
# job runs first. Card TNCrQi31: ONE copy of the shell guard, called by every
# job that takes a plugin name from the matrix (the validate and tests jobs),
# instead of one pasted block per job.

set -uo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-z0-9-]+$ ]]; then
  echo "::error::Plugin directory name is not allowed: must match ^[a-z0-9-]+\$"
  exit 1
fi
