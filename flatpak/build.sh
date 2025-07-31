#!/bin/bash

# Build script for Lotti Flatpak
set -e

# Default values
readonly LOTTI_REPO_URL=${LOTTI_REPO_URL:-"https://github.com/matthiasn/lotti.git"}
readonly LOTTI_VERSION=${LOTTI_VERSION:-"v0.9.645"}
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
readonly TEMP_MANIFEST="com.matthiasnehlsen.lotti.generated.yml"
readonly TEMP_METAINFO="com.matthiasnehlsen.lotti.generated.metainfo.xml"

# Set up cleanup trap
trap 'rm -f "$TEMP_MANIFEST" "$TEMP_METAINFO" ../com.matthiasnehlsen.lotti.desktop ../com.matthiasnehlsen.lotti.generated.metainfo.xml' EXIT

echo "Generating manifest and metainfo files..."

# Generate manifest
if ! sed -e "s|{{LOTTI_REPO_URL}}|${LOTTI_REPO_URL}|g" \
        -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        com.matthiasnehlsen.lotti.yml > "${TEMP_MANIFEST}"; then
    echo "Error: Failed to generate manifest file"
    exit 1
fi

# Generate metainfo
if ! sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        com.matthiasnehlsen.lotti.metainfo.xml > "${TEMP_METAINFO}"; then
    echo "Error: Failed to generate metainfo file"
    exit 1
fi

# Copy required files to the correct location for the build
echo "Copying required files..."
cp com.matthiasnehlsen.lotti.desktop ../com.matthiasnehlsen.lotti.desktop
cp "${TEMP_METAINFO}" ../com.matthiasnehlsen.lotti.generated.metainfo.xml

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