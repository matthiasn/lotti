#!/bin/bash

# Lotti VM Debug Run Script
# This script runs Lotti in debug mode without building

set -e

echo "=== Running Lotti in Debug Mode ==="

# Check Flutter version
echo "Checking Flutter version..."
flutter --version

# Check if we're in the right directory
echo "Current directory: $(pwd)"
echo "Checking for main.dart..."
if [ -f "lib/main.dart" ]; then
    echo "✓ main.dart found"
else
    echo "✗ main.dart not found"
    exit 1
fi

# Check dependencies
echo "Checking Flutter dependencies..."
flutter pub get

# Generate code
echo "Generating code..."
make build_runner

# Try to run in debug mode
echo "Attempting to run in debug mode..."
echo "This will start the app without building a release version."

flutter run -d linux --debug

echo ""
echo "If the app starts successfully, you should see the Lotti interface."
echo "If it fails, we can try alternative approaches." 