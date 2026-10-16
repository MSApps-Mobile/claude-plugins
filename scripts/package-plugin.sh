#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  package-plugin.sh                                ║
# ║  Packages a whole plugins/<name>/ tree into a     ║
# ║  distributable .plugin zip file                   ║
# ╚════════════════════════════════════════════════════╝
#
# Usage: ./scripts/package-plugin.sh <plugin-name> [output-dir]
#
# Input:  plugins/{name}/ (must contain .claude-plugin/plugin.json)
# Output: {output-dir}/{name}-{version}.plugin
#
# The .plugin format is a zip archive of the whole plugin directory.
# The root of the zip IS the plugin directory contents, i.e.
# .claude-plugin/plugin.json, skills/, hooks/, ... (not nested under
# another folder).

set -euo pipefail

PLUGIN_NAME="${1:?Usage: package-plugin.sh <plugin-name> [output-dir]}"
OUTPUT_DIR="${2:-dist}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME"
CLAUDE_PLUGIN_DIR="$PLUGIN_DIR/.claude-plugin"

# ── Validation ──────────────────────────────────────
if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo "::error::Plugin directory not found: $PLUGIN_DIR"
  exit 1
fi

if [[ ! -d "$CLAUDE_PLUGIN_DIR" ]]; then
  echo "::error::Missing .claude-plugin/ directory in $PLUGIN_DIR"
  exit 1
fi

if [[ ! -f "$CLAUDE_PLUGIN_DIR/plugin.json" ]]; then
  echo "::error::Missing plugin.json in $CLAUDE_PLUGIN_DIR"
  exit 1
fi

# ── Read version from plugin.json ───────────────────
VERSION=$(python3 -c "import json; d=json.load(open('$CLAUDE_PLUGIN_DIR/plugin.json')); print(d['version'])" 2>/dev/null)
if [[ -z "$VERSION" ]]; then
  echo "::error::Could not read version from plugin.json"
  exit 1
fi

# ── Prepare output dir ──────────────────────────────
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/$PLUGIN_NAME-$VERSION.plugin"

# Remove any existing build for this version
rm -f "$OUTPUT_FILE"

# ── Create the zip ──────────────────────────────────
# We zip the CONTENTS of the plugin dir so the archive root holds
# .claude-plugin/, skills/, hooks/, etc. Zipping only .claude-plugin/
# shipped an archive with just plugin.json (card 2cbdYCv2).
#
# OUTPUT_FILE can be absolute (CI passes /tmp/dist-test/...) or
# relative (the default "dist"). Once we `cd` into the plugin dir
# the relative path resolves incorrectly, and prefixing with $OLDPWD
# breaks for absolute paths (zip sees /pwd//tmp/...). Resolve once,
# up front, and pass the absolute path to zip.
if [[ "$OUTPUT_FILE" = /* ]]; then
  ZIP_TARGET="$OUTPUT_FILE"
else
  ZIP_TARGET="$PWD/$OUTPUT_FILE"
fi

cd "$PLUGIN_DIR"
zip -r -q "$ZIP_TARGET" . \
  --exclude "*.DS_Store" \
  --exclude "*/__pycache__/*" \
  --exclude "__pycache__/*" \
  --exclude "*.pyc" \
  --exclude "*/node_modules/*" \
  --exclude "node_modules/*" \
  --exclude ".git/*"
cd "$OLDPWD"

# ── Verify ──────────────────────────────────────────
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "::error::Package creation failed — file not found: $OUTPUT_FILE"
  exit 1
fi

# Guard: a zip holding <= 1 file is an empty shell (card 2cbdYCv2).
ENTRIES=$(unzip -Z1 "$OUTPUT_FILE" | grep -vc '/$' || true)
if [[ "$ENTRIES" -le 1 ]]; then
  echo "::error::Packaged zip $OUTPUT_FILE has only $ENTRIES file entries (<= 1) - refusing to ship an empty package"
  exit 1
fi
echo "Zip holds $ENTRIES files"

SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
echo "✓ Packaged $PLUGIN_NAME v$VERSION → $OUTPUT_FILE ($SIZE)"

# Output for GitHub Actions step chaining
echo "plugin_file=$OUTPUT_FILE" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "plugin_version=$VERSION" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
