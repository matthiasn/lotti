#!/bin/bash
# Check code complexity similar to CodeFactor

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set absolute paths for binaries and target
RADON="$SCRIPT_DIR/.venv/bin/radon"
PY="$SCRIPT_DIR/.venv/bin/python"
PIP="$SCRIPT_DIR/.venv/bin/pip"
TARGET="$SCRIPT_DIR/manifest_tool"

# Ensure required packages are installed
if [ ! -f "$RADON" ]; then
    echo "Installing radon..."
    "$PIP" install radon
fi

if ! "$PY" -c "import flake8" 2>/dev/null; then
    echo "Installing flake8 and cognitive complexity plugin..."
    "$PIP" install flake8 flake8-cognitive-complexity
fi

echo "Checking cyclomatic complexity (threshold: 10)..."
echo "==========================================="

# Show functions with complexity > 10 (grades C, D, E, F)
echo -e "\nFunctions with complexity > 10:"
"$RADON" cc "$TARGET" -n C -s | head -n 50

echo -e "\nChecking cognitive complexity..."
echo "================================"
"$PY" -m flake8 "$TARGET" --select=CCR001 --max-cognitive-complexity=10 || true

echo -e "\nSummary:"
echo "========"
echo "Functions with high complexity (C or worse):"
"$RADON" cc "$TARGET" -n C --no-assert | wc -l | xargs echo "  Count:"

echo -e "\nTo see details for a specific file:"
echo "  $RADON cc $TARGET/flutter_ops.py -s"
echo ""
echo "Grade thresholds:"
echo "  A: 1-5 (simple)"
echo "  B: 6-10 (moderate)"
echo "  C: 11-20 (complex)"
echo "  D: 21-50 (very complex)"
echo "  E: 51+ (extremely complex)"