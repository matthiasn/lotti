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
if ! cp -r build/linux/x64/release/bundle/* .; then
    echo "Error: Failed to copy built app to project root"
    exit 1
fi
echo "Built app copied to project root"
echo "Files in project root:"
ls -la

# Check if lotti executable exists
if [ ! -f "lotti" ]; then
    echo "Error: lotti executable not found after copy"
    echo "Contents of build/linux/x64/release/bundle/:"
    ls -la build/linux/x64/release/bundle/
    exit 1
fi

# Built files are now included as sources in the Flatpak manifest
echo "Built files are ready for Flatpak packaging"



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