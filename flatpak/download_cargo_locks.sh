#!/bin/bash
# Download Cargo.lock files from the actual GitHub repositories at the correct versions

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Accept output directory as first argument, or use default
if [ -n "$1" ]; then
  OUTPUT_DIR="$1"
else
  OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/flathub-build/output}"
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${YELLOW}ℹ${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Plugin repositories
# Note: Using specific commits/tags for deterministic builds
declare -A PLUGINS=(
  ["flutter_vodozemac"]="https://raw.githubusercontent.com/famedly/dart-vodozemac/a3446206da432a3a48dedf39bb57604a376b3582/rust/Cargo.lock"
  ["super_native_extensions"]="https://raw.githubusercontent.com/superlistapp/super_native_extensions/super_native_extensions-v0.9.1/super_native_extensions/rust/Cargo.lock"
  ["irondash_engine_context"]="https://raw.githubusercontent.com/irondash/irondash/65343873472d6796c0388362a8e04b6e9a499044/Cargo.lock"
)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

print_info "Output directory: $OUTPUT_DIR"

print_info "Downloading Cargo.lock files from GitHub..."

for plugin in "${!PLUGINS[@]}"; do
  URL="${PLUGINS[$plugin]}"
  OUTPUT_FILE="${plugin}-Cargo.lock"

  print_info "Downloading $plugin Cargo.lock..."

  if curl -sL "$URL" -o "$OUTPUT_FILE.tmp"; then
    # Check if it's actually a Cargo.lock file
    if grep -q "\[package\]" "$OUTPUT_FILE.tmp" 2>/dev/null; then
      mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
      print_status "Downloaded $OUTPUT_FILE"
    else
      rm -f "$OUTPUT_FILE.tmp"
      print_error "Failed to download valid Cargo.lock for $plugin from $URL"
    fi
  else
    print_error "Failed to download $plugin from $URL"
  fi
done

# Now generate cargo-sources.json from the downloaded Cargo.lock files
print_info "Generating cargo-sources.json from downloaded Cargo.lock files..."

lock_files=()
for lock_file in *-Cargo.lock; do
  if [ -f "$lock_file" ]; then
    lock_files+=("$lock_file")
    print_info "Using: $lock_file"
  fi
done

CARGO_LOCKS=$(IFS=,; echo "${lock_files[*]}")

if [ -n "$CARGO_LOCKS" ]; then
  if python3 "$SCRIPT_DIR/flatpak-flutter/cargo_generator/cargo_generator.py" \
    "$CARGO_LOCKS" \
    -o "$OUTPUT_DIR/cargo-sources.json"; then
    print_status "Successfully generated cargo-sources.json"
    print_info "Line count: $(wc -l < $OUTPUT_DIR/cargo-sources.json)"
  else
    print_error "Failed to generate cargo-sources.json"
    exit 1
  fi
else
  print_error "No Cargo.lock files found to process"
  exit 1
fi

print_status "Done!"