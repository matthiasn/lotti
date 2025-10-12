#!/bin/bash
# Install emoji font configuration for local development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTCONFIG_SRC="../flatpak/75-noto-color-emoji.conf"
FONTCONFIG_DEST="/etc/fonts/conf.d/75-noto-color-emoji.conf"

echo "Installing Noto Color Emoji font configuration..."
echo ""

# Check if the source file exists
if [ ! -f "$SCRIPT_DIR/$FONTCONFIG_SRC" ]; then
    echo "Error: Font configuration file not found at $SCRIPT_DIR/$FONTCONFIG_SRC"
    exit 1
fi

# Check if Noto Color Emoji font is installed
if ! fc-list | grep -qi "Noto Color Emoji"; then
    echo "NOTE: This script only installs the font configuration. You must also install the"
    echo "      'Noto Color Emoji' font package."
    echo ""
    echo "For example, on Debian/Ubuntu: sudo apt install fonts-noto-color-emoji"
    echo "             on Fedora:        sudo dnf install google-noto-emoji-color-fonts"
    echo "             on Arch:          sudo pacman -S noto-fonts-emoji"
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install the fontconfig file
echo "Installing fontconfig to $FONTCONFIG_DEST (requires sudo)..."
sudo install -Dm644 "$SCRIPT_DIR/$FONTCONFIG_SRC" "$FONTCONFIG_DEST"

# Rebuild font cache
echo "Rebuilding font cache..."
sudo fc-cache -fv

echo ""
echo "✓ Emoji font configuration installed successfully!"
echo "✓ Please restart your Flutter app to see the changes."
echo ""
echo "To verify the configuration, run:"
echo "  fc-match emoji"
echo ""
