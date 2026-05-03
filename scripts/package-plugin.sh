#!/bin/bash
# ╔═══════════════════════════════════════════════════╗
# ║  package-plugin.sh                                 !║
#!║  Packages a plugin's .claude-plugin/ directory   !║
#!║  into a distributable .plugin zip file           !║
#!╚════════════════════════════════════════════════════╝
#
# Usage: ./scripts/package-plugin.sh <plugin-name> [output-dir]
#
# Input:  plugins/{name}/.claude-plugin/
# Output: {output-dir}/{name}-{version}.plugin
#
# The .plugin format is a zip archive of the .claude-plugin/ directory.
# The root of the zip IS the .claude-plugin/ directory contents
# (not nested under another folder).

set -euo pipefail

PLUGIN_NAME="${1:?Usage: package-plugin.sh <plugin-name> [output-dir]}"
OUTPUT_DIR="${2:-dist}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME"
CLAUDE_PLUGIN_DIR="$PLUGIN_DIR/.claude-plugin"

# ── Validation ───────────────────────────────────────
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
# Resolve to absolute path so it survives the cd below
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
OUTPUT_FILE="$OUTPUT_DIR/$PLUGIN_NAME-$VERSION.plugin"

# Remove any existing build for this version
rm -f "$OUTPUT_FILE"

# ── Create the zip ──────────────────────────────────
# We zip the CONTENTS of .claude-plugin/ so the archive root
# contains plugin.json, skills/, agents/, etc. directly.
cd "$CLAUDE_PLUGIN_DIR"
zip -r "$OUTPUT_FILE" . \
  --exclude "*.DS_Store" \
  --exclude "__pycache__/*" \
  --exclude "*.pyc" \
  --exclude "node_modules/*" \
  --exclude ".git/*"

# ── Verify ──────────────────────────────────────────
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "::error::Package creation failed — file not found: $OUTPUT_FILE"
  exit 1
fi

SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
echo "✓ Packaged $PLUGIN_NAME v$VERSION → $OUTPUT_FILE ($SIZE)"

# Output for GitHub Actions step chaining
echo "plugin_file=$OUTPUT_FILE" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
echo "plugin_version=$VERSION" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
