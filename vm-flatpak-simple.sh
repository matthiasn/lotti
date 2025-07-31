#!/bin/bash

# Simple Lotti VM Flatpak Build Script
# This script builds the Flutter app first, then packages it as Flatpak

set -e

echo "=== Simple Lotti VM Flatpak Build ==="

# Update system
echo "Updating system packages..."
sudo apt update

# Install Flatpak
echo "Installing Flatpak..."
sudo apt install -y flatpak flatpak-builder

# Add Flathub repository
echo "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install required SDK
echo "Installing GNOME SDK..."
flatpak install flathub org.gnome.Sdk//45 org.gnome.Platform//45

# Check if we're in the right directory
echo "Current directory: $(pwd)"
echo "Checking for required files..."

# Verify required files exist
if [ ! -f "flatpak/com.matthiasnehlsen.lotti.desktop" ]; then
    echo "✗ Desktop file not found"
    exit 1
fi

if [ ! -f "flatpak/com.matthiasnehlsen.lotti.metainfo.xml" ]; then
    echo "✗ Metainfo file not found"
    exit 1
fi

if [ ! -f "assets/icon/app_icon_1024.png" ]; then
    echo "✗ Icon file not found"
    exit 1
fi

echo "✓ All required files found"

# Create a simple manifest that uses the existing build
echo "Creating simple manifest..."

cat > flatpak/com.matthiasnehlsen.lotti.simple.yml << 'EOF'
app-id: com.matthiasnehlsen.lotti
runtime: org.gnome.Platform
runtime-version: '45'
sdk: org.gnome.Sdk
command: lotti
finish-args:
  - --share=network
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --socket=pulseaudio
  - --filesystem=xdg-documents:rw
  - --filesystem=xdg-pictures:ro
  - --filesystem=xdg-download:rw
  - --device=dri
modules:
  - name: lotti
    buildsystem: simple
    build-commands:
      - install -D lotti /app/bin/lotti
      - install -D com.matthiasnehlsen.lotti.desktop /app/share/applications/com.matthiasnehlsen.lotti.desktop
      - install -D com.matthiasnehlsen.lotti.metainfo.xml /app/share/metainfo/com.matthiasnehlsen.lotti.metainfo.xml
      - |
        for size in 1024 512 256 128 64 48 32 16; do
          install -D app_icon_1024.png /app/share/icons/hicolor/${size}x${size}/apps/com.matthiasnehlsen.lotti.png
        done
    sources:
      - type: file
        path: lotti
      - type: file
        path: com.matthiasnehlsen.lotti.desktop
      - type: file
        path: com.matthiasnehlsen.lotti.metainfo.xml
      - type: file
        path: ../assets/icon/app_icon_1024.png
        dest-filename: app_icon_1024.png
EOF

# First, try to build the Flutter app normally
echo "Building Flutter app first..."
flutter pub get
make build_runner
flutter build linux

# Check if the build succeeded
if [ -f "build/linux/x64/release/bundle/lotti" ]; then
    echo "✓ Flutter build succeeded"
    cp build/linux/x64/release/bundle/lotti flatpak/
elif [ -f "build/linux/x64/debug/bundle/lotti" ]; then
    echo "✓ Flutter debug build succeeded"
    cp build/linux/x64/debug/bundle/lotti flatpak/
else
    echo "✗ Flutter build failed"
    echo "Trying alternative approach..."
    
    # Try to download a pre-built release
    echo "Downloading pre-built release..."
    cd ~
    wget https://github.com/matthiasn/lotti/releases/latest/download/linux.x64.tar.gz
    tar xf linux.x64.tar.gz
    cp lotti/lotti ~/lotti/flatpak/
    cd ~/lotti
fi

# Build the Flatpak
echo "Building Flatpak..."
cd flatpak
flatpak-builder --force-clean --repo=repo build-dir com.matthiasnehlsen.lotti.simple.yml

echo ""
echo "=== Flatpak Build Completed! ==="
echo ""
echo "To install the Flatpak:"
echo "  flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify"
echo "  flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
echo ""
echo "To run directly from build:"
echo "  flatpak-builder --run build-dir com.matthiasnehlsen.lotti.simple.yml lotti"
echo ""
echo "To create a bundle:"
echo "  flatpak build-bundle repo lotti.flatpak com.matthiasnehlsen.lotti" 