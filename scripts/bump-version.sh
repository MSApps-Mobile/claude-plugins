#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  bump-version.sh                                  ║
# ║  Bumps version in .claude-plugin/plugin.json AND  ║
# ║  the matching .claude-plugin/marketplace.json entry║
# ╚═══════════════════════════════════════════════════╝
#
# Usage: ./scripts/bump-version.sh <plugin-name> [major|minor|patch]
# Default bump type: patch

set -euo pipefail

PLUGIN_NAME="${1:?Usage: bump-version.sh <plugin-name> [major|minor|patch]}"
BUMP_TYPE="${2:-patch}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Card tIL3cCkK: the plugin name is a folder name from merged repo content and
# this runs in release.yml's bump step, which holds a write token. Refuse any
# name outside ^[a-z0-9-]+$ (the same guard validate-pr.yml's jobs run) before
# it is used in a path. Defence in depth: the Python below still takes the name
# and path only as argv, never inside its source.
bash "$SCRIPT_DIR/check-plugin-name.sh" "$PLUGIN_NAME"

PLUGIN_JSON="$REPO_ROOT/plugins/$PLUGIN_NAME/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "::error::plugin.json not found: $PLUGIN_JSON"
  exit 1
fi

# Card tIL3cCkK: values reach Python as argv under a QUOTED heredoc delimiter,
# so bash expands nothing inside the Python source.
CURRENT=$(python3 - "$PLUGIN_JSON" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    print(json.load(f)['version'])
PYEOF
)
# Card SNQ5Siev: the version is repo content. Bash arithmetic below evaluates
# each part as an expression (a part like 'BASH_VERSINFO[$(cmd)]' runs cmd), and the
# result names the release tag, so accept only plain x.y.z - the same rule
# validate-pr.yml applies to plugin.json.
if [[ ! "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::version in $PLUGIN_JSON is not x.y.z: '$CURRENT'"
  exit 1
fi
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

python3 - "$PLUGIN_JSON" "$PLUGIN_NAME" "$CURRENT" "$NEW_VERSION" <<'PYEOF'
import json, sys
path, name, current, new_version = sys.argv[1:5]
with open(path) as f:
    data = json.load(f)
data['version'] = new_version
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(f"✓ Bumped {name}: {current} → {new_version}")
PYEOF

# Card okOoGKTA: the marketplace listing must advertise the version that ships.
# Same commit, same script - this is the only bumper (no second bumper to drift).
python3 "$SCRIPT_DIR/marketplace-versions.py" --root "$REPO_ROOT" --set "$PLUGIN_NAME" "$NEW_VERSION"

echo "new_version=$NEW_VERSION" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "old_version=$CURRENT" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
