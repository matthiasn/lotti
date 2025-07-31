#!/bin/bash

# Lotti VM Download Release Script
# This script downloads and runs a pre-built release from GitHub

set -e

echo "=== Downloading Lotti Pre-built Release ==="

# Create a directory for the release
mkdir -p ~/lotti-release
cd ~/lotti-release

# Download the latest release
echo "Downloading latest Lotti release..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/matthiasn/lotti/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
echo "Latest release: $LATEST_RELEASE"

# Download the Linux release
echo "Downloading Linux release..."
wget "https://github.com/matthiasn/lotti/releases/download/$LATEST_RELEASE/linux.x64.tar.gz"

# Extract the release
echo "Extracting release..."
tar xf linux.x64.tar.gz

# Check if the executable exists
if [ -f "lotti/lotti" ]; then
    echo "✓ Release extracted successfully"
    echo ""
    echo "Running Lotti..."
    echo "You can also run it manually with: ./lotti/lotti"
    echo ""
    
    # Make it executable and run
    chmod +x lotti/lotti
    ./lotti/lotti
else
    echo "✗ Release extraction failed or executable not found"
    echo "Checking what was extracted:"
    ls -la
    if [ -d "lotti" ]; then
        ls -la lotti/
    fi
fi

echo ""
echo "=== Alternative Downloads ==="
echo "If the above doesn't work, you can try:"
echo "1. Download from releases page: https://github.com/matthiasn/lotti/releases"
echo "2. Look for 'linux.x64.tar.gz' files"
echo "3. Extract and run manually" 