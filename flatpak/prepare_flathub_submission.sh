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

# Get the current branch
CURRENT_BRANCH=$(cd "$LOTTI_ROOT" && git rev-parse --abbrev-ref HEAD)

# Verify branch exists on remote (required for flatpak-flutter)
if ! git ls-remote origin "refs/heads/$CURRENT_BRANCH" > /dev/null 2>&1; then
    print_error "Branch $CURRENT_BRANCH not found on remote"
    print_info "Please push your branch first: git push origin $CURRENT_BRANCH"
    exit 1
fi

print_info "Using branch: $CURRENT_BRANCH"

echo "=========================================="
echo "   Flathub Submission Preparation Script"
echo "=========================================="
echo "Version: ${LOTTI_VERSION}"
echo "Release Date: ${LOTTI_RELEASE_DATE}"
echo "Branch: ${CURRENT_BRANCH}"
echo ""

# Step 1: Clean and create work directory
print_status "Creating clean work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

# Step 2: Copy source manifest to work directory
print_status "Preparing source manifest..."
cp "$FLATPAK_DIR/com.matthiasn.lotti.source.yml" "$WORK_DIR/com.matthiasn.lotti.yml"

# Replace commit with branch for better flatpak-flutter compatibility
sed -i "s|commit: COMMIT_PLACEHOLDER|branch: $CURRENT_BRANCH|" "$WORK_DIR/com.matthiasn.lotti.yml"

# Also ensure flatpak-flutter sees Flutter SDK in the app module's sources.
# flatpak-flutter only generates dependency files when it finds the Flutter
# SDK git source (with a tag) inside the app module ("lotti"). Our source
# manifest keeps Flutter SDK as a separate module, so we inject a temporary
# Flutter SDK git source into the lotti module's sources here.
print_status "Injecting Flutter SDK source into app module for flatpak-flutter..."

