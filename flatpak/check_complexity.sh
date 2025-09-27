#!/bin/bash
# Check code complexity similar to CodeFactor

echo "Checking cyclomatic complexity (threshold: 10)..."
echo "==========================================="

# Show functions with complexity > 10 (grades C, D, E, F)
echo -e "\nFunctions with complexity > 10:"
.venv/bin/radon cc manifest_tool/ -n C -s | head -n 50

echo -e "\nChecking cognitive complexity..."
echo "================================"
.venv/bin/python -m flake8 manifest_tool/ --select=CCR001 --max-cognitive-complexity=10 || true

echo -e "\nSummary:"
echo "========"
echo "Functions with high complexity (C or worse):"
.venv/bin/radon cc manifest_tool/ -n C --no-assert | wc -l | xargs echo "  Count:"

echo -e "\nTo see details for a specific file:"
echo "  .venv/bin/radon cc manifest_tool/flutter_ops.py -s"
echo ""
echo "Grade thresholds:"
echo "  A: 1-5 (simple)"
echo "  B: 6-10 (moderate)"
echo "  C: 11-20 (complex)"
echo "  D: 21-50 (very complex)"
echo "  E: 51+ (extremely complex)"