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

# Behavior toggles (can be overridden via env)
: "${CLEAN_AFTER_GEN:=true}"          # Remove .flatpak-builder after generation
: "${PIN_COMMIT:=true}"               # Pin app source to exact commit in output manifest
: "${USE_OFFLINE_FLUTTER:=true}"      # Rewrite manifest to consume generated Flutter JSON

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
if ! git -C "$LOTTI_ROOT" ls-remote origin "refs/heads/$CURRENT_BRANCH" > /dev/null 2>&1; then
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

# Using upstream flatpak-flutter directly; no local patching required

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

# Pin commit in the working manifest before submission/copy
APP_COMMIT=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)
print_status "Pinning working manifest to commit: $APP_COMMIT"
awk -v C="$APP_COMMIT" '
  BEGIN { in_lotti=0; in_src=0; in_git=0 }
  /^\s*- name: lotti\s*$/ { in_lotti=1 }
  in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
  {
    if (in_lotti && /^\s{4}sources:\s*$/) { in_src=1 }
    if (in_src && /^\s{6}- /) { in_git=0 }
    if (in_src && /^\s{6}-\s+type:\s+git\s*$/) { in_git=1 }
    if (in_git && /^\s{8}url:\s+https:\/\/github.com\/matthiasn\/lotti\s*$/) { url_ok=1 }
    if (in_git && url_ok && /^\s{8}branch:/) { sub(/branch:.*/, "commit: " C) }
    if (in_git && url_ok && /^\s{8}commit:\s*COMMIT_PLACEHOLDER/) { sub(/commit:.*/, "commit: " C) }
    print $0
  }
' "$WORK_DIR/com.matthiasn.lotti.yml" > "$WORK_DIR/com.matthiasn.lotti.tmp.yml" && mv "$WORK_DIR/com.matthiasn.lotti.tmp.yml" "$WORK_DIR/com.matthiasn.lotti.yml"

# Fast-fail validation on working manifest to prevent submitting branch refs
print_status "Validating working manifest is commit-pinned..."
if grep -n "COMMIT_PLACEHOLDER" "$WORK_DIR/com.matthiasn.lotti.yml" >/dev/null 2>&1; then
  print_error "Working manifest contains COMMIT_PLACEHOLDER; final manifest must be commit-pinned."
  print_info "File: $WORK_DIR/com.matthiasn.lotti.yml"
  grep -n "COMMIT_PLACEHOLDER" "$WORK_DIR/com.matthiasn.lotti.yml" || true
  exit 1
fi
if grep -nE '^[[:space:]]*branch:' "$WORK_DIR/com.matthiasn.lotti.yml" >/dev/null 2>&1; then
  print_error "Working manifest contains branch: entries; final manifest must be commit-pinned."
  print_info "File: $WORK_DIR/com.matthiasn.lotti.yml"
  grep -nE '^[[:space:]]*branch:' "$WORK_DIR/com.matthiasn.lotti.yml" || true
  exit 1
fi

# Debug: Show what files were generated
print_info "Files generated by flatpak-flutter:"
ls -la -- *.json 2>/dev/null || print_warning "No JSON files found in work directory"
ls -la -- *.yml 2>/dev/null || true
ls -la -- *.yaml 2>/dev/null || true

# Check if the build directories were created
print_info "Checking build directories:"
ls -la .flatpak-builder/build/ 2>/dev/null || print_warning "No build directories found"

# Step 5: Create the final flathub manifest
print_status "Creating flathub manifest..."

# The generated manifest should be com.matthiasn.lotti.yml
# Copy it to output directory
# Fast-fail: do not proceed if COMMIT_PLACEHOLDER remains in generated manifest
if grep -q 'COMMIT_PLACEHOLDER' "com.matthiasn.lotti.yml"; then
  print_error "Generated manifest contains COMMIT_PLACEHOLDER; final manifest must be commit-pinned."
  print_info "Please ensure commit pinning completed before copying."
  exit 1
fi
cp -- "com.matthiasn.lotti.yml" "$OUTPUT_DIR/"

