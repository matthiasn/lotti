#!/bin/bash

# Update the commit placeholder in the Flatpak manifest.
# - Validates the manifest before touching it
# - Replaces 'COMMIT_PLACEHOLDER' with the current (or provided) commit

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/com.matthiasn.lotti.source.yml"

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "Error: Manifest not found: $MANIFEST_FILE" >&2
  exit 1
fi

# Determine commit to pin
COMMIT_HASH="${1:-$(git -C "$SCRIPT_DIR/.." rev-parse HEAD)}"

echo "Updating Flatpak manifest with commit: $COMMIT_HASH"

# Preflight: guard against bad states and give immediate feedback
if grep -qE '^[[:space:]]*commit:[[:space:]]*$' "$MANIFEST_FILE"; then
  echo "Error: Empty 'commit:' field detected in $MANIFEST_FILE. Please restore 'commit: COMMIT_PLACEHOLDER' before running this script." >&2
  exit 1
fi

if ! grep -q 'commit: COMMIT_PLACEHOLDER' "$MANIFEST_FILE"; then
  echo "Info: No COMMIT_PLACEHOLDER found; manifest may already be commit-pinned. Nothing to do." >&2
  exit 0
fi

# Replace the placeholder with the commit hash
sed -i "s/commit: COMMIT_PLACEHOLDER/commit: $COMMIT_HASH/" "$MANIFEST_FILE"

echo "Updated $MANIFEST_FILE with commit $COMMIT_HASH"

# Show the change context
echo "Modified source configuration:"
grep -n -A3 -B1 "url: https://github.com/matthiasn/lotti" "$MANIFEST_FILE" || true
