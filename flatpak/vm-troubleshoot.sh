#!/bin/bash

# VM Troubleshooting Script for Lotti Flatpak Build
# This script helps diagnose and fix common issues

set -e

echo "=== Lotti VM Troubleshooting Script ==="

# Check OS
echo "Checking OS..."
echo "OSTYPE: $OSTYPE"
echo "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"

# Check Flutter
echo ""
echo "Checking Flutter..."
if command -v flutter &> /dev/null; then
    echo "✓ Flutter found: $(flutter --version | head -1)"
else
    echo "✗ Flutter not found"
    echo "Installing Flutter..."
    cd ~
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
    tar xf flutter_linux_3.16.5-stable.tar.xz
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/flutter/bin"
    cd ~/lotti
fi

# Check Flatpak
echo ""
echo "Checking Flatpak..."
if command -v flatpak &> /dev/null; then
    echo "✓ Flatpak found: $(flatpak --version)"
else
    echo "✗ Flatpak not found"
    echo "Installing Flatpak..."
    sudo apt update
    sudo apt install -y flatpak flatpak-builder
fi

# Check GNOME SDK
echo ""
echo "Checking GNOME SDK..."
if flatpak list | grep -q "org.gnome.Sdk"; then
    echo "✓ GNOME SDK installed"
else
    echo "✗ GNOME SDK not found"
    echo "Installing GNOME SDK..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub org.gnome.Sdk//45 org.gnome.Platform//45
fi

# Check dependencies
echo ""
echo "Checking Linux dependencies..."
DEPS=(
    "build-essential"
    "cmake"
    "ninja-build"
    "pkg-config"
    "libgtk-3-dev"
    "libsecret-1-dev"
    "libjsoncpp-dev"
    "sqlite3"
    "libsqlite3-dev"
    "clang"
    "libclang-dev"
)

MISSING_DEPS=()
for dep in "${DEPS[@]}"; do
    if ! dpkg -l | grep -q "^ii  $dep "; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo "✓ All required dependencies installed"
else
    echo "✗ Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Installing missing dependencies..."
    sudo apt update
    sudo apt install -y "${MISSING_DEPS[@]}"
fi

# Check disk space
echo ""
echo "Checking disk space..."
DISK_USAGE=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "⚠️  Low disk space: ${DISK_USAGE}% used"
    echo "Consider freeing up space before building"
else
    echo "✓ Disk space OK: ${DISK_USAGE}% used"
fi

# Check memory
echo ""
echo "Checking memory..."
MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
if [ "$MEMORY_GB" -lt 4 ]; then
    echo "⚠️  Low memory: ${MEMORY_GB}GB available (recommended: 4GB+)"
else
    echo "✓ Memory OK: ${MEMORY_GB}GB available"
fi

# Test Flutter build
echo ""
echo "Testing Flutter build..."
cd ~/lotti

# Get dependencies
echo "Getting Flutter packages..."
flutter pub get

# Generate code
echo "Generating code..."
make build_runner

# Try debug build first (faster)
echo "Testing debug build..."
if flutter build linux --debug; then
    echo "✓ Debug build successful"
    if [ -f "build/linux/x64/debug/bundle/lotti" ]; then
        echo "✓ Executable created successfully"
    else
        echo "✗ Executable not found after successful build"
    fi
else
    echo "✗ Debug build failed"
    echo "Trying release build..."
    if flutter build linux --release; then
        echo "✓ Release build successful"
        if [ -f "build/linux/x64/release/bundle/lotti" ]; then
            echo "✓ Executable created successfully"
        else
            echo "✗ Executable not found after successful build"
        fi
    else
        echo "✗ Both debug and release builds failed"
        echo "Check the error messages above for specific issues"
    fi
fi

echo ""
echo "=== Troubleshooting Complete ==="
echo ""
echo "If builds are successful, you can now run:"
echo "  ./flatpak/build-working-vm.sh"
echo ""
echo "If builds failed, check the error messages above and:"
echo "1. Make sure you have enough disk space (10GB+)"
echo "2. Make sure you have enough memory (4GB+)"
echo "3. Try running: flutter doctor"
echo "4. Check if all dependencies are installed" 