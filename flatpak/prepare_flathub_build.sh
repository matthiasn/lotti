#!/bin/bash
# Direct flatpak-flutter invocation. No Python wrapper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$SCRIPT_DIR/direct-build"
OUTPUT_DIR="$WORK_DIR/output"

# Use venv if available, otherwise system Python
if [ -f "$SCRIPT_DIR/.venv/bin/python3" ]; then
  PYTHON="$SCRIPT_DIR/.venv/bin/python3"
elif ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found" >&2
  exit 1
else
  PYTHON="python3"
fi

# Commit to use (default: origin/main)
COMMIT="${1:-$(git -C "$REPO_ROOT" rev-parse origin/main)}"
echo "Using commit: ${COMMIT:0:12}"

# Clone flatpak-flutter if missing (pinned for reproducibility)
FLATPAK_FLUTTER_VERSION="0.10.0"
if [ ! -d "$SCRIPT_DIR/flatpak-flutter" ]; then
  echo "Cloning flatpak-flutter v${FLATPAK_FLUTTER_VERSION}..."
  git clone --depth 1 --branch "$FLATPAK_FLUTTER_VERSION" https://github.com/TheAppgineer/flatpak-flutter.git "$SCRIPT_DIR/flatpak-flutter"
fi

# Clean and create work dir
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# Create manifest with real commit (not placeholder)
# Using flatpak-flutter compatible manifest (Flutter inside lotti module)
sed "s/COMMIT_PLACEHOLDER/$COMMIT/" "$SCRIPT_DIR/com.matthiasn.lotti.flatpak-flutter.yml" > "$WORK_DIR/com.matthiasn.lotti.yml"

# Copy foreign.json if present (handles cargokit plugins like flutter_vodozemac)
if [ -f "$SCRIPT_DIR/foreign.json" ]; then
  cp "$SCRIPT_DIR/foreign.json" "$WORK_DIR/"
  echo "Using foreign.json for cargokit dependencies"
fi

# Run flatpak-flutter
echo "Running flatpak-flutter..."
cd "$WORK_DIR"
PYTHONPATH="$SCRIPT_DIR/flatpak-flutter" "$PYTHON" "$SCRIPT_DIR/flatpak-flutter/flatpak-flutter.py" \
  --app-module lotti \
  com.matthiasn.lotti.yml

# Copy output
echo "Copying output..."
for f in "$WORK_DIR"/*.json "$WORK_DIR"/*.yml "$WORK_DIR"/generated; do
  [ -e "$f" ] && cp -r "$f" "$OUTPUT_DIR/"
done

# Copy cargokit patch (needed by foreign.json references)
if [ -d "$SCRIPT_DIR/flatpak-flutter/foreign_deps/cargokit" ]; then
  cp -r "$SCRIPT_DIR/flatpak-flutter/foreign_deps/cargokit" "$OUTPUT_DIR/"
fi

echo ""
echo "Done! Output in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

# Copy to flathub release repo if it exists
FLATHUB_DIR="$REPO_ROOT/../com.matthiasn.lotti"
if [ -d "$FLATHUB_DIR" ]; then
  echo ""
  echo "Copying to flathub repo: $FLATHUB_DIR"
  cp -r "$OUTPUT_DIR"/* "$FLATHUB_DIR/"
  echo "Flathub repo updated."
else
  echo ""
  echo "Flathub repo not found at $FLATHUB_DIR - skipping copy."
  echo "Clone it with: git clone git@github.com:flathub/com.matthiasn.lotti.git $FLATHUB_DIR"
fi
