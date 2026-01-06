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

# Clone flatpak-flutter if missing
if [ ! -d "$SCRIPT_DIR/flatpak-flutter" ]; then
  echo "Cloning flatpak-flutter..."
  git clone --depth 1 https://github.com/TheAppgineer/flatpak-flutter.git "$SCRIPT_DIR/flatpak-flutter"
fi

# Clean and create work dir
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# Create manifest with real commit (not placeholder)
# Using flatpak-flutter compatible manifest (Flutter inside lotti module)
sed "s/COMMIT_PLACEHOLDER/$COMMIT/" "$SCRIPT_DIR/com.matthiasn.lotti.flatpak-flutter.yml" > "$WORK_DIR/com.matthiasn.lotti.yml"

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

echo ""
echo "Done! Output in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
