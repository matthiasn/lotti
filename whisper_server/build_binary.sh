#!/bin/bash
# Build Whisper server as a standalone binary using PyInstaller
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

echo "=== Building Whisper Server Binary ==="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Determine requirements file based on platform and architecture
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        REQUIREMENTS="requirements_apple_silicon.txt"
    else
        REQUIREMENTS="requirements_macos_intel.txt"
    fi
elif [[ "$(uname)" == "Linux" ]]; then
    REQUIREMENTS="requirements_linux.txt"
else
    REQUIREMENTS="requirements.txt"
fi

# Install dependencies
echo "Installing dependencies from $REQUIREMENTS..."
pip install --upgrade pip
pip install -r "$REQUIREMENTS"
pip install pyinstaller

# Build the binary
echo "Building binary with PyInstaller..."
pyinstaller whisper_api_server.spec --clean

# Check if build succeeded
if [ -f "dist/whisper_api_server" ]; then
    echo ""
    echo "=== Build successful! ==="
    echo "Binary location: $SCRIPT_DIR/dist/whisper_api_server"
    echo ""
    echo "To run:"
    echo "  ./dist/whisper_api_server"
    echo ""
    echo "To package for distribution:"
    echo "  cd dist && tar -czvf whisper_server-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz whisper_api_server"
else
    echo "Build failed!"
    exit 1
fi
