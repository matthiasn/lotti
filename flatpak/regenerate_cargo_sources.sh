#!/usr/bin/env bash

# Script to regenerate cargo-sources.json from actual Cargo.lock files
# This solves the timing issue where cargo-sources.json is generated before
# the actual plugin Cargo.lock files are available

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "[i] $1"; }

# Find the build directory with .pub-cache
BUILD_DIR=""
for candidate in flathub-build/output/.flatpak-builder/build/lotti-* ; do
  if [ -d "$candidate/.pub-cache" ]; then
    BUILD_DIR="$candidate"
    break
  fi
done

if [ -z "$BUILD_DIR" ]; then
  print_error "Could not find build directory with .pub-cache"
  print_info "Run a build first to populate the .pub-cache directory"
  exit 1
fi

print_status "Found build directory: $BUILD_DIR"

# Find all Cargo.lock files in the .pub-cache
CARGO_LOCKS=""
for pattern in \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/rust/Cargo.lock" \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/android/rust/Cargo.lock" \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/ios/rust/Cargo.lock" \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/linux/rust/Cargo.lock" \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/macos/rust/Cargo.lock" \
  "$BUILD_DIR/.pub-cache/hosted/pub.dev/*/windows/rust/Cargo.lock"; do
  for lock_file in $pattern; do
    if [ -f "$lock_file" ]; then
      if [ -n "$CARGO_LOCKS" ]; then
        CARGO_LOCKS="$CARGO_LOCKS,$lock_file"
      else
        CARGO_LOCKS="$lock_file"
      fi
      print_info "Found Cargo.lock: $lock_file"
    fi
  done
done

if [ -z "$CARGO_LOCKS" ]; then
  print_error "No Cargo.lock files found in $BUILD_DIR/.pub-cache"
  exit 1
fi

# Check if cargo_generator.py exists
if [ ! -f "flatpak-flutter/cargo_generator/cargo_generator.py" ]; then
  print_error "cargo_generator.py not found"
  print_info "Make sure flatpak-flutter is cloned in the flatpak directory"
  exit 1
fi

# Generate new cargo-sources.json
OUTPUT_FILE="flathub-build/output/cargo-sources.json"
print_status "Regenerating cargo-sources.json from actual Cargo.lock files..."
python3 flatpak-flutter/cargo_generator/cargo_generator.py \
  "$CARGO_LOCKS" \
  -o "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  print_status "Successfully regenerated $OUTPUT_FILE"
  print_info "You can now rebuild with: cd flathub-build/output && flatpak-builder --force-clean --disable-updates build-dir com.matthiasn.lotti.yml"
else
  print_error "Failed to regenerate cargo-sources.json"
  exit 1
fi