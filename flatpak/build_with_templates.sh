#!/bin/bash

# Automated Flatpak build script with proper template substitution
set -euo pipefail

source .env

# Default values - can be overridden by environment variables
readonly LOTTI_VERSION=${LOTTI_VERSION:-"v0.9.645"}
readonly LOTTI_RELEASE_DATE=${LOTTI_RELEASE_DATE:-"2025-01-26"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "   Lotti Flatpak Build with Templates    "
echo "=========================================="
echo "Version: ${LOTTI_VERSION}"
echo "Release Date: ${LOTTI_RELEASE_DATE}"
echo ""

# Clean previous builds unless SKIP_CLEAN is set
if [ "${SKIP_CLEAN:-}" != "true" ] && [ "${SKIP_CLEAN:-}" != "1" ]; then
    print_status "Cleaning previous build artifacts..."
    
    # Remove build directories
    rm -rf flutter-bundle
    rm -rf build-dir
    rm -rf repo
    rm -rf .flatpak-builder
    rm -f com.matthiasnehlsen.lotti.generated.metainfo.xml
    
    # Clean Flutter build in parent directory
    print_status "Cleaning Flutter build artifacts..."
    (cd .. && flutter clean) || print_warning "Flutter clean failed - continuing anyway"
    
    print_status "Clean complete!"
else
    print_warning "Skipping clean (SKIP_CLEAN is set)"
fi

# Generate the metainfo file from template
print_status "Generating metainfo file from template..."
if ! sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        com.matthiasnehlsen.lotti.metainfo.xml > com.matthiasnehlsen.lotti.generated.metainfo.xml; then
    print_error "Failed to generate metainfo file"
    exit 1
fi

print_status "Generated metainfo file with version ${LOTTI_VERSION} and date ${LOTTI_RELEASE_DATE}"

# Build Flutter app if needed
if [ ! -d "../build/linux/x64/release/bundle" ]; then
    print_status "Building Flutter Linux release..."
    if ! (cd .. && flutter build linux --release); then
        print_error "Flutter build failed!"
        exit 1
    fi
    print_status "Flutter build complete!"
fi

# Check if Flutter bundle exists
if [ ! -d "flutter-bundle" ]; then
    print_status "Preparing Flutter bundle..."
    if [ ! -d "../build/linux/x64/release/bundle" ]; then
        print_error "No Flutter build found. Please run 'flutter build linux --release' first."
        exit 1
    fi
    
    mkdir -p flutter-bundle
    cp -r ../build/linux/x64/release/bundle/* flutter-bundle/
    
    # Remove oversized icons
    rm -rf flutter-bundle/share/icons/hicolor/1024x1024/ 2>/dev/null || true
    find flutter-bundle -name "*1024*" -type f -delete 2>/dev/null || true
    
    print_status "Flutter bundle prepared"
fi

# Build Flatpak using local manifest (which doesn't need template substitution)
print_status "Building Flatpak package..."
if ! flatpak-builder --repo=repo --force-clean build-dir com.matthiasnehlsen.lotti.local.yml; then
    print_error "Flatpak build failed!"
    exit 1
fi

print_status "Flatpak build complete!"

# Install if requested or if run is requested without install
if [ "${1:-}" = "install" ] || [ "${1:-}" = "run" ] || [ "${2:-}" = "run" ]; then
    print_status "Installing Flatpak..."
    
    # Add repo if not exists
    flatpak --user remote-add --no-gpg-verify --if-not-exists lotti-repo repo
    
    # Install
    flatpak --user install -y lotti-repo com.matthiasnehlsen.lotti
    
    print_status "Installation complete!"
    print_status "You can now run: flatpak run com.matthiasnehlsen.lotti"
fi

# Run if requested
if [ "${1:-}" = "run" ] || [ "${2:-}" = "run" ]; then
    print_status "Running Lotti app..."
    flatpak run com.matthiasnehlsen.lotti &
fi

# Auto-run if AUTORUN environment variable is set
if [ "${AUTORUN:-}" = "true" ] || [ "${AUTORUN:-}" = "1" ]; then
    print_status "Auto-launching Lotti app..."
    flatpak run com.matthiasnehlsen.lotti &
fi

print_status "Build completed successfully!"
echo ""
echo "Template variables used:"
echo "  LOTTI_VERSION=${LOTTI_VERSION}"
echo "  LOTTI_RELEASE_DATE=${LOTTI_RELEASE_DATE}"
echo ""
echo "Usage:"
echo "  $0                    - Build only"
echo "  $0 install           - Build and install" 
echo "  $0 install run       - Build, install and run"
echo "  $0 run               - Build and run (auto-installs if needed)"
echo ""
echo "Environment variables:"
echo "  LOTTI_VERSION=v1.0.0 LOTTI_RELEASE_DATE=2025-09-17 $0"
echo "  AUTORUN=true $0      - Automatically launch app after build"
echo "  SKIP_CLEAN=true $0   - Skip cleaning previous builds (faster rebuilds)"