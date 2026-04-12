#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  bump-version.sh                                  ║
# ║  Bumps patch version in .claude-plugin/plugin.json║
# ╚═══════════════════════════════════════════════════╝
#
# Usage: ./scripts/bump-version.sh <plugin-name> [major|minor|patch]
# Default bump type: patch

set -euo pipefail

PLUGIN_NAME="${1:?Usage: bump-version.sh <plugin-name> [major|minor|patch]}"
BUMP_TYPE="${2:-patch}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PLUGIN_JSON="$REPO_ROOT/plugins/$PLUGIN_NAME/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "::error::plugin.json not found: $PLUGIN_JSON"
  exit 1
fi

CURRENT=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d['version'])")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *)
    echo "::error::Invalid bump type '$BUMP_TYPE'. Use major|minor|patch"
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

python3 - <<PYEOF
import json
path = "$PLUGIN_JSON"
with open(path) as f:
    data = json.load(f)
data['version'] = "$NEW_VERSION"
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f"✓ Bumped $PLUGIN_NAME: $CURRENT → $NEW_VERSION")
PYEOF

echo "new_version=$NEW_VERSION" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "old_version=$CURRENT" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