# Copy all generated JSON files (they might be in current dir or parent)
cp -- flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No flutter-sdk JSON found"
cp -- pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No pubspec-sources.json found"
cp -- cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No cargo-sources.json found"
cp -- rustup-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No rustup JSON found"
cp -- package_config.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No package_config.json found"

# Check if files were generated in parent directory
if [ -f "../pubspec-sources.json" ]; then
    print_info "Found generated files in parent directory, copying..."
    cp -- ../flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../rustup-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../package_config.json "$OUTPUT_DIR/" 2>/dev/null
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
cp -- "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$OUTPUT_DIR/" 2>/dev/null || print_warning "No desktop file found"
cp -- "$FLATPAK_DIR/com.matthiasn.lotti.desktop" "$WORK_DIR/" 2>/dev/null || true

# Copy icon files
for icon in "$FLATPAK_DIR"/app_icon_*.png; do
    if [ -f "$icon" ]; then
        cp -- "$icon" "$OUTPUT_DIR/"
        cp -- "$icon" "$WORK_DIR/"
    fi
done

# Copy patch directories if needed
if [ -d "$FLATPAK_DIR/patches" ]; then
    cp -r "$FLATPAK_DIR/patches" "$OUTPUT_DIR/"
fi

# Copy any helper source directories generated by flatpak-flutter that are referenced by path
for helper_dir in sqlite3_flutter_libs cargokit; do
  if [ -d "$WORK_DIR/$helper_dir" ]; then
    print_info "Copying helper dir: $helper_dir"
    cp -r "$WORK_DIR/$helper_dir" "$OUTPUT_DIR/" || true
  fi
done

# Step 7: Post-process output manifest (pin commit, use offline Flutter JSON)
print_status "Post-processing output manifest..."

OUT_MANIFEST="$OUTPUT_DIR/com.matthiasn.lotti.yml"
if [ -f "$OUT_MANIFEST" ]; then
  # Pin app source to commit
  if [ "$PIN_COMMIT" = "true" ]; then
    APP_COMMIT=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)
    print_info "Pinning app source to commit: $APP_COMMIT"
    awk -v C="$APP_COMMIT" '
      BEGIN { in_lotti=0; in_src=0; in_git=0 }
      /^\s*- name: lotti\s*$/ { in_lotti=1 }
      in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
      {
        if (in_lotti && /^\s{4}sources:\s*$/) { in_src=1 }
        if (in_src && /^\s{6}- /) { in_git=0 }
        if (in_src && /^\s{6}-\s+type:\s+git\s*$/) { in_git=1 }
        if (in_git && /^\s{8}url:\s+https:\/\/github.com\/matthiasn\/lotti\s*$/) { url_ok=1 }
        if (in_git && url_ok && /^\s{8}branch:/) { sub(/branch:.*/, "commit: " C) }
        if (in_git && url_ok && /^\s{8}commit:\s*COMMIT_PLACEHOLDER/) { sub(/commit:.*/, "commit: " C) }
        print $0
      }
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"
  fi

  # Use offline Flutter SDK JSON instead of separate module
  if [ "$USE_OFFLINE_FLUTTER" = "true" ]; then
    # Remove flutter-sdk module block entirely
    awk '
      BEGIN{skip=0}
      /^\s*- name: flutter-sdk\s*$/ {skip=1}
      skip && /^\s*- name: / {skip=0}
      !skip {print}
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"

    # Insert offline JSON includes into lotti module sources
    # Determine available JSONs relative to output dir
    FLUTTER_JSON=$(ls "$OUTPUT_DIR"/flutter-sdk-*.json 2>/dev/null | xargs -n1 basename | head -n1)
    PUBSPEC_JSON=$( [ -f "$OUTPUT_DIR/pubspec-sources.json" ] && echo pubspec-sources.json )
    CARGO_JSON=$( [ -f "$OUTPUT_DIR/cargo-sources.json" ] && echo cargo-sources.json )
    RUSTUP_JSON=$(ls "$OUTPUT_DIR"/rustup-*.json 2>/dev/null | xargs -n1 basename | head -n1)

    print_info "Adding offline sources: ${FLUTTER_JSON:-none} ${PUBSPEC_JSON:-} ${CARGO_JSON:-} ${RUSTUP_JSON:-}"

    awk -v FJ="$FLUTTER_JSON" -v PJ="$PUBSPEC_JSON" -v CJ="$CARGO_JSON" -v RJ="$RUSTUP_JSON" '
      BEGIN { in_lotti=0; inserted=0 }
      /^\s*- name: lotti\s*$/ { in_lotti=1 }
      in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
      {
        print $0
        if (in_lotti && /^\s{4}sources:\s*$/ && !inserted) {
          if (FJ != "") { print "      - type: file\n        path: " FJ }
          if (PJ != "") { print "      - type: file\n        path: " PJ }
          if (CJ != "") { print "      - type: file\n        path: " CJ }
          if (RJ != "") { print "      - type: file\n        path: " RJ }
          inserted=1
        }
      }
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"

    # Adjust build-commands to use extracted SDK in module dir rather than /app/flutter
    sed -i 's|cp -r /app/flutter /run/build/lotti/flutter_sdk|cp -r flutter /run/build/lotti/flutter_sdk|' "$OUT_MANIFEST"
    
    # Remove problematic CMake patch entries for sqlite3_flutter_libs if present
    # This drops any single source item with type: patch whose path contains CMakeLists.txt.patch
    awk '
      BEGIN { in_patch=0; has_cmake=0; }
      {
        if (!in_patch) {
          if ($0 ~ /^\s{6}-\s*type:\s*patch\s*$/) {
            in_patch=1; has_cmake=0; buf_cnt=0; buf[++buf_cnt]=$0; next;
          } else {
            print $0; next;
          }
        } else {
          # inside a patch source entry
          if ($0 ~ /CMakeLists\.txt\.patch/) { has_cmake=1 }
          buf[++buf_cnt]=$0
          if ($0 ~ /^\s{6}-\s/ ) {
            # next source entry begins; flush previous
            if (!has_cmake) { for (i=1;i<=buf_cnt-1;i++) print buf[i]; }
            # start buffering the new line only if it is another patch entry
            if ($0 ~ /^\s{6}-\s*type:\s*patch\s*$/) { in_patch=1; has_cmake=0; buf_cnt=0; buf[++buf_cnt]=$0; }
            else { in_patch=0; print $0; }
          }
        }
      }
      END {
        if (in_patch) {
          if (!has_cmake) { for (i=1;i<=buf_cnt;i++) print buf[i]; }
        }
      }
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"
  fi
