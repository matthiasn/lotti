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

# Check if we're on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Error: This script must be run on Linux (Kubuntu VM)"
    echo "Current OS: $OSTYPE"
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

# Install Flutter dependencies for Linux
echo "Installing Flutter Linux dependencies..."
sudo apt install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    libsecret-1-dev \
    libjsoncpp-dev \
    libsecret-1-0 \
    sqlite3 \
    libsqlite3-dev \
    pulseaudio-utils \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    clang \
    libclang-dev \
    libgtk-3-dev \
    libblkid-dev \
    liblzma-dev \
    libsqlite3-dev \
    libssl-dev \
    libzstd-dev \
    libgirepository1.0-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    gstreamer1.0-x \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-qt5 \
    gstreamer1.0-pulseaudio

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing Flutter..."
    cd ~
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
    tar xf flutter_linux_3.16.5-stable.tar.xz
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/flutter/bin"
    cd ~/lotti
fi

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
    echo "Trying debug build..."
    flutter build linux --debug
    if [ ! -f "build/linux/x64/debug/bundle/lotti" ]; then
        echo "Error: Both release and debug builds failed."
        exit 1
    else
        echo "✓ Flutter debug build succeeded"
        cp build/linux/x64/debug/bundle/lotti flatpak/
    fi
else
    echo "✓ Flutter release build succeeded"
    cp build/linux/x64/release/bundle/lotti flatpak/
fi

# Create working directory for Flatpak build
echo "Preparing Flatpak build..."
mkdir -p flatpak/build-files
cp flatpak/lotti flatpak/build-files/
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