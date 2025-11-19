#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Use venv if available, otherwise system Python
if [ -f "$SCRIPT_DIR/.venv/bin/python3" ]; then
  PYTHON="$SCRIPT_DIR/.venv/bin/python3"
elif ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found" >&2
  exit 1
else
  PYTHON="python3"
fi

exec "$PYTHON" "$SCRIPT_DIR/manifest_tool/cli.py" prepare-flathub \
  --repo-root "$REPO_ROOT" "$@"