# Extract Flutter tag from the flutter-sdk module in the source manifest as the source of truth
FLUTTER_TAG=$(awk '
  /^[[:space:]]*-[[:space:]]+name:[[:space:]]+flutter-sdk[[:space:]]*$/ {in_sdk=1}
  in_sdk && /^[[:space:]]*sources:/ {in_sources=1}
  in_sdk && in_sources && /^[[:space:]]*tag:[[:space:]]/ {print $2; exit}
  in_sdk && /^[[:space:]]*-[[:space:]]+name:/ {in_sdk=0}
' "$WORK_DIR/com.matthiasn.lotti.yml" | tr -d '"' | tr -d "'")

if [ -z "${FLUTTER_TAG}" ]; then
  FLUTTER_TAG="3.35.4"
  print_warning "Could not detect Flutter tag from manifest; defaulting to ${FLUTTER_TAG}"
else
  print_info "Detected Flutter tag: ${FLUTTER_TAG}"
fi

# Insert a Flutter SDK git source into the lotti module's sources list
awk -v TAG="$FLUTTER_TAG" '
  BEGIN { in_lotti=0; inserted=0 }
  /^  - name: lotti$/ { in_lotti=1 }
  # End of lotti module when another module starts
  in_lotti && /^  - name:/ && $0 !~ /name: lotti$/ { in_lotti=0 }
  {
    if (in_lotti && /^ {4}sources:/ && !inserted) {
      print $0
      print "      - type: git"
      print "        url: https://github.com/flutter/flutter.git"
      print "        tag: " TAG
      print "        dest: flutter"
      inserted=1
      next
    }
    print $0
  }
' "$WORK_DIR/com.matthiasn.lotti.yml" > "$WORK_DIR/com.matthiasn.lotti.tmp.yml"
mv "$WORK_DIR/com.matthiasn.lotti.tmp.yml" "$WORK_DIR/com.matthiasn.lotti.yml"
print_info "Temporary manifest prepared for flatpak-flutter processing."

# Step 3: Check for flatpak-flutter
if [ ! -d "$FLATPAK_DIR/flatpak-flutter" ]; then
    print_status "Cloning flatpak-flutter..."
    cd "$FLATPAK_DIR"
    git clone https://github.com/TheAppgineer/flatpak-flutter.git
fi

# Always apply the local patch to flatpak-flutter (safe no-op if already applied)
if [ -x "$FLATPAK_DIR/flatpak-flutter-patch.sh" ]; then
    print_status "Applying local flatpak-flutter patch..."
    bash "$FLATPAK_DIR/flatpak-flutter-patch.sh" "$FLATPAK_DIR/flatpak-flutter" || print_warning "flatpak-flutter patch may already be applied"
fi

# Step 4: Run flatpak-flutter in work directory
print_status "Running flatpak-flutter to generate offline sources..."
cd "$WORK_DIR"

# Copy necessary files to work directory
cp -r "$LOTTI_ROOT/lib" .
cp -r "$LOTTI_ROOT/linux" .
cp "$LOTTI_ROOT/pubspec.yaml" .
cp "$LOTTI_ROOT/pubspec.lock" .

# Create build directory that flatpak-flutter expects
mkdir -p .flatpak-builder/build

# Ensure pubspec files are available where flatpak-flutter expects them
for build_dir in \
    .flatpak-builder/build/lotti \
    .flatpak-builder/build/lotti-1; do
  mkdir -p "$build_dir"
  cp -f pubspec.yaml "$build_dir/" 2>/dev/null || true
  cp -f pubspec.lock "$build_dir/" 2>/dev/null || true
  # Provide an empty foreign_deps.json if flatpak-flutter expects it
  if [ ! -f "$build_dir/foreign_deps.json" ]; then
    echo '{}' > "$build_dir/foreign_deps.json"
  fi
done

# Prime a usable Flutter SDK at the path flatpak-flutter expects for pub get
if [ ! -x ".flatpak-builder/build/lotti/flutter/bin/flutter" ]; then
  print_status "Priming Flutter SDK at .flatpak-builder/build/lotti/flutter (tag $FLUTTER_TAG)..."
  mkdir -p .flatpak-builder/build/lotti
  git clone --depth 1 --branch "$FLUTTER_TAG" https://github.com/flutter/flutter.git .flatpak-builder/build/lotti/flutter || true
  if [ -x ".flatpak-builder/build/lotti/flutter/bin/flutter" ]; then
    (cd .flatpak-builder/build/lotti/flutter && ./bin/flutter --version || true)
  else
    print_warning "Failed to clone Flutter SDK to expected path; flatpak-flutter will attempt its own clone."
  fi
fi

# Run flatpak-flutter with verbose output
print_info "Running flatpak-flutter with the following manifest:"
grep -A 5 "name: flutter-sdk" com.matthiasn.lotti.yml || print_warning "No flutter-sdk module found"
grep -A 5 "name: lotti" com.matthiasn.lotti.yml || print_warning "No lotti module found"

if ! python3 "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" \
    --app-module lotti \
    --keep-build-dirs \
    "com.matthiasn.lotti.yml" 2>&1 | tee flatpak-flutter.log; then
    print_error "flatpak-flutter failed to generate files"
    print_info "Check flatpak-flutter.log for details"
    exit 1
fi

print_status "Generated offline manifest and dependencies"

# Debug: Show what files were generated
print_info "Files generated by flatpak-flutter:"
ls -la *.json 2>/dev/null || print_warning "No JSON files found in work directory"
ls -la *.yml 2>/dev/null || true
ls -la *.yaml 2>/dev/null || true

# Check if the build directories were created
print_info "Checking build directories:"
ls -la .flatpak-builder/build/ 2>/dev/null || print_warning "No build directories found"

# Step 5: Create the final flathub manifest
print_status "Creating flathub manifest..."

# The generated manifest should be com.matthiasn.lotti.yml
# Copy it to output directory
cp "com.matthiasn.lotti.yml" "$OUTPUT_DIR/"

# Copy all generated JSON files (they might be in current dir or parent)
cp flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No flutter-sdk JSON found"
cp pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No pubspec-sources.json found"
cp cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No cargo-sources.json found"
cp rustup-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No rustup JSON found"
cp package_config.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No package_config.json found"

# Check if files were generated in parent directory
if [ -f "../pubspec-sources.json" ]; then
    print_info "Found generated files in parent directory, copying..."
    cp ../flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp ../pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp ../cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp ../rustup-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp ../package_config.json "$OUTPUT_DIR/" 2>/dev/null
fi

# Step 6: Copy additional required files
print_status "Copying additional files..."

# Copy metadata files
if [ -f "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" ]; then
    print_info "Processing metainfo.xml with version substitution..."
    sed -e "s|{{LOTTI_VERSION}}|${LOTTI_VERSION}|g" \
        -e "s|{{LOTTI_RELEASE_DATE}}|${LOTTI_RELEASE_DATE}|g" \
        "$FLATPAK_DIR/com.matthiasn.lotti.metainfo.xml" > "$OUTPUT_DIR/com.matthiasn.lotti.metainfo.xml"
    # Also place processed metainfo in work dir so local builds from WORK_DIR succeed
    cp "$OUTPUT_DIR/com.matthiasn.lotti.metainfo.xml" "$WORK_DIR/com.matthiasn.lotti.metainfo.xml"
fi

# Desktop file to both output and work dir
cp "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$OUTPUT_DIR/" 2>/dev/null || print_warning "No desktop file found"
cp "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$WORK_DIR/" 2>/dev/null || true

# Copy icon files
for icon in "$FLATPAK_DIR"/app_icon_*.png; do
    if [ -f "$icon" ]; then
        cp "$icon" "$OUTPUT_DIR/"
        cp "$icon" "$WORK_DIR/"
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
