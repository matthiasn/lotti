#!/bin/bash

# Lotti VM Setup Script for Kubuntu
# This script sets up the environment and builds Lotti in a Kubuntu VM

set -e

echo "=== Lotti VM Setup Script ==="
echo "Setting up Lotti development environment in Kubuntu VM..."

# Update system
echo "Updating system packages..."
sudo apt update

# Install required dependencies
echo "Installing Flutter dependencies..."
sudo apt install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    libsecret-1-dev \
    libjsoncpp-dev \
    libjsoncpp1 \
    libsecret-1-0 \
    sqlite3 \
    libsqlite3-dev \
    pulseaudio-utils \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev

# Install Flutter if not already installed
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    cd ~
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
    tar xf flutter_linux_3.16.5-stable.tar.xz
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/flutter/bin"
    cd -
else
    echo "Flutter already installed"
fi

# Navigate to lotti directory (assuming it's in current directory)
echo "Setting up Lotti project..."

# Get Flutter dependencies
echo "Getting Flutter packages..."
flutter pub get

# Generate code
echo "Generating code with build_runner..."
make build_runner

# Build for Linux
echo "Building Lotti for Linux..."
flutter build linux

echo "=== Build completed successfully! ==="
echo ""
echo "To run the app:"
echo "  ./build/linux/x64/debug/bundle/lotti"
echo ""
echo "To install desktop integration:"
echo "  ./linux/install_dev_desktop_integration.sh"
echo ""
echo "Alternative: Try Flatpak build:"
echo "  sudo apt install flatpak flatpak-builder"
echo "  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
echo "  flatpak install flathub org.gnome.Sdk//45 org.gnome.Platform//45"
echo "  ./flatpak/build.sh" 