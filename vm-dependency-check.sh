#!/bin/bash

# Lotti VM Dependency Check Script
# This script checks for all required system dependencies

set -e

echo "=== Lotti VM Dependency Check ==="

# Check system information
echo "System Information:"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"

# Check for required packages
echo ""
echo "Checking for required packages..."

PACKAGES=(
    "libgtk-3-dev"
    "libsecret-1-dev"
    "libjsoncpp-dev"
    "libsecret-1-0"
    "sqlite3"
    "libsqlite3-dev"
    "pulseaudio-utils"
    "build-essential"
    "cmake"
    "ninja-build"
    "pkg-config"
    "clang"
    "libkeybinder-3.0-dev"
    "libmpv-dev"
    "libglu1-mesa"
    "curl"
    "git"
    "unzip"
    "xz-utils"
    "zip"
)

MISSING_PACKAGES=()

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        echo "✓ $package"
    else
        echo "✗ $package (MISSING)"
        MISSING_PACKAGES+=("$package")
    fi
done

# Check Flutter
echo ""
echo "Checking Flutter:"
if command -v flutter &> /dev/null; then
    echo "✓ Flutter installed"
    flutter --version
else
    echo "✗ Flutter not installed"
fi

# Check if we can run without building
echo ""
echo "Attempting to run without building..."

# Try to run the app directly if it exists
if [ -f "build/linux/x64/debug/bundle/lotti" ]; then
    echo "Found existing build, trying to run..."
    ./build/linux/x64/debug/bundle/lotti
elif [ -f "build/linux/x64/profile/bundle/lotti" ]; then
    echo "Found profile build, trying to run..."
    ./build/linux/x64/profile/bundle/lotti
elif [ -f "build/linux/x64/release/bundle/lotti" ]; then
    echo "Found release build, trying to run..."
    ./build/linux/x64/release/bundle/lotti
else
    echo "No existing builds found."
fi

# Install missing packages if any
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "Installing missing packages..."
    sudo apt update
    sudo apt install -y "${MISSING_PACKAGES[@]}"
fi

echo ""
echo "=== Summary ==="
echo "If you have missing packages, they should now be installed."
echo ""
echo "Alternative approaches:"
echo "1. Try running with existing build: ./build/linux/x64/debug/bundle/lotti"
echo "2. Try downloading a pre-built release from GitHub"
echo "3. Try the Flatpak approach (if you have Flatpak installed)"
echo ""
echo "To download a pre-built release:"
echo "  wget https://github.com/matthiasn/lotti/releases/latest/download/linux.x64.tar.gz"
echo "  tar xf linux.x64.tar.gz"
echo "  ./lotti/lotti" 