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

# Locate an existing Flutter SDK checkout that can be reused for offline builds
find_cached_flutter_dir() {
    while IFS= read -r flutter_bin; do
        local candidate_dir
        candidate_dir="$(dirname "$(dirname "$flutter_bin")")"

        # Skip directories that live inside the working directory to avoid recursion
        case "$candidate_dir" in
            "$WORK_DIR"/*) continue ;;
            "$WORK_DIR") continue ;;
        esac

        echo "$candidate_dir"
        return 0
    done < <(find "$LOTTI_ROOT" -maxdepth 6 -type f -path "*flutter/bin/flutter" 2>/dev/null | sort)

    return 1
}

# Find a previously downloaded source artifact by filename
find_cached_source_file() {
    local filename="$1"

    local search_roots=(
        "$FLATPAK_DIR/.flatpak-builder"
        "$LOTTI_ROOT/.flatpak-builder"
        "$(dirname "$LOTTI_ROOT")/.flatpak-builder"
    )

    local root
    for root in "${search_roots[@]}"; do
        if [ -d "$root" ]; then
            local match
            match=$(find "$root" -type f -name "$filename" -print -quit 2>/dev/null || true)
            if [ -n "$match" ]; then
                echo "$match"
                return 0
            fi
        fi
    done

    return 1
}

# Replace a source url entry with a local path in the manifest
replace_source_url_with_path() {
    local manifest="$1"
    local identifier="$2"
    local path_value="$3"

    if [ ! -f "$manifest" ]; then
        return 0
    fi

    if ! grep -q "$identifier" "$manifest"; then
        return 0
    fi

    python3 - "$manifest" "$identifier" "$path_value" <<'PY'
import sys

manifest, identifier, replacement = sys.argv[1:]

try:
    with open(manifest, encoding='utf-8') as handle:
        lines = handle.readlines()
except FileNotFoundError:
    sys.exit(0)

changed = False
for idx, line in enumerate(lines):
    if 'url:' in line and identifier in line:
        prefix = line.split('url:')[0]
        lines[idx] = f"{prefix}path: {replacement}\n"
        changed = True

if changed:
    with open(manifest, 'w', encoding='utf-8') as handle:
        handle.writelines(lines)
PY
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
: "${USE_OFFLINE_PYTHON:=true}"       # Prefer cached Python artifacts for offline builds
: "${USE_OFFLINE_ARCHIVES:=true}"     # Prefer cached archive/file sources in manifest
: "${USE_OFFLINE_APP_SOURCE:=true}"   # Bundle app source as archive for offline testing

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
set +e
REMOTE_CHECK_OUTPUT=$(git -C "$LOTTI_ROOT" ls-remote origin "refs/heads/$CURRENT_BRANCH" 2>&1)
REMOTE_CHECK_STATUS=$?
set -e

if [ "$REMOTE_CHECK_STATUS" -eq 0 ]; then
    if [ -z "$REMOTE_CHECK_OUTPUT" ]; then
        print_error "Branch $CURRENT_BRANCH not found on remote"
        print_info "Please push your branch first: git push origin $CURRENT_BRANCH"
        exit 1
    fi
else
    print_warning "Unable to verify remote branch $CURRENT_BRANCH (git ls-remote exited with $REMOTE_CHECK_STATUS)."
    print_info "Proceeding with local branch; ensure origin/$CURRENT_BRANCH exists before publishing."
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
mkdir -p "$WORK_DIR"
find "$WORK_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
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

CACHED_FLUTTER_DIR="$(find_cached_flutter_dir || true)"
FLUTTER_GIT_URL="https://github.com/flutter/flutter.git"
if [ -n "$CACHED_FLUTTER_DIR" ]; then
  print_info "Found cached Flutter SDK checkout at $CACHED_FLUTTER_DIR"
  # Use local checkout to avoid network requirement during preparation
  FLUTTER_GIT_URL="file://$CACHED_FLUTTER_DIR"
fi

# Insert a Flutter SDK git source into the lotti module's sources list
awk -v TAG="$FLUTTER_TAG" -v FLUTTER_URL="$FLUTTER_GIT_URL" '
  BEGIN { in_lotti=0; inserted=0 }
  /^  - name: lotti$/ { in_lotti=1 }
  # End of lotti module when another module starts
  in_lotti && /^  - name:/ && $0 !~ /name: lotti$/ { in_lotti=0 }
  {
    if (in_lotti && /^ {4}sources:/ && !inserted) {
      print $0
      print "      - type: git"
      print "        url: " FLUTTER_URL
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
TARGET_FLUTTER_DIR=".flatpak-builder/build/lotti/flutter"
if [ ! -x "$TARGET_FLUTTER_DIR/bin/flutter" ]; then
  print_status "Priming Flutter SDK at $TARGET_FLUTTER_DIR (tag $FLUTTER_TAG)..."

  # Try to reuse an existing local Flutter checkout to avoid network access
  LOCAL_FLUTTER_DIR="$CACHED_FLUTTER_DIR"
  if [ -z "$LOCAL_FLUTTER_DIR" ]; then
    while IFS= read -r flutter_bin; do
      candidate_dir="$(dirname "$(dirname "$flutter_bin")")"
      # Skip if the candidate already matches the target directory
      if [ "$candidate_dir" = "$(cd "$TARGET_FLUTTER_DIR/.." 2>/dev/null && pwd)/flutter" ]; then
        continue
      fi
      LOCAL_FLUTTER_DIR="$candidate_dir"
      break
    done < <(find "$LOTTI_ROOT" -maxdepth 6 -type f -path "*flutter/bin/flutter" 2>/dev/null | sort)
  fi

  mkdir -p "$TARGET_FLUTTER_DIR"

  if [ -n "$LOCAL_FLUTTER_DIR" ]; then
    print_info "Using cached Flutter SDK from $LOCAL_FLUTTER_DIR"
    find "$TARGET_FLUTTER_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    cp -a "$LOCAL_FLUTTER_DIR/." "$TARGET_FLUTTER_DIR" || print_warning "Failed to copy cached Flutter SDK; will fall back to cloning."
  fi

  if [ ! -x "$TARGET_FLUTTER_DIR/bin/flutter" ]; then
    print_warning "Cached Flutter SDK not available; attempting shallow clone from remote."
    git clone --depth 1 --branch "$FLUTTER_TAG" "$FLUTTER_GIT_URL" "$TARGET_FLUTTER_DIR" || true
  fi

  if [ -x "$TARGET_FLUTTER_DIR/bin/flutter" ]; then
    (cd "$TARGET_FLUTTER_DIR" && ./bin/flutter --version || true)
  else
    print_warning "Failed to provision Flutter SDK; flatpak-flutter will attempt its own clone."
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
    FLUTTER_JSON=""
    for candidate in "$OUTPUT_DIR"/flutter-sdk-*.json; do
      if [ -e "$candidate" ]; then
        FLUTTER_JSON="$(basename "$candidate")"
        break
      fi
    done

    PUBSPEC_JSON=""
    if [ -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
      PUBSPEC_JSON="pubspec-sources.json"
    fi

    CARGO_JSON=""
    if [ -f "$OUTPUT_DIR/cargo-sources.json" ]; then
      CARGO_JSON="cargo-sources.json"
    fi

    RUSTUP_JSON=""
    for candidate in "$OUTPUT_DIR"/rustup-*.json; do
      if [ -e "$candidate" ]; then
        RUSTUP_JSON="$(basename "$candidate")"
        break
      fi
    done

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

    # Ensure the injected Flutter SDK git source points back to the upstream URL
    awk '
      BEGIN { in_lotti=0; in_sources=0; in_git=0; saw_dest=0 }
      /^\s*- name: lotti\s*$/ { in_lotti=1 }
      in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
      {
        if (in_lotti && /^\s{4}sources:\s*$/) { in_sources=1 }
        if (in_sources && /^\s{6}- /) { in_git=0; saw_dest=0 }
        if (in_sources && /^\s{6}-\s+type:\s+git\s*$/) { in_git=1 }
        if (in_git && /^\s{8}dest:\s+flutter\s*$/) { saw_dest=1 }
        if (in_git && saw_dest && /^\s{8}url:/) {
          sub(/url:.*/, "        url: https://github.com/flutter/flutter.git")
          saw_dest=0
        }
        print $0
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

    # Fallback: if offline JSON artifacts were not generated, convert flutter-sdk module
    # to consume the cached Flutter archive directly.
    if [ -z "$FLUTTER_JSON" ]; then
      FLUTTER_ARCHIVE_SOURCE=""
      for root in \
        "$FLATPAK_DIR/.flatpak-builder" \
        "$LOTTI_ROOT/.flatpak-builder" \
        "$(dirname "$LOTTI_ROOT")/.flatpak-builder"; do
        [ -d "$root" ] || continue
        candidate=$(find "$root" -type f -name "flutter_*${FLUTTER_TAG}*.tar.*" -print -quit 2>/dev/null || true)
        if [ -n "$candidate" ]; then
          FLUTTER_ARCHIVE_SOURCE="$candidate"
          break
        fi
      done

      if [ -n "$FLUTTER_ARCHIVE_SOURCE" ]; then
        FLUTTER_ARCHIVE_BASENAME="$(basename "$FLUTTER_ARCHIVE_SOURCE")"
        if [ ! -f "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME" ]; then
          cp -- "$FLUTTER_ARCHIVE_SOURCE" "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME"
        fi
        FLUTTER_ARCHIVE_SHA256=$(sha256sum "$FLUTTER_ARCHIVE_SOURCE" | awk '{print $1}')

        python3 - "$OUT_MANIFEST" "$FLUTTER_ARCHIVE_BASENAME" "$FLUTTER_ARCHIVE_SHA256" <<'PY'
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
archive_name = sys.argv[2]
archive_sha = sys.argv[3]

