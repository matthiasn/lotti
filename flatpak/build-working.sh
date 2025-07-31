#!/bin/bash

# Working Lotti Flatpak Build Script for Kubuntu VM
# This script builds the Flutter app first, then packages it as Flatpak

set -e

echo "=== Working Lotti Flatpak Build for Kubuntu VM ==="

# Check if we're in the lotti directory
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: Please run this script from the lotti repository root"
    exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo apt update

# Install Flatpak if not already installed
if ! command -v flatpak &> /dev/null; then
    echo "Installing Flatpak..."
    sudo apt install -y flatpak flatpak-builder
fi

# Add Flathub repository
echo "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install required SDK
echo "Installing GNOME SDK..."
flatpak install -y flathub org.gnome.Sdk//45 org.gnome.Platform//45

# Get Flutter dependencies
echo "Getting Flutter packages..."
flutter pub get

# Generate code
echo "Generating code with build_runner..."
make build_runner

# Build Flutter app for Linux
echo "Building Flutter app for Linux..."
flutter build linux --release

# Check if the build succeeded
if [ ! -f "build/linux/x64/release/bundle/lotti" ]; then
    echo "Error: Flutter build failed. The executable was not created."
    exit 1
fi

echo "✓ Flutter build succeeded"

# Create working directory for Flatpak build
echo "Preparing Flatpak build..."
mkdir -p flatpak/build-files
cp build/linux/x64/release/bundle/lotti flatpak/build-files/
cp flatpak/com.matthiasnehlsen.lotti.desktop flatpak/build-files/
cp assets/icon/app_icon_1024.png flatpak/build-files/

# Create a working manifest that uses simple buildsystem
echo "Creating working Flatpak manifest..."

cat > flatpak/com.matthiasnehlsen.lotti.working.yml << 'EOF'
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
        path: app_icon_1024.png
EOF

# Build the Flatpak
echo "Building Flatpak..."
cd flatpak
flatpak-builder --force-clean --repo=repo build-dir com.matthiasnehlsen.lotti.working.yml

echo ""
echo "=== Flatpak Build Completed Successfully! ==="
echo ""
echo "To install the Flatpak:"
echo "  flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify"
echo "  flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
echo ""
echo "To run the app:"
echo "  flatpak run com.matthiasnehlsen.lotti"
echo ""
echo "To create a bundle for distribution:"
echo "  flatpak build-bundle repo lotti.flatpak com.matthiasnehlsen.lotti" 