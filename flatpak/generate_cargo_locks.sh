#!/bin/bash
# Script to generate Cargo.lock files for cargokit-based Flutter plugins
# This runs during prepare phase WITH network access to resolve dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/flathub-build"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${YELLOW}ℹ${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Plugins that use cargokit and need Cargo.lock generation
CARGOKIT_PLUGINS=(
  "flutter_vodozemac-0.2.2"
  "super_native_extensions-0.9.1"
  "irondash_engine_context-0.5.5"
)

# Create a temporary directory for work
TEMP_DIR="$WORK_DIR/cargo-lock-generation"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

print_info "Generating Cargo.lock files for cargokit-based plugins..."

# Check if pubspec-sources.json exists
PUBSPEC_SOURCES="$WORK_DIR/output/pubspec-sources.json"
if [ ! -f "$PUBSPEC_SOURCES" ]; then
  print_error "pubspec-sources.json not found at $PUBSPEC_SOURCES"
  print_info "Run the prepare script first to generate pubspec-sources.json"
  exit 1
fi

# Generate Cargo.lock for each plugin
for plugin in "${CARGOKIT_PLUGINS[@]}"; do
  print_info "Processing $plugin..."

  # Extract plugin tarball URL from pubspec-sources.json
  TARBALL_URL=$(grep "/$plugin.tar.gz" "$PUBSPEC_SOURCES" | cut -d'"' -f4 | head -1)

  if [ -z "$TARBALL_URL" ]; then
    print_error "Could not find URL for $plugin in pubspec-sources.json"
    continue
  fi

  # Download and extract the plugin
  print_info "Downloading $plugin from pub.dev..."
  curl -sL "$TARBALL_URL" -o "$plugin.tar.gz"
  mkdir -p "$plugin"
  tar -xzf "$plugin.tar.gz" -C "$plugin"

  # Find the cargokit/build directory
  CARGOKIT_DIR="$plugin/cargokit/build"
  if [ ! -d "$CARGOKIT_DIR" ]; then
    print_error "No cargokit/build directory found in $plugin"
    continue
  fi

  cd "$CARGOKIT_DIR"

  # Generate Cargo.lock if it doesn't exist
  if [ ! -f "Cargo.lock" ]; then
    print_info "Generating Cargo.lock for $plugin..."
    cargo generate-lockfile

    if [ -f "Cargo.lock" ]; then
      print_status "Generated Cargo.lock for $plugin"
      # Copy to output directory with descriptive name
      PLUGIN_NAME=$(echo "$plugin" | cut -d'-' -f1)
      cp Cargo.lock "$WORK_DIR/output/${PLUGIN_NAME}-Cargo.lock"
    else
      print_error "Failed to generate Cargo.lock for $plugin"
    fi
  else
    print_info "Cargo.lock already exists for $plugin"
    PLUGIN_NAME=$(echo "$plugin" | cut -d'-' -f1)
    cp Cargo.lock "$WORK_DIR/output/${PLUGIN_NAME}-Cargo.lock"
  fi

  cd "$TEMP_DIR"
done

# Collect all generated Cargo.lock files
print_info "Collecting generated Cargo.lock files..."
CARGO_LOCKS=""
for lock_file in "$WORK_DIR/output/"*-Cargo.lock; do
  if [ -f "$lock_file" ]; then
    if [ -n "$CARGO_LOCKS" ]; then
      CARGO_LOCKS="$CARGO_LOCKS,$lock_file"
    else
      CARGO_LOCKS="$lock_file"
    fi
    print_info "Found: $(basename "$lock_file")"
  fi
done

if [ -n "$CARGO_LOCKS" ]; then
  print_status "Generating cargo-sources.json from Cargo.lock files..."
  if python3 "$SCRIPT_DIR/flatpak-flutter/cargo_generator/cargo_generator.py" \
    "$CARGO_LOCKS" \
    -o "$WORK_DIR/output/cargo-sources.json"; then
    print_status "Successfully generated cargo-sources.json"
  else
    print_error "Failed to generate cargo-sources.json"
    exit 1
  fi
else
  print_error "No Cargo.lock files were generated"
  exit 1
fi

# Clean up
cd "$SCRIPT_DIR"
rm -rf "$TEMP_DIR"

print_status "Done! cargo-sources.json has been generated."