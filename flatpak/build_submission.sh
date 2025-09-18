#!/bin/bash
# Build and test the submission manifest (non-local version)

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "=========================================="
echo "   Lotti Flatpak Submission Build Test   "
echo "=========================================="
echo ""

# Clean previous test builds
if [ "${SKIP_CLEAN:-}" != "true" ]; then
    print_status "Cleaning previous submission build artifacts..."
    rm -rf submission-build submission-repo
else
    print_warning "Skipping clean (SKIP_CLEAN is set)"
fi

# Build using the submission manifest
print_status "Building submission manifest (com.matthiasn.lotti.yml)..."
if flatpak-builder --repo=submission-repo --force-clean submission-build com.matthiasn.lotti.yml; then
    print_status "Build successful!"

    # Install from test repo
    if [ "${1:-}" = "install" ] || [ "${1:-}" = "run" ]; then
        print_status "Installing from submission repo..."
        flatpak --user remote-add --no-gpg-verify --if-not-exists lotti-submission-repo submission-repo
        flatpak --user install -y lotti-submission-repo com.matthiasn.lotti

        print_status "Installation complete!"
        print_status "You can run: flatpak run com.matthiasn.lotti"
    fi

    # Run if requested
    if [ "${1:-}" = "run" ]; then
        print_status "Launching app..."
        flatpak run com.matthiasn.lotti &
    fi

    echo ""
    echo "Build completed successfully!"
    echo ""
    echo "Usage:"
    echo "  $0              - Build only"
    echo "  $0 install      - Build and install"
    echo "  $0 run          - Build, install and run"
    echo ""
    echo "Environment variables:"
    echo "  SKIP_CLEAN=true $0  - Skip cleaning previous builds"
else
    print_error "Build failed!"
    exit 1
fi