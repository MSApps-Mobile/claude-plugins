#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  detect-changed-plugins.sh                        ║
# ║  Outputs newline-separated list of plugin dirs    ║
# ║  that changed between BASE_SHA and HEAD_SHA       ║
# ╚═══════════════════════════════════════════════════╝
#
# Usage: ./scripts/detect-changed-plugins.sh <base_sha> <head_sha>
# Output: one plugin name per line (e.g. "whatsapp-mcp")
#
# In GitHub Actions, call as:
#   CHANGED=$(bash scripts/detect-changed-plugins.sh ${{ github.event.before }} ${{ github.sha }})

set -euo pipefail

BASE_SHA="${1:-HEAD~1}"
HEAD_SHA="${2:-HEAD}"

# Get all changed files between the two commits
CHANGED_FILES=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" 2>/dev/null || git diff --name-only HEAD~1 HEAD)

# Extract unique plugin names from changed paths like plugins/{name}/...
PLUGINS=()
while IFS= read -r file; do
  if [[ "$file" == plugins/* ]]; then
    plugin_name=$(echo "$file" | cut -d'/' -f2)
    if [[ -n "$plugin_name" ]] && [[ -d "plugins/$plugin_name" ]]; then
      PLUGINS+=("$plugin_name")
    fi
  fi
done <<< "$CHANGED_FILES"

# Deduplicate
UNIQUE_PLUGINS=($(printf '%s\n' "${PLUGINS[@]}" | sort -u))

if [[ ${#UNIQUE_PLUGINS[@]} -eq 0 ]]; then
  echo "::notice::No plugin directories changed — skipping release"
  exit 0
fi

for plugin in "${UNIQUE_PLUGINS[@]}"; do
  echo "$plugin"
done
