#!/bin/bash

# Simple Lotti VM Setup Script
# This script sets up minimal dependencies to run Lotti in debug mode

set -e

echo "=== Simple Lotti VM Setup ==="

# Update system
echo "Updating system packages..."
sudo apt update

# Install minimal required dependencies
echo "Installing minimal dependencies..."
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
    libkeybinder-3.0-dev \
    libmpv-dev

# Install Flutter if not already installed
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    cd ~
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.5-stable.tar.xz
    tar xf flutter_linux_3.32.5-stable.tar.xz
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/flutter/bin"
    cd -
else
    echo "Flutter already installed"
fi

echo "Setting up Lotti project..."

# Get Flutter dependencies
echo "Getting Flutter packages..."
flutter pub get

# Generate code
echo "Generating code with build_runner..."
make build_runner

echo "=== Setup completed! ==="
echo ""
echo "Now try running the app in debug mode:"
echo "  flutter run -d linux"
echo ""
echo "If that fails, try running with verbose output:"
echo "  flutter run -d linux --verbose"
echo ""
echo "Alternative: Try building with specific flags:"
echo "  flutter build linux --debug --verbose" 