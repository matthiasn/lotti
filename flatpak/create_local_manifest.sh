#!/bin/bash

# Update the commit placeholder in the Flatpak manifest using the Python tool.
# This script provides a simple interface for the GitHub workflow while
# delegating all complex logic to the tested Python manifest tool.

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_MANIFEST="$SCRIPT_DIR/com.matthiasn.lotti.source.yml"
OUTPUT_MANIFEST="$SCRIPT_DIR/com.matthiasn.lotti.yml"
PYTHON_CLI="$SCRIPT_DIR/manifest_tool/cli.py"

if [ ! -f "$SOURCE_MANIFEST" ]; then
  echo "Error: Manifest not found: $SOURCE_MANIFEST" >&2
  exit 1
fi

# Work on a fresh copy alongside the source manifest
cp "$SOURCE_MANIFEST" "$OUTPUT_MANIFEST"

# Determine commit (use provided argument or current HEAD)
COMMIT_HASH="${1:-$(git -C "$SCRIPT_DIR/.." rev-parse HEAD)}"

echo "Updating Flatpak manifest with commit: $COMMIT_HASH"

# Use the Python tool to update the manifest
# It automatically detects PR mode from GitHub environment variables
python3 "$PYTHON_CLI" update-manifest \
  --manifest "$OUTPUT_MANIFEST" \
  --commit "$COMMIT_HASH" \
  --event-name "${GITHUB_EVENT_NAME:-}" \
  --event-path "${GITHUB_EVENT_PATH:-}"

echo "Generated manifest: $OUTPUT_MANIFEST"

# Show the change context
echo "Modified source configuration:"
grep -n -A3 -B1 "name: lotti" "$OUTPUT_MANIFEST" | sed -n '1,40p' || true