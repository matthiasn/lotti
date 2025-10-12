#!/bin/bash
# Install emoji font configuration for local development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTCONFIG_SRC="../flatpak/75-noto-color-emoji.conf"
FONTCONFIG_DEST="/etc/fonts/conf.d/75-noto-color-emoji.conf"

echo "Installing Noto Color Emoji font configuration..."

# Check if the source file exists
if [ ! -f "$SCRIPT_DIR/$FONTCONFIG_SRC" ]; then
    echo "Error: Font configuration file not found at $SCRIPT_DIR/$FONTCONFIG_SRC"
    exit 1
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
