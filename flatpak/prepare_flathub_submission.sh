#!/bin/bash

# Script to prepare Lotti for Flathub submission
# Assumes flathub fork is in ../flathub relative to lotti directory

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
FLATHUB_ROOT="$(cd "$LOTTI_ROOT/.." && pwd)/flathub"
FLATPAK_DIR="$LOTTI_ROOT/flatpak"

# Version configuration - can be overridden by environment variables
# Get latest git tag if not specified
if [ -z "${LOTTI_VERSION:-}" ]; then
    LOTTI_VERSION=$(cd "$LOTTI_ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo "v0.9.645")
fi

# Use today's date if not specified
if [ -z "${LOTTI_RELEASE_DATE:-}" ]; then
    LOTTI_RELEASE_DATE=$(date +%Y-%m-%d)
fi

echo "=========================================="
echo "   Flathub Submission Preparation Script"
echo "=========================================="
echo "Version: ${LOTTI_VERSION}"
echo "Release Date: ${LOTTI_RELEASE_DATE}"
echo ""
print_info "Lotti root: $LOTTI_ROOT"
print_info "Flathub repo: $FLATHUB_ROOT"
print_info "Flatpak dir: $FLATPAK_DIR"
echo ""

# Check if flathub directory exists
if [ ! -d "$FLATHUB_ROOT" ]; then
    print_error "Flathub repository not found at $FLATHUB_ROOT"
    print_info "Please clone your flathub fork to ../flathub"
    print_info "Run: git clone https://github.com/YOUR_USERNAME/flathub ../flathub"
    exit 1
fi

# Step 0: Install required SDK extensions
print_status "Checking and installing required SDK extensions..."

# Check if LLVM extension is installed
if ! flatpak list | grep -q "org.freedesktop.Sdk.Extension.llvm20.*24.08"; then
    print_info "Installing LLVM 20 SDK extension (provides clang++ for Flutter builds)..."
    if ! flatpak install -y flathub org.freedesktop.Sdk.Extension.llvm20//24.08; then
        print_error "Failed to install LLVM extension"
        print_info "Try manually: flatpak install flathub org.freedesktop.Sdk.Extension.llvm20//24.08"
        exit 1
    fi
else
    print_info "LLVM 20 SDK extension already installed"
fi

# Check if Rust extension is installed
if ! flatpak list | grep -q "org.freedesktop.Sdk.Extension.rust-stable.*24.08"; then
    print_info "Installing Rust SDK extension (for building native extensions)..."
    if ! flatpak install -y flathub org.freedesktop.Sdk.Extension.rust-stable//24.08; then
        print_error "Failed to install Rust extension"
        print_info "Try manually: flatpak install flathub org.freedesktop.Sdk.Extension.rust-stable//24.08"
        exit 1
    fi
else
    print_info "Rust SDK extension already installed"
fi

# Check if Freedesktop SDK is installed
if ! flatpak list | grep -q "org.freedesktop.Sdk.*24.08"; then
    print_info "Installing Freedesktop SDK 24.08..."
    if ! flatpak install -y flathub org.freedesktop.Sdk//24.08; then
        print_error "Failed to install Freedesktop SDK"
        exit 1
    fi
else
    print_info "Freedesktop SDK 24.08 already installed"
fi

# Check if Freedesktop Platform is installed
if ! flatpak list | grep -q "org.freedesktop.Platform.*24.08"; then
    print_info "Installing Freedesktop Platform 24.08..."
    if ! flatpak install -y flathub org.freedesktop.Platform//24.08; then
        print_error "Failed to install Freedesktop Platform"
        exit 1
    fi
else
    print_info "Freedesktop Platform 24.08 already installed"
fi

# Step 1: Clean up any previous generated files in the root directory
print_status "Cleaning up previous generated files in root directory..."
cd "$LOTTI_ROOT"
rm -f com.matthiasn.lotti.yml
rm -f flutter-sdk-*.json
rm -f pubspec-sources.json
rm -f cargo-sources.json
rm -f rustup-*.json
rm -f package_config.json

# Step 2: Run flatpak-flutter to generate all required files
print_status "Running flatpak-flutter to generate offline build files..."
cd "$LOTTI_ROOT"

# Check if flatpak-flutter exists
if [ ! -f "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" ]; then
    print_error "flatpak-flutter not found. Please run:"
    print_info "cd $FLATPAK_DIR && git clone https://github.com/TheAppgineer/flatpak-flutter.git"
    exit 1
fi

# Check if source manifest exists
if [ ! -f "$FLATPAK_DIR/com.matthiasn.lotti.source.yml" ]; then
    print_error "Source manifest not found at $FLATPAK_DIR/com.matthiasn.lotti.source.yml"
    exit 1
fi

# Clean .flatpak-builder directory for fresh run
rm -rf .flatpak-builder

# Run flatpak-flutter
print_status "Generating offline manifest and dependencies..."
if ! python3 "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" \
    --app-module lotti \
    "$FLATPAK_DIR/com.matthiasn.lotti.source.yml"; then
    print_error "flatpak-flutter failed to generate files"
    exit 1
fi

print_status "Files generated successfully"

# Step 3: Create app directory in flathub repo
APP_DIR="$FLATHUB_ROOT/com.matthiasn.lotti"
if [ -d "$APP_DIR" ]; then
    print_warning "App directory already exists at $APP_DIR"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborting..."
        exit 1
    fi
    rm -rf "$APP_DIR"
fi

print_status "Creating app directory at $APP_DIR"
mkdir -p "$APP_DIR"

# Step 4: Copy all required files to flathub repo
print_status "Copying generated files to flathub repository..."

# Copy the main manifest (rename from generated name)
cp "$LOTTI_ROOT/com.matthiasn.lotti.yml" "$APP_DIR/com.matthiasn.lotti.yml"

# Copy all generated JSON files
cp "$LOTTI_ROOT/flutter-sdk-"*.json "$APP_DIR/" 2>/dev/null || print_warning "No flutter-sdk JSON found"
cp "$LOTTI_ROOT/pubspec-sources.json" "$APP_DIR/" 2>/dev/null || print_warning "No pubspec-sources.json found"
cp "$LOTTI_ROOT/cargo-sources.json" "$APP_DIR/" 2>/dev/null || print_warning "No cargo-sources.json found"
cp "$LOTTI_ROOT/rustup-"*.json "$APP_DIR/" 2>/dev/null || print_warning "No rustup JSON found"
cp "$LOTTI_ROOT/package_config.json" "$APP_DIR/" 2>/dev/null || print_warning "No package_config.json found"

# Copy patch directories and files
if [ -d "$FLATPAK_DIR/sqlite3_flutter_libs" ]; then
    cp -r "$FLATPAK_DIR/sqlite3_flutter_libs" "$APP_DIR/"
fi

if [ -d "$FLATPAK_DIR/cargokit" ]; then
    cp -r "$FLATPAK_DIR/cargokit" "$APP_DIR/"
fi

if [ -d "$FLATPAK_DIR/super_native_extensions" ]; then
    cp -r "$FLATPAK_DIR/super_native_extensions" "$APP_DIR/"
fi

# Copy individual patch files
if [ -f "$FLATPAK_DIR/flutter-shared.sh.patch" ]; then
    cp "$FLATPAK_DIR/flutter-shared.sh.patch" "$APP_DIR/"
fi

# Copy metadata files with template substitution
print_status "Processing metadata files..."

# Generate metainfo file with version substitution
if [ -f "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" ]; then
    print_info "Substituting version ${LOTTI_VERSION} and date ${LOTTI_RELEASE_DATE} in metainfo.xml..."
    sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" > "$APP_DIR/com.matthiasn.lotti.metainfo.xml"
    print_status "Generated metainfo file with version information"
else
    print_warning "No metainfo.xml template found"
fi

cp "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$APP_DIR/" 2>/dev/null || print_warning "No desktop file found"

# Copy icon files
print_status "Copying icon files..."
for icon in "$FLATPAK_DIR"/app_icon_*.png; do
    if [ -f "$icon" ]; then
        cp "$icon" "$APP_DIR/"
    fi
done

# Step 5: Clean up generated files from root directory
print_status "Cleaning up generated files from root directory..."
cd "$LOTTI_ROOT"
rm -f com.matthiasn.lotti.yml
rm -f flutter-sdk-*.json
rm -f pubspec-sources.json
rm -f cargo-sources.json
rm -f rustup-*.json
rm -f package_config.json

# Step 6: Show git status in flathub repo
print_status "Preparation complete!"
echo ""
print_info "Files have been copied to: $APP_DIR"
echo ""
print_info "Version information used:"
echo "  LOTTI_VERSION=${LOTTI_VERSION}"
echo "  LOTTI_RELEASE_DATE=${LOTTI_RELEASE_DATE}"
echo ""
print_info "To use different version/date, run with:"
echo "  LOTTI_VERSION=v1.0.0 LOTTI_RELEASE_DATE=2025-02-01 $0"
echo ""
print_info "Next steps:"
echo "  1. cd $FLATHUB_ROOT"
echo "  2. git checkout -b new-app-com.matthiasn.lotti"
echo "  3. git add com.matthiasn.lotti"
echo "  4. git commit -m \"Add com.matthiasn.lotti\""
echo "  5. git push origin new-app-com.matthiasn.lotti"
echo "  6. Create PR at https://github.com/flathub/flathub"
echo ""
print_info "Files in app directory:"
ls -la "$APP_DIR"