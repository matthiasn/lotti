#!/bin/bash

# Desktop Integration Script for Lotti Development Environment
# This script installs the .desktop file and icons for development testing
#
# Security Features:
# - Uses mktemp for secure temporary file creation
# - Properly escapes paths to prevent injection attacks
# - Comprehensive error handling with cleanup
# - Validates all operations before proceeding
#
# Usage: ./linux/install_dev_desktop_integration.sh
# Requirements: bash, sed, find, cp, mkdir
# 
# Author: Generated for Lotti Flutter app Linux desktop integration
# License: Same as parent project

set -euo pipefail  # Fail on errors, undefined variables, and pipe failures
IFS=$'\n\t'        # Set secure Internal Field Separator

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate environment
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Error: Project root directory not found: $PROJECT_ROOT" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
    echo "Error: This doesn't appear to be a Flutter project (no pubspec.yaml found)" >&2
    exit 1
fi

echo "Installing Lotti desktop integration for development..."
echo "Project root: $PROJECT_ROOT"
echo "Script directory: $SCRIPT_DIR"

# Create user directories if they don't exist
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/share/icons/hicolor

# Create KDE-specific directories for better compatibility
mkdir -p ~/.kde/share/applications 2>/dev/null || true

# Copy desktop file to user applications directory
echo "Installing desktop file..."
DESKTOP_FILE="$SCRIPT_DIR/com.matthiasnehlsen.lotti.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    # Create a development version of the desktop file with absolute paths
    # Use mktemp for secure temporary file creation
    TEMP_DESKTOP=$(mktemp) || {
        echo "Error: Failed to create temporary file"
        exit 1
    }
    
    # Properly escape paths for sed to prevent injection
    ESCAPED_EXEC_PATH=$(printf '%s\n' "$PROJECT_ROOT/build/linux/x64/debug/bundle/lotti" | sed 's/[[\.*^$()+?{|]/\\&/g')
    ESCAPED_ICON_PATH=$(printf '%s\n' "$PROJECT_ROOT/assets/icon/app_icon_1024.png" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Use secure sed operations with proper escaping
    sed "s|Exec=lotti|Exec=${ESCAPED_EXEC_PATH}|g" "$DESKTOP_FILE" > "$TEMP_DESKTOP" || {
        echo "Error: Failed to process desktop file"
        rm -f "$TEMP_DESKTOP"
        exit 1
    }
    sed -i "s|Icon=com.matthiasnehlsen.lotti|Icon=${ESCAPED_ICON_PATH}|g" "$TEMP_DESKTOP" || {
        echo "Error: Failed to update icon path"
        rm -f "$TEMP_DESKTOP"
        exit 1
    }
    
    cp "$TEMP_DESKTOP" ~/.local/share/applications/com.matthiasnehlsen.lotti.desktop || {
        echo "Error: Failed to install desktop file"
        rm -f "$TEMP_DESKTOP"
        exit 1
    }
    
    # Also copy to KDE-specific locations for better compatibility
    if [ -d ~/.kde/share/applications ]; then
        if cp "$TEMP_DESKTOP" ~/.kde/share/applications/com.matthiasnehlsen.lotti.desktop 2>/dev/null; then
            echo "Desktop file also copied to ~/.kde/share/applications/"
        fi
    fi
    
    rm -f "$TEMP_DESKTOP"
    echo "Desktop file installed to ~/.local/share/applications/"
else
    echo "Error: Desktop file not found at $DESKTOP_FILE"
    exit 1
fi

# Copy icons to user icon directory
echo "Installing icons..."
ICON_SOURCE_DIR="$SCRIPT_DIR/icons/hicolor"
if [ -d "$ICON_SOURCE_DIR" ]; then
    # Ensure target directory exists before copying
    mkdir -p ~/.local/share/icons/hicolor || {
        echo "Error: Failed to create icon directory"
        exit 1
    }
    
    # Copy icons with proper error handling and preserve attributes
    if [ "$(find "$ICON_SOURCE_DIR" -name "*.png" | wc -l)" -gt 0 ]; then
        cp -r "$ICON_SOURCE_DIR"/* ~/.local/share/icons/hicolor/ || {
            echo "Error: Failed to copy icons"
            exit 1
        }
        echo "Icons installed to ~/.local/share/icons/hicolor/"
    else
        echo "Warning: No icon files found in $ICON_SOURCE_DIR"
    fi
else
    echo "Error: Icon directory not found at $ICON_SOURCE_DIR"
    exit 1
fi

# Update desktop database
echo "Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database ~/.local/share/applications
    echo "Desktop database updated"
else
    echo "Warning: update-desktop-database not found, you may need to log out and back in"
fi

# Update icon cache
echo "Updating icon cache..."
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
    echo "Icon cache updated"
else
    echo "Warning: gtk-update-icon-cache not found, icons may not appear immediately"
fi

# Update KDE icon cache (for Kubuntu/KDE Plasma)
echo "Updating KDE icon cache..."
if command -v kbuildsycoca5 &> /dev/null; then
    kbuildsycoca5 --noincremental
    echo "KDE icon cache updated (kbuildsycoca5)"
elif command -v kbuildsycoca4 &> /dev/null; then
    kbuildsycoca4 --noincremental
    echo "KDE icon cache updated (kbuildsycoca4)"
else
    echo "Info: KDE icon cache update not available (not running KDE)"
fi

echo ""
echo "Desktop integration installed successfully!"
echo ""
echo "To test:"
echo "1. Build the app: flutter build linux"
echo "2. Run this script: ./linux/install_dev_desktop_integration.sh"
echo "3. Launch the app from Android Studio or run: $PROJECT_ROOT/build/linux/x64/debug/bundle/lotti"
echo "4. Check the Ubuntu dock/sidebar for the correct Lotti icon"
echo ""
echo "Note: You may need to restart your desktop session for changes to take full effect." 