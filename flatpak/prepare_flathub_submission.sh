#!/bin/bash

# Robust Flathub submission preparation script
# Generates all offline build files in a clean subdirectory

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOTTI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLATPAK_DIR="$LOTTI_ROOT/flatpak"

# Work directory for generation
WORK_DIR="$FLATPAK_DIR/flathub-build"
OUTPUT_DIR="$WORK_DIR/output"

# Version configuration
if [ -z "${LOTTI_VERSION:-}" ]; then
    # Extract version from pubspec.yaml (e.g., "0.9.665+3266" -> "0.9.665")
    PUBSPEC_VERSION=$(grep "^version:" "$LOTTI_ROOT/pubspec.yaml" | sed 's/version: //;s/+.*//')
    if [ -n "$PUBSPEC_VERSION" ]; then
        LOTTI_VERSION="$PUBSPEC_VERSION"
        print_info "Using version from pubspec.yaml: $LOTTI_VERSION"
    else
        # Fallback to git tag or default
        LOTTI_VERSION=$(cd "$LOTTI_ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo "0.9.645")
        print_warning "Could not extract version from pubspec.yaml, using: $LOTTI_VERSION"
    fi
fi

if [ -z "${LOTTI_RELEASE_DATE:-}" ]; then
    LOTTI_RELEASE_DATE=$(date +%Y-%m-%d)
fi

# Get the current HEAD commit (not based on version tag)
COMMIT_HASH=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)

# Check if commit exists on remote
if ! git ls-remote origin "$COMMIT_HASH" > /dev/null 2>&1; then
    print_warning "Current commit $COMMIT_HASH not found on remote"
    print_info "Using latest remote commit from current branch instead"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMIT_HASH=$(git ls-remote origin "refs/heads/$CURRENT_BRANCH" | cut -f1)
    if [ -z "$COMMIT_HASH" ]; then
        print_error "Could not find remote commit. Please push your changes first."
        exit 1
    fi
    print_info "Using remote commit: $COMMIT_HASH"
fi

echo "=========================================="
echo "   Flathub Submission Preparation Script"
echo "=========================================="
echo "Version: ${LOTTI_VERSION}"
echo "Release Date: ${LOTTI_RELEASE_DATE}"
echo "Commit: ${COMMIT_HASH}"
echo ""

# Step 1: Clean and create work directory
print_status "Creating clean work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

# Step 2: Copy source manifest to work directory
print_status "Preparing source manifest..."
cp "$FLATPAK_DIR/com.matthiasn.lotti.source.yml" "$WORK_DIR/com.matthiasn.lotti.yml"

# For local testing, we can use a directory source instead of git
if [ "${USE_LOCAL_SOURCE:-false}" == "true" ]; then
    print_info "Using local directory source instead of git"
    # Replace the git source with a local directory source
    sed -i '/- type: git/,/commit: COMMIT_PLACEHOLDER/{
        s|type: git|type: dir|
        s|url: https://github.com/matthiasn/lotti|path: '"$LOTTI_ROOT"'|
        /commit:/d
    }' "$WORK_DIR/com.matthiasn.lotti.yml"
else
    # Replace COMMIT_PLACEHOLDER with actual commit
    sed -i "s/COMMIT_PLACEHOLDER/$COMMIT_HASH/" "$WORK_DIR/com.matthiasn.lotti.yml"
fi

# Step 3: Check for flatpak-flutter
if [ ! -d "$FLATPAK_DIR/flatpak-flutter" ]; then
    print_status "Cloning flatpak-flutter..."
    cd "$FLATPAK_DIR"
    git clone https://github.com/TheAppgineer/flatpak-flutter.git
fi

# Step 4: Run flatpak-flutter in work directory
print_status "Running flatpak-flutter to generate offline sources..."
cd "$WORK_DIR"

# Copy necessary files to work directory
cp -r "$LOTTI_ROOT/lib" .
cp -r "$LOTTI_ROOT/linux" .
cp "$LOTTI_ROOT/pubspec.yaml" .
cp "$LOTTI_ROOT/pubspec.lock" .

# Run flatpak-flutter
if ! python3 "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" \
    --app-module lotti \
    "com.matthiasn.lotti.yml"; then
    print_error "flatpak-flutter failed to generate files"
    exit 1
fi

print_status "Generated offline manifest and dependencies"

# Step 5: Create the final flathub manifest
print_status "Creating flathub manifest..."

# The generated manifest should be com.matthiasn.lotti.yml
# Copy it to output directory
cp "com.matthiasn.lotti.yml" "$OUTPUT_DIR/"

# Copy all generated JSON files
cp flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No flutter-sdk JSON found"
cp pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No pubspec-sources.json found"
cp cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No cargo-sources.json found"
cp rustup-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No rustup JSON found"
cp package_config.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No package_config.json found"

# Step 6: Copy additional required files
print_status "Copying additional files..."

# Copy metadata files
if [ -f "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" ]; then
    print_info "Processing metainfo.xml with version substitution..."
    sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" > "$OUTPUT_DIR/com.matthiasn.lotti.metainfo.xml"
fi

cp "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$OUTPUT_DIR/" 2>/dev/null || print_warning "No desktop file found"

# Copy icon files
for icon in "$FLATPAK_DIR"/app_icon_*.png; do
    if [ -f "$icon" ]; then
        cp "$icon" "$OUTPUT_DIR/"
    fi
done

# Copy patch directories if needed
if [ -d "$FLATPAK_DIR/patches" ]; then
    cp -r "$FLATPAK_DIR/patches" "$OUTPUT_DIR/"
fi

# Step 7: Test build (optional)
if [ "${TEST_BUILD:-false}" == "true" ]; then
    print_status "Testing build..."
    cd "$OUTPUT_DIR"
    flatpak-builder --force-clean --repo=repo build-dir com.matthiasn.lotti.yml
    if [ $? -eq 0 ]; then
        print_status "Test build successful!"
    else
        print_error "Test build failed"
    fi
fi

# Step 8: Final report
print_status "Preparation complete!"
echo ""
print_info "Generated files are in: $OUTPUT_DIR"
echo ""
print_info "Files generated:"
ls -la "$OUTPUT_DIR"
echo ""

# Check if flathub repo exists
FLATHUB_ROOT="$(cd "$LOTTI_ROOT/.." && pwd)/flathub"
if [ -d "$FLATHUB_ROOT" ]; then
    print_info "To copy to flathub repo:"
    echo "  cp -r $OUTPUT_DIR/* $FLATHUB_ROOT/com.matthiasn.lotti/"
    echo ""
    print_info "Then:"
    echo "  1. cd $FLATHUB_ROOT"
    echo "  2. git checkout -b new-app-com.matthiasn.lotti"
    echo "  3. git add com.matthiasn.lotti"
    echo "  4. git commit -m \"Add com.matthiasn.lotti\""
    echo "  5. git push origin new-app-com.matthiasn.lotti"
    echo "  6. Create PR at https://github.com/flathub/flathub"
else
    print_info "To prepare for Flathub submission:"
    echo "  1. Fork https://github.com/flathub/flathub"
    echo "  2. Clone your fork to ../flathub"
    echo "  3. Copy $OUTPUT_DIR to ../flathub/com.matthiasn.lotti"
    echo "  4. Create a pull request"
fi