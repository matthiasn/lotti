#!/bin/bash

# Lotti VM Troubleshooting Script
# This script helps identify and fix build issues

set -e

echo "=== Lotti VM Troubleshooting ==="

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

# Try to identify the specific build issue
echo "Attempting to build with detailed output..."

# Create a temporary build script to capture all output
cat > temp_build.sh << 'EOF'
#!/bin/bash
set -x
flutter build linux --debug --verbose 2>&1 | tee build_output.log
EOF

chmod +x temp_build.sh

echo "Running build with detailed logging..."
./temp_build.sh

# Check if build succeeded
if [ -f "build/linux/x64/debug/bundle/lotti" ]; then
    echo "✓ Build succeeded!"
    echo "You can now run: ./build/linux/x64/debug/bundle/lotti"
else
    echo "✗ Build failed. Check build_output.log for details."
    echo ""
    echo "Common solutions:"
    echo "1. Install missing dependencies:"
    echo "   sudo apt install -y libgtk-3-dev libsecret-1-dev libjsoncpp-dev"
    echo ""
    echo "2. Try running in debug mode instead:"
    echo "   flutter run -d linux"
    echo ""
    echo "3. Check if all required packages are installed:"
    echo "   flutter doctor"
fi

# Clean up
rm -f temp_build.sh 