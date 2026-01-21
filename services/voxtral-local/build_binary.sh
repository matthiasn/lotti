#!/bin/bash
# Build Voxtral server as a standalone binary using PyInstaller
#
# Usage:
#   ./build_binary.sh
#
# Prerequisites:
#   - Python 3.9+ with pip
#   - FFmpeg installed (brew install ffmpeg / apt install ffmpeg)
#   - libsndfile installed (brew install libsndfile / apt install libsndfile1)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building Voxtral Server Binary ==="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

# Build the binary
echo "Building binary with PyInstaller..."
pyinstaller voxtral_server.spec --clean

# Check if build succeeded
if [ -f "dist/voxtral_server" ]; then
    echo ""
    echo "=== Build successful! ==="
    echo "Binary location: $SCRIPT_DIR/dist/voxtral_server"
    echo ""
    echo "To run:"
    echo "  ./dist/voxtral_server"
    echo ""
    echo "To package for distribution:"
    echo "  cd dist && tar -czvf voxtral_server-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz voxtral_server"
else
    echo "Build failed!"
    exit 1
fi