lines = manifest_path.read_text(encoding='utf-8').splitlines()
result = []
in_flutter = False
in_sources = False
skipping_git_block = False
replaced = False

idx = 0
length = len(lines)
while idx < length:
    line = lines[idx]
    stripped = line.strip()

    if stripped.startswith('- name: '):
        in_flutter = stripped == '- name: flutter-sdk'
        in_sources = False
        skipping_git_block = False
    elif in_flutter and line.startswith('    sources:'):
        in_sources = True
    elif in_sources and line.startswith('  '):
        # Leaving sources due to reduced indentation
        in_sources = line.startswith('      ')

    if (
        in_flutter
        and in_sources
        and not replaced
        and line.startswith('      - type: git')
    ):
        # Replace the git source block with archive source information
        result.append('      - type: archive')
        result.append(f'        path: {archive_name}')
        result.append(f'        sha256: {archive_sha}')
        replaced = True
        idx += 1
        # Skip existing lines belonging to the git block
        while idx < length and lines[idx].startswith('        '):
            idx += 1
        continue

    result.append(line)
    idx += 1

manifest_path.write_text('\n'.join(result) + '\n', encoding='utf-8')
PY
        python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
lines = manifest_path.read_text(encoding='utf-8').splitlines()
result = []
in_lotti = False
in_sources = False

