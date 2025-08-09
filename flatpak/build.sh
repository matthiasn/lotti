#!/bin/bash

# Build script for Lotti Flatpak
set -e

# Default values
readonly LOTTI_REPO_URL=${LOTTI_REPO_URL:-"https://github.com/matthiasn/lotti.git"}
readonly LOTTI_VERSION=${LOTTI_VERSION:-$(git rev-parse HEAD)}
readonly LOTTI_RELEASE_DATE=${LOTTI_RELEASE_DATE:-"2025-01-26"}

echo "Building Lotti Flatpak..."
echo "Repository: ${LOTTI_REPO_URL}"
echo "Version: ${LOTTI_VERSION}"
echo "Release Date: ${LOTTI_RELEASE_DATE}"

# Validate inputs
if [[ ! "${LOTTI_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Warning: LOTTI_VERSION '${LOTTI_VERSION}' does not follow expected format 'vX.Y.Z'"
fi

if [[ ! "${LOTTI_RELEASE_DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Warning: LOTTI_RELEASE_DATE '${LOTTI_RELEASE_DATE}' does not follow expected format 'YYYY-MM-DD'"
fi

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
    echo "Error: flatpak-builder is not installed"
    echo "Please install it with: sudo apt install flatpak-builder"
    exit 1
fi

# Create temporary manifest with substituted variables
readonly TEMP_MANIFEST="flatpak/com.matthiasnehlsen.lotti.generated.yml"
readonly TEMP_METAINFO="flatpak/com.matthiasnehlsen.lotti.generated.metainfo.xml"
readonly TEMP_DESKTOP="com.matthiasnehlsen.lotti.desktop"
# Set up cleanup trap
trap 'rm -f "$TEMP_MANIFEST" "$TEMP_METAINFO" "$TEMP_DESKTOP" flatpak/app_icon_1024.png' EXIT

echo "Generating manifest and metainfo files..."

# Generate manifest
if ! sed -e "s|{{LOTTI_REPO_URL}}|${LOTTI_REPO_URL}|g" \
        -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        flatpak/com.matthiasnehlsen.lotti.yml > "${TEMP_MANIFEST}"; then
    echo "Error: Failed to generate manifest file"
    exit 1
fi

# Generate metainfo
if ! sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        flatpak/com.matthiasnehlsen.lotti.metainfo.xml > "${TEMP_METAINFO}"; then
    echo "Error: Failed to generate metainfo file"
    exit 1
fi

# Copy desktop file to project root
if ! cp flatpak/com.matthiasnehlsen.lotti.desktop "${TEMP_DESKTOP}"; then
    echo "Error: Failed to copy desktop file"
    exit 1
fi

# Copy icon file to flatpak directory for build
if ! cp assets/icon/app_icon_1024.png flatpak/app_icon_1024.png; then
    echo "Error: Failed to copy icon file"
    exit 1
fi
echo "Icon file copied successfully to flatpak/app_icon_1024.png"

# Build Flutter app if it doesn't exist
if [ ! -d "build/linux/x64/release/bundle" ]; then
    echo "Flutter app not built. Building now..."
    echo "Getting Flutter dependencies..."
    flutter pub get
    echo "Building Flutter app with all dependencies..."
    if ! flutter build linux --release; then
        echo "Error: Failed to build Flutter app"
        exit 1
    fi
    echo "Flutter app built successfully"
else
    echo "Flutter app already built, skipping build"
fi

# Copy built app to project root for Flatpak build
echo "Copying built app to project root..."
if ! cp -r build/linux/x64/release/bundle .; then
    echo "Error: Failed to copy built app to project root"
    exit 1
fi
echo "Built app copied to project root"

# Add built files to git for Flatpak access
echo "Adding built files to git..."
git add bundle/ || echo "Failed to add bundle to git"
git add -f *.so 2>/dev/null || echo "No .so files to add"
git add -f flutter_assets/ 2>/dev/null || echo "No flutter_assets to add"
git add -f icudtl.dat 2>/dev/null || echo "No icudtl.dat to add"
echo "Committing built files..."
git commit -m "temp: Add built files for Flatpak build" --no-verify || echo "Nothing to commit"

# Copy libkeybinder from system to bundle/lib for Flatpak
echo "Copying libkeybinder from system to bundle/lib..."
if [ -f "/usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0" ]; then
    echo "Found libkeybinder-3.0.so.0 in system, copying to bundle/lib/:"
    cp /usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0 bundle/lib/ 2>/dev/null || echo "Failed to copy libkeybinder-3.0.so.0"
elif [ -f "/usr/lib/libkeybinder-3.0.so.0" ]; then
    echo "Found libkeybinder-3.0.so.0 in /usr/lib, copying to bundle/lib/:"
    cp /usr/lib/libkeybinder-3.0.so.0 bundle/lib/ 2>/dev/null || echo "Failed to copy libkeybinder-3.0.so.0"
else
    echo "libkeybinder-3.0.so.0 not found in system, trying to install it..."
    sudo apt-get update && sudo apt-get install -y libkeybinder-3.0-0 2>/dev/null || echo "Failed to install libkeybinder-3.0-0"
    # Try copying again after installation
    if [ -f "/usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0" ]; then
        echo "Found libkeybinder-3.0.so.0 after installation, copying to bundle/lib/:"
        cp /usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0 bundle/lib/ 2>/dev/null || echo "Failed to copy libkeybinder-3.0.so.0"
    elif [ -f "/usr/lib/libkeybinder-3.0.so.0" ]; then
        echo "Found libkeybinder-3.0.so.0 after installation, copying to bundle/lib/:"
        cp /usr/lib/libkeybinder-3.0.so.0 bundle/lib/ 2>/dev/null || echo "Failed to copy libkeybinder-3.0.so.0"
    else
        echo "libkeybinder-3.0.so.0 still not found after installation attempt"
    fi
fi

echo "Bundle structure:"
ls -la bundle/
ls -la bundle/lib/ 2>/dev/null || echo "No lib directory in bundle"

# Check if lotti executable exists in bundle
if [ ! -f "bundle/lotti" ]; then
    echo "Error: lotti executable not found in bundle"
    echo "Contents of build/linux/x64/release/bundle/:"
    ls -la build/linux/x64/release/bundle/
    exit 1
fi

# Built files are now included as sources in the Flatpak manifest

# Force clean build to avoid cache issues
echo "Cleaning previous build cache..."
rm -rf .flatpak-builder/ build-dir/ || true
echo "Built files are ready for Flatpak packaging"

# Build Flatpak without AppStream validation to get basic functionality working
echo "Building Flatpak without AppStream validation..."
flatpak-builder --force-clean --disable-rofiles-fuse build-dir flatpak/com.matthiasnehlsen.lotti.generated.yml



# Build the Flatpak
echo "Starting Flatpak build..."
if ! flatpak-builder --force-clean --repo=repo build-dir "${TEMP_MANIFEST}"; then
    echo "Error: Flatpak build failed"
    exit 1
fi

echo "Flatpak build completed successfully!"
echo ""
echo "To install from the local repository:"
echo "  flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify && flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
echo ""
echo "To create a bundle:"
echo "  flatpak build-bundle repo lotti.flatpak com.matthiasnehlsen.lotti"
echo ""
echo "To run directly from build:"
echo "  flatpak-builder --run build-dir ${TEMP_MANIFEST} lotti"

echo ""
echo "Environment variables used:"
echo "  LOTTI_REPO_URL=${LOTTI_REPO_URL}"
echo "  LOTTI_VERSION=${LOTTI_VERSION}"
echo "  LOTTI_RELEASE_DATE=${LOTTI_RELEASE_DATE}"

# Note: temporary files will be cleaned up by the EXIT trap 