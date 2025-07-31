#!/bin/bash

# Fixed Lotti VM Flatpak Build Script
# This script fixes the path issues in the Flatpak build

set -e

echo "=== Fixed Lotti VM Flatpak Build ==="

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
echo "Checking for flatpak files..."

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

# Create a fixed manifest that works in the VM
echo "Creating fixed manifest..."

cat > flatpak/com.matthiasnehlsen.lotti.fixed.yml << 'EOF'
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
    buildsystem: flutter
    build-options:
      strip: true
      no-debuginfo: true
    sources:
      - type: git
        url: https://github.com/matthiasn/lotti.git
        tag: v0.9.645
    modules:
      - name: flutter-common
        buildsystem: simple
        build-commands:
          - install -D com.matthiasnehlsen.lotti.desktop /app/share/applications/com.matthiasnehlsen.lotti.desktop
          - install -D com.matthiasnehlsen.lotti.metainfo.xml /app/share/metainfo/com.matthiasnehlsen.lotti.metainfo.xml
          - |
            for size in 1024 512 256 128 64 48 32 16; do
              install -D app_icon_1024.png /app/share/icons/hicolor/${size}x${size}/apps/com.matthiasnehlsen.lotti.png
            done
        sources:
          - type: file
            path: com.matthiasnehlsen.lotti.desktop
          - type: file
            path: com.matthiasnehlsen.lotti.metainfo.xml
          - type: file
            path: app_icon_1024.png
EOF

# Copy required files to the flatpak directory
echo "Copying required files..."
cp flatpak/com.matthiasnehlsen.lotti.desktop flatpak/
cp flatpak/com.matthiasnehlsen.lotti.metainfo.xml flatpak/
cp assets/icon/app_icon_1024.png flatpak/

# Build the Flatpak
echo "Building Flatpak with fixed manifest..."
cd flatpak
flatpak-builder --force-clean --repo=repo build-dir com.matthiasnehlsen.lotti.fixed.yml

echo ""
echo "=== Flatpak Build Completed! ==="
echo ""
echo "To install the Flatpak:"
echo "  flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify"
echo "  flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
echo ""
echo "To run directly from build:"
echo "  flatpak-builder --run build-dir com.matthiasnehlsen.lotti.fixed.yml lotti"
echo ""
echo "To create a bundle:"
echo "  flatpak build-bundle repo lotti.flatpak com.matthiasnehlsen.lotti" 