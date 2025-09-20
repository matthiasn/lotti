#!/bin/bash

# Script to update the commit placeholder in the Flatpak manifest
# Replaces COMMIT_PLACEHOLDER with the actual current commit

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/com.matthiasn.lotti.source.yml"

# Get the commit hash to use (either from argument or current HEAD)
COMMIT_HASH="${1:-$(git rev-parse HEAD)}"

echo "Updating Flatpak manifest with commit: $COMMIT_HASH"

# Replace the COMMIT_PLACEHOLDER with the actual commit hash
sed -i "s/COMMIT_PLACEHOLDER/$COMMIT_HASH/" "$MANIFEST_FILE"

echo "Updated $MANIFEST_FILE with commit $COMMIT_HASH"

# Show the change
echo "Modified source configuration:"
grep -A2 "url: https://github.com/matthiasn/lotti" "$MANIFEST_FILE"