idx = 0
length = len(lines)
while idx < length:
    line = lines[idx]
    stripped = line.strip()

    if stripped.startswith('- name: '):
        in_lotti = stripped == '- name: lotti'
        in_sources = False
    elif in_lotti and line.startswith('    sources:'):
        in_sources = True

    if in_lotti and in_sources and line.startswith('      - type: git'):
        j = idx + 1
        is_flutter_dependency = False
        while j < length and lines[j].startswith('        '):
            if lines[j].strip().startswith('dest:') and 'flutter' in lines[j]:
                is_flutter_dependency = True
            j += 1
        if is_flutter_dependency:
            idx = j
            continue

    result.append(line)
    idx += 1

manifest_path.write_text('\n'.join(result) + '\n', encoding='utf-8')
PY
        print_info "Bundled Flutter archive ${FLUTTER_ARCHIVE_BASENAME} for offline builds"
      else
        print_warning "No cached Flutter archive found; flutter-sdk module will continue to reference upstream git"
      fi
    fi
  fi

  if [ "$USE_OFFLINE_PYTHON" = "true" ]; then
    print_info "Ensuring python3-jinja2 module sources use cached artifacts..."

    JINJA_FILENAME="jinja2-3.1.4-py3-none-any.whl"
    if JINJA_SOURCE=$(find_cached_source_file "$JINJA_FILENAME"); then
      if [ ! -f "$OUTPUT_DIR/$JINJA_FILENAME" ]; then
        cp -- "$JINJA_SOURCE" "$OUTPUT_DIR/$JINJA_FILENAME"
      fi
      replace_source_url_with_path "$OUT_MANIFEST" "$JINJA_FILENAME" "$JINJA_FILENAME"
      print_info "Bundled $JINJA_FILENAME from cache"
    else
      print_warning "Cached $JINJA_FILENAME not found; manifest will reference upstream URL"
    fi

    MARKUPSAFE_FILENAME="MarkupSafe-2.1.5.tar.gz"
    if MARKUPSAFE_SOURCE=$(find_cached_source_file "$MARKUPSAFE_FILENAME"); then
      if [ ! -f "$OUTPUT_DIR/$MARKUPSAFE_FILENAME" ]; then
        cp -- "$MARKUPSAFE_SOURCE" "$OUTPUT_DIR/$MARKUPSAFE_FILENAME"
      fi
      replace_source_url_with_path "$OUT_MANIFEST" "$MARKUPSAFE_FILENAME" "$MARKUPSAFE_FILENAME"
      print_info "Bundled $MARKUPSAFE_FILENAME from cache"
    else
      print_warning "Cached $MARKUPSAFE_FILENAME not found; manifest will reference upstream URL"
    fi
  fi

  if [ "$USE_OFFLINE_ARCHIVES" = "true" ]; then
    print_info "Bundling cached archive and file sources referenced by manifest..."
    while IFS= read -r report_line; do
      [ -z "$report_line" ] && continue
      action="${report_line%% *}"
      remainder="${report_line#* }"
      case "$action" in
        BUNDLE)
          print_info "Bundled ${remainder}"
          ;;
        MISSING)
          missing_file="${remainder%% *}"
          missing_url="${remainder#* }"
          print_warning "No cached copy for ${missing_file}; leaving URL ${missing_url}"
          ;;
      esac
    done < <(python3 - "$OUT_MANIFEST" "$OUTPUT_DIR" \
      "$FLATPAK_DIR/.flatpak-builder/downloads" \
      "$LOTTI_ROOT/.flatpak-builder/downloads" \
      "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads" <<'PY'
import os
import sys
from pathlib import Path
import shutil

manifest_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
search_roots = [Path(p) for p in sys.argv[3:] if p and Path(p).exists()]

# Index cached files by filename for quick lookup
cache_index = {}
for root in search_roots:
    if not root.is_dir():
        continue
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            cache_index.setdefault(name, os.path.join(dirpath, name))

lines = manifest_path.read_text(encoding='utf-8').splitlines()
current_type = None
modified = False

for idx, line in enumerate(lines):
    stripped = line.strip()
    # Track the current source entry type based on indentation level used in manifest
    if line.startswith('      - ') and 'type:' in stripped:
        current_type = stripped.split(':', 1)[1].strip()
    elif line.startswith('      - '):
        current_type = None

    if not line.startswith('        url: '):
        continue

    if current_type not in {'archive', 'file'}:
        continue

    url = stripped.split(':', 1)[1].strip()
    filename = os.path.basename(url)

    cached_path = cache_index.get(filename)
    if cached_path is None:
        print(f"MISSING {filename} {url}")
        continue

    dest_path = output_dir / filename
    if not dest_path.exists():
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cached_path, dest_path)

    # Replace url entry with path to bundled file
    lines[idx] = line.replace(f"url: {url}", f"path: {filename}")
    modified = True
    print(f"BUNDLE {filename}")