else
  print_warning "Output manifest not found at $OUT_MANIFEST; skipping post-processing"
fi

# Final validation: ensure the manifest to be submitted is commit-pinned (no branch:, no COMMIT_PLACEHOLDER)
print_status "Validating output manifest is commit-pinned..."
if grep -n "COMMIT_PLACEHOLDER" "$OUT_MANIFEST" >/dev/null 2>&1; then
  print_error "Output manifest contains COMMIT_PLACEHOLDER; final manifest must be commit-pinned."
  print_info "File: $OUT_MANIFEST"
  grep -n "COMMIT_PLACEHOLDER" "$OUT_MANIFEST" || true
  exit 1
fi
if grep -nE '^[[:space:]]*branch:' "$OUT_MANIFEST" >/dev/null 2>&1; then
  print_error "Output manifest contains branch: entries; final manifest must be commit-pinned."
  print_info "File: $OUT_MANIFEST"
  grep -nE '^[[:space:]]*branch:' "$OUT_MANIFEST" || true
  exit 1
fi

# Optionally clean the work .flatpak-builder dir to avoid local build conflicts
if [ "$CLEAN_AFTER_GEN" = "true" ]; then
  print_status "Cleaning work build directory (.flatpak-builder)..."
  rm -rf "$WORK_DIR/.flatpak-builder" || true
fi

# Step 8: Test build (optional)
if [ "${TEST_BUILD:-false}" == "true" ]; then
    print_status "Testing build..."
    cd "$OUTPUT_DIR"
    if flatpak-builder --force-clean --repo=repo build-dir com.matthiasn.lotti.yml; then
        print_status "Test build successful!"
    else
        print_error "Test build failed"
    fi
fi

# Step 9: Final report
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
