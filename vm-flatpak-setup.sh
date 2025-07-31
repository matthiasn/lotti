#!/bin/bash

# Lotti VM Flatpak Setup Script
# This script sets up and builds Lotti using Flatpak

set -e

echo "=== Lotti VM Flatpak Setup ==="

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
echo "Checking for flatpak build script..."
if [ -f "flatpak/build.sh" ]; then
    echo "✓ Flatpak build script found"
else
    echo "✗ Flatpak build script not found"
    exit 1
fi

# Try the Flatpak build
echo "Attempting Flatpak build..."
echo "This might take a while as it downloads and builds dependencies..."

./flatpak/build.sh

echo ""
echo "If the Flatpak build succeeds, you can install it with:"
echo "  flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify"
echo "  flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
echo ""
echo "Or run it directly with:"
echo "  flatpak-builder --run build-dir flatpak/com.matthiasnehlsen.lotti.generated.yml lotti" 