if modified:
    manifest_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
    )
  fi

  # Restore any temporary local Flutter git URLs back to upstream origin for submission safety
  python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
lines = manifest_path.read_text(encoding='utf-8').splitlines()

current_type = None
url_index = None
for idx, line in enumerate(lines):
    stripped = line.strip()
    if line.startswith('      - ') and 'type:' in stripped:
        current_type = stripped.split(':', 1)[1].strip()
        url_index = None
        continue
    if line.startswith('      - '):
        current_type = None
        url_index = None
        continue

    if current_type != 'git':
        continue

    if line.startswith('        url: '):
        url_index = idx
        continue

    if url_index is None:
        continue

    if line.startswith('        dest: ') and stripped.endswith('flutter'):
        lines[url_index] = '        url: https://github.com/flutter/flutter.git'
        url_index = None

manifest_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY

  if [ "$USE_OFFLINE_APP_SOURCE" = "true" ]; then
    LOTT_ARCHIVE_NAME="lotti-${APP_COMMIT}.tar.xz"
    LOTT_ARCHIVE_PATH="$OUTPUT_DIR/$LOTT_ARCHIVE_NAME"

    if [ ! -f "$LOTT_ARCHIVE_PATH" ]; then
      print_info "Creating archived app source ${LOTT_ARCHIVE_NAME}"
      git -C "$LOTTI_ROOT" archive --format=tar --prefix=lotti/ "$APP_COMMIT" | xz > "$LOTT_ARCHIVE_PATH"
    fi

    LOTT_ARCHIVE_SHA256=$(sha256sum "$LOTT_ARCHIVE_PATH" | awk '{print $1}')

    python3 - "$OUT_MANIFEST" "$LOTT_ARCHIVE_NAME" "$LOTT_ARCHIVE_SHA256" <<'PY'
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
archive_name = sys.argv[2]
archive_sha = sys.argv[3]

lines = manifest_path.read_text(encoding='utf-8').splitlines()
result = []
in_lotti = False
in_sources = False
replaced = False

idx = 0
length = len(lines)
while idx < length:
    line = lines[idx]
    stripped = line.strip()

    if stripped.startswith('- name: '):
        in_lotti = stripped == '- name: lotti'
        in_sources = False
    elif in_lotti and line.startswith('    sources:'):
        in_sources = True

    if (
        in_lotti
        and in_sources
        and not replaced
        and line.startswith('      - type: git')
    ):
        # Look ahead to check if this git source targets the Lotti repository
        j = idx + 1
        is_lotti_repo = False
        while j < length and lines[j].startswith('        '):
            if 'github.com/matthiasn/lotti' in lines[j]:
                is_lotti_repo = True
                break
            j += 1

        if is_lotti_repo:
            result.append('      - type: archive')
            result.append(f'        path: {archive_name}')
            result.append(f'        sha256: {archive_sha}')
            result.append('        strip-components: 1')
            replaced = True
            idx += 1
            while idx < length and lines[idx].startswith('        '):
                idx += 1
            continue

    result.append(line)
    idx += 1

manifest_path.write_text('\n'.join(result) + '\n', encoding='utf-8')
PY
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
