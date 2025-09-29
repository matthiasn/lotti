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
# This now delegates to the Python CLI tool for consistency
find_cached_flutter_dir() {
    python3 "$PYTHON_CLI" find-flutter-sdk \
        --search-root "$LOTTI_ROOT" \
        --max-depth 6 2>/dev/null || true
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

    # The Python CLI handles non-existent files and missing identifiers gracefully
    if [ -n "${PYTHON_CLI:-}" ] && [ -f "$PYTHON_CLI" ]; then
        python3 "$PYTHON_CLI" replace-url-with-path \
            --manifest "$manifest" \
            --identifier "$identifier" \
            --path "$path_value" 2>/dev/null || true
    fi
}

# Stage a pub.dev archive locally from available caches when missing.
stage_pubdev_archive() {
  local package="$1"
  local version="$2"
  local dest="$FLATPAK_DIR/cache/pub.dev/${package}-${version}.tar.gz"

  if [ -f "$dest" ]; then
    return 0
  fi

  local candidates=(
    "$LOTTI_ROOT/.pub-cache/hosted/pub.dev/${package}-${version}"
    "$HOME/.pub-cache/hosted/pub.dev/${package}-${version}"
  )
  if [ -n "${PUB_CACHE:-}" ]; then
    candidates+=("$PUB_CACHE/hosted/pub.dev/${package}-${version}")
  fi

  for candidate in "${candidates[@]}"; do
    if [ -d "$candidate" ]; then
      mkdir -p "$FLATPAK_DIR/cache/pub.dev"
      ( cd "$(dirname "$candidate")" && tar -czf "$dest" "${package}-${version}" )
      print_info "Staged pub.dev archive ${package}-${version} from ${candidate}"
      return 0
    fi
  done

  print_warning "Missing staged pub.dev archive for ${package}-${version}; offline bundling may fail"
  return 1
}

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOTTI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLATPAK_DIR="$LOTTI_ROOT/flatpak"
PYTHON_CLI="$FLATPAK_DIR/manifest_tool/cli.py"

# Work directory for generation
WORK_DIR="$FLATPAK_DIR/flathub-build"
OUTPUT_DIR="$WORK_DIR/output"

# Behavior toggles (can be overridden via env)
: "${CLEAN_AFTER_GEN:=true}"          # Remove .flatpak-builder after generation
: "${PIN_COMMIT:=true}"               # Pin app source to exact commit in output manifest
: "${USE_NESTED_FLUTTER:=false}"      # Prefer nested SDK module under lotti (false = keep top-level flutter-sdk)
: "${DOWNLOAD_MISSING_SOURCES:=true}" # Permit downloading sources when cache is absent

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

# Get the current branch (handle detached HEAD in CI gracefully)
CURRENT_BRANCH=$(cd "$LOTTI_ROOT" && git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" = "HEAD" ]; then
    if [ -n "${GITHUB_HEAD_REF:-}" ]; then
        CURRENT_BRANCH="$GITHUB_HEAD_REF"
        print_warning "Detached HEAD detected; using GitHub head ref: $CURRENT_BRANCH"
    elif [ -n "${GITHUB_REF_NAME:-}" ]; then
        CURRENT_BRANCH="$GITHUB_REF_NAME"
        print_warning "Detached HEAD detected; using GitHub ref name: $CURRENT_BRANCH"
    else
        CURRENT_BRANCH="main"
        print_warning "Detached HEAD detected with no ref information; defaulting branch to 'main'"
    fi
fi

# Verify branch exists on remote (optional warning if missing)
set +e
REMOTE_CHECK_OUTPUT=$(git -C "$LOTTI_ROOT" ls-remote origin "refs/heads/$CURRENT_BRANCH" 2>&1)
REMOTE_CHECK_STATUS=$?
set -e

if [ "$REMOTE_CHECK_STATUS" -eq 0 ]; then
    if [ -z "$REMOTE_CHECK_OUTPUT" ]; then
        print_warning "Branch $CURRENT_BRANCH not found on remote"
        print_info "Please ensure the branch is pushed before publishing"
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

# Show effective options for diagnostics
print_info "Effective options:"
echo "  PIN_COMMIT=${PIN_COMMIT}"
echo "  USE_NESTED_FLUTTER=${USE_NESTED_FLUTTER}"
echo "  DOWNLOAD_MISSING_SOURCES=${DOWNLOAD_MISSING_SOURCES}"
echo "  CLEAN_AFTER_GEN=${CLEAN_AFTER_GEN}"
echo "  NO_FLATPAK_FLUTTER=${NO_FLATPAK_FLUTTER:-false}"
echo "  FLATPAK_FLUTTER_TIMEOUT=${FLATPAK_FLUTTER_TIMEOUT:-<unset>}"
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
# Always use the canonical upstream URL for the injected Flutter git source so that
# flatpak-flutter can detect the tag and generate sources JSONs. We'll still reuse
# any cached SDK only for priming the build directory below.
FLUTTER_GIT_URL="https://github.com/flutter/flutter.git"
if [ -n "$CACHED_FLUTTER_DIR" ]; then
  print_info "Found cached Flutter SDK checkout at $CACHED_FLUTTER_DIR"
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

# Step 4: Run flatpak-flutter in work directory (with timeout + fallback)
print_status "Running flatpak-flutter to generate offline sources..."
cd "$WORK_DIR"

# Copy necessary files to work directory
cp -r "$LOTTI_ROOT/lib" .
cp -r "$LOTTI_ROOT/linux" .
cp "$LOTTI_ROOT/pubspec.yaml" .
cp "$LOTTI_ROOT/pubspec.lock" .

# Copy the setup helper script from the helpers directory
SETUP_HELPER_SOURCE="$FLATPAK_DIR/helpers/setup-flutter.sh"
SETUP_HELPER="$WORK_DIR/setup-flutter.sh"

if [ -f "$SETUP_HELPER_SOURCE" ]; then
  cp "$SETUP_HELPER_SOURCE" "$SETUP_HELPER"
  chmod +x "$SETUP_HELPER"
else
  print_error "Setup helper script not found at $SETUP_HELPER_SOURCE"
  exit 1
fi
SETUP_HELPER_BASENAME="$(basename "$SETUP_HELPER")"

python3 "$PYTHON_CLI" ensure-setup-helper \
  --manifest "$WORK_DIR/com.matthiasn.lotti.yml" \
  --helper "$SETUP_HELPER_BASENAME"

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
  # Use Python CLI to find Flutter SDK, excluding the work directory
  LOCAL_FLUTTER_DIR=""
  if [ -n "$CACHED_FLUTTER_DIR" ]; then
    # Check if the cached dir is not the target dir itself
    if [ "$CACHED_FLUTTER_DIR" != "$(cd "$TARGET_FLUTTER_DIR/.." 2>/dev/null && pwd)/flutter" ]; then
      LOCAL_FLUTTER_DIR="$CACHED_FLUTTER_DIR"
    fi
  fi

  # If still no SDK, use Python tool to find one
  if [ -z "$LOCAL_FLUTTER_DIR" ]; then
    LOCAL_FLUTTER_DIR=$(python3 "$PYTHON_CLI" find-flutter-sdk \
      --search-root "$LOTTI_ROOT" \
      --exclude "$WORK_DIR" \
      --exclude "$TARGET_FLUTTER_DIR" \
      --max-depth 6 2>/dev/null || echo "")
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

FLATPAK_FLUTTER_TIMEOUT="${FLATPAK_FLUTTER_TIMEOUT:-}"
NO_FLATPAK_FLUTTER="${NO_FLATPAK_FLUTTER:-false}"
FLATPAK_FLUTTER_STATUS=0

if [ "$NO_FLATPAK_FLUTTER" != "true" ]; then
  set +e
  if [ -n "$FLATPAK_FLUTTER_TIMEOUT" ]; then
    GIT_TERMINAL_PROMPT=0 timeout "$FLATPAK_FLUTTER_TIMEOUT" \
      python3 "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" \
        --app-module lotti \
        --keep-build-dirs \
        "com.matthiasn.lotti.yml" 2>&1 | tee flatpak-flutter.log
    FLATPAK_FLUTTER_STATUS=$?
  else
    GIT_TERMINAL_PROMPT=0 \
      python3 "$FLATPAK_DIR/flatpak-flutter/flatpak-flutter.py" \
        --app-module lotti \
        --keep-build-dirs \
        "com.matthiasn.lotti.yml" 2>&1 | tee flatpak-flutter.log
    FLATPAK_FLUTTER_STATUS=$?
  fi
  set -e
  if [ $FLATPAK_FLUTTER_STATUS -eq 0 ]; then
    print_status "Generated offline manifest and dependencies"
  else
    if [ $FLATPAK_FLUTTER_STATUS -eq 124 ]; then
      print_warning "flatpak-flutter timed out after ${FLATPAK_FLUTTER_TIMEOUT}s; set FLATPAK_FLUTTER_TIMEOUT to a larger value or unset to disable. Proceeding with fallback generation."
    else
      print_warning "flatpak-flutter did not complete (exit ${FLATPAK_FLUTTER_STATUS}); proceeding with fallback generation"
    fi
    print_info "Check flatpak-flutter.log for partial output"
  fi
else
  print_info "Skipping flatpak-flutter run (NO_FLATPAK_FLUTTER=true); using fallback generation paths"
  FLATPAK_FLUTTER_STATUS=124
fi

# Normalize sqlite3 plugin patch to 3.50.4 (3500400) so CMake uses local tarball
# flatpak-flutter may ship a patch for an earlier sqlite version (e.g., 3500100).
# Update it here to match our pre-fetched archive and SHA.
SQLITE_PATCH_CANDIDATE="$WORK_DIR/sqlite3_flutter_libs/0.5.34-CMakeLists.txt.patch"
if [ -f "$SQLITE_PATCH_CANDIDATE" ]; then
  print_info "Normalizing sqlite3 patch to 3.50.4 (3500400) with SHA verification"
  sed -i -E 's/sqlite-autoconf-3500[0-9]{2}00/sqlite-autoconf-3500400/g' "$SQLITE_PATCH_CANDIDATE" || true
  sed -i -E 's/SHA256=[0-9a-f]{64}/SHA256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18/g' "$SQLITE_PATCH_CANDIDATE" || true
fi

# Pin commit in the working manifest before submission/copy
APP_COMMIT=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)
print_status "Pinning working manifest to commit: $APP_COMMIT"
python3 "$PYTHON_CLI" pin-commit \
  --manifest "$WORK_DIR/com.matthiasn.lotti.yml" \
  --commit "$APP_COMMIT"

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
cp -- rustup-*.json "$OUTPUT_DIR/" 2>/dev/null || print_info "No rustup JSON found (will rely on SDK extension if not present)"
cp -- package_config.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No package_config.json found"
cp -- "$WORK_DIR/setup-flutter.sh" "$OUTPUT_DIR/" 2>/dev/null || true

# Collect JSON artifacts from build directories when generated elsewhere
for search_root in . ..; do
  for pattern in \
    '*/.flatpak-builder/*/pubspec-sources.json' \
    '*/.flatpak-builder/*/cargo-sources.json' \
    '*/.flatpak-builder/*/flutter-sdk-*.json'; do
    while IFS= read -r json; do
      [ -n "${json:-}" ] || continue
      base=$(basename "$json")
      cp -- "$json" "$OUTPUT_DIR/" 2>/dev/null && print_info "Bundled $base" || true
    done < <(find "$search_root" -maxdepth 10 -path "$pattern" -print 2>/dev/null)
  done
done

# Fallback: generate pubspec-sources.json and package_config.json if missing
# Also: generate cargo-sources.json if cargo locks are present but the file is missing
if [ ! -f "$OUTPUT_DIR/cargo-sources.json" ]; then
  print_warning "No cargo-sources.json; attempting to generate from Cargo.lock files..."
  # Look for Cargo.lock files in multiple possible locations within cargokit-based plugins
  CARGO_LOCKS=""
  for pattern in \
    '*/.pub-cache/hosted/pub.dev/*/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/android/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/ios/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/linux/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/macos/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/windows/rust/Cargo.lock'; do
    FOUND=$(find "$WORK_DIR/.flatpak-builder/build" -maxdepth 8 -path "$pattern" -print 2>/dev/null || true)
    if [ -n "$FOUND" ]; then
      if [ -n "$CARGO_LOCKS" ]; then
        CARGO_LOCKS="$CARGO_LOCKS
$FOUND"
      else
        CARGO_LOCKS="$FOUND"
      fi
    fi
  done

  if [ -n "$CARGO_LOCKS" ]; then
    # Remove duplicates and create comma-separated list
    UNIQUE_LOCKS=$(echo "$CARGO_LOCKS" | sort -u | grep -v '^$')
    LOCK_COUNT=$(echo "$UNIQUE_LOCKS" | wc -l)
    print_info "Found $LOCK_COUNT Cargo.lock file(s) for cargo-sources generation"
    LOCK_LIST=$(echo "$UNIQUE_LOCKS" | paste -sd, -)
    if python3 "$FLATPAK_DIR/flatpak-flutter/cargo_generator/cargo_generator.py" "$LOCK_LIST" -o "$WORK_DIR/cargo-sources.json"; then
      cp -- "$WORK_DIR/cargo-sources.json" "$OUTPUT_DIR/" 2>/dev/null && print_status "Generated cargo-sources.json from Cargo.lock"
    else
      print_warning "Failed to synthesize cargo-sources.json via cargo_generator"
    fi
  else
    print_warning "No Cargo.lock files found under .flatpak-builder; skipping cargo-sources generation"
  fi
fi

APP_LOCK="$WORK_DIR/pubspec.lock"
TOOLS_LOCK=""
if [ -d "$WORK_DIR/.flatpak-builder/build" ]; then
  TOOLS_LOCK="$(find "$WORK_DIR/.flatpak-builder/build" -maxdepth 5 -path '*/flutter/packages/flutter_tools/pubspec.lock' -print -quit 2>/dev/null || true)"
fi

if [ -z "$TOOLS_LOCK" ]; then
  if [ -f "$FLATPAK_DIR/cache/flutter_tools/pubspec.lock" ]; then
    TOOLS_LOCK="$FLATPAK_DIR/cache/flutter_tools/pubspec.lock"
    print_info "Using staged flutter_tools pubspec.lock from cache/flutter_tools"
  else
  print_warning "Could not locate flutter_tools pubspec.lock within .flatpak-builder cache"
  fi
fi

CARGOKIT_LOCKS=""
if [ -d "$WORK_DIR/.flatpak-builder/build" ] || [ -d "$OUTPUT_DIR/.flatpak-builder/build" ]; then
  TMP_LOCKS=""
  for search_root in \
    "$WORK_DIR/.flatpak-builder/build" \
    "$OUTPUT_DIR/.flatpak-builder/build"; do
    [ -d "$search_root" ] || continue
    found=$(find "$search_root" -maxdepth 15 -path '*/cargokit/build_tool/pubspec.lock' -print 2>/dev/null || true)
    if [ -n "$found" ]; then
      if [ -n "$TMP_LOCKS" ]; then
        TMP_LOCKS="$TMP_LOCKS
$found"
      else
        TMP_LOCKS="$found"
      fi
    fi
  done
  if [ -n "$TMP_LOCKS" ]; then
    CARGOKIT_LOCKS=$(printf "%s" "$TMP_LOCKS" | sort -u)
  fi
fi

# Include any pre-staged cargokit lockfiles bundled with the repository
PRESET_CARGOKIT_LOCKS=""
if [ -d "$FLATPAK_DIR/cache/cargokit" ]; then
  PRESET_CARGOKIT_LOCKS=$(find "$FLATPAK_DIR/cache/cargokit" -maxdepth 1 -name '*.pubspec.lock' -print 2>/dev/null | sort -u || true)
fi

LOCK_INPUTS=""
if [ -f "$APP_LOCK" ]; then
  LOCK_INPUTS="$APP_LOCK"
  if [ -n "$TOOLS_LOCK" ] && [ -f "$TOOLS_LOCK" ]; then
    LOCK_INPUTS="$LOCK_INPUTS,$TOOLS_LOCK"
  fi
  if [ -n "$CARGOKIT_LOCKS" ]; then
    CARGOKIT_LIST=$(echo "$CARGOKIT_LOCKS" | paste -sd, -)
    LOCK_INPUTS="$LOCK_INPUTS,$CARGOKIT_LIST"
  fi
  if [ -n "$PRESET_CARGOKIT_LOCKS" ]; then
    PRESET_LIST=$(echo "$PRESET_CARGOKIT_LOCKS" | paste -sd, -)
    LOCK_INPUTS="$LOCK_INPUTS,$PRESET_LIST"
  fi
fi

if [ -n "$LOCK_INPUTS" ]; then
  print_info "Generating pubspec-sources.json from lockfiles"
  if [ -n "$CARGOKIT_LOCKS" ]; then
    LOCK_COUNT=$(echo "$CARGOKIT_LOCKS" | grep -c . || true)
    print_info "Including ${LOCK_COUNT} cargokit lockfile(s)"
  fi
  if python3 "$FLATPAK_DIR/flatpak-flutter/pubspec_generator/pubspec_generator.py" \
    "$LOCK_INPUTS" -o "$WORK_DIR/pubspec-sources.generated.json"; then
    mv "$WORK_DIR/pubspec-sources.generated.json" "$OUTPUT_DIR/pubspec-sources.json"
    cp -- "$OUTPUT_DIR/pubspec-sources.json" "$WORK_DIR/../pubspec-sources.json" 2>/dev/null || true
    print_status "Regenerated pubspec-sources.json with build tool dependencies"

    if [ -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
      OUT_JSON="$OUTPUT_DIR/pubspec-sources.json"
      STAGED_PACKAGES=$(OUT_JSON="$OUT_JSON" python3 - <<'PY'
import json
import os

path = os.environ["OUT_JSON"]
data = json.loads(open(path, "r", encoding="utf-8").read())
seen = set()
for entry in data:
    if isinstance(entry, dict):
        dest = entry.get("dest", "")
        if dest.startswith(".pub-cache/hosted/pub.dev/"):
            name_version = dest.split("/")[-1]
            if "-" in name_version:
                pkg, ver = name_version.rsplit("-", 1)
                if pkg and ver and (pkg, ver) not in seen:
                    seen.add((pkg, ver))
                    print(f"{pkg} {ver}")
PY
)
      if [ -n "$STAGED_PACKAGES" ]; then
        while read -r pkg ver; do
          # Try to stage package archives, but don't fail if not found
          [ -n "$pkg" ] && stage_pubdev_archive "$pkg" "$ver" || true
        done <<EOF
$STAGED_PACKAGES
EOF
      fi
    fi
  else
    print_error "Failed to regenerate pubspec-sources.json"
  fi
else
  print_warning "Missing pubspec.lock inputs; cannot regenerate pubspec-sources.json"
fi

# Also stage the current package_config.json if available to speed offline bootstrap
if [ -n "$TOOLS_LOCK" ] && [ -f "$TOOLS_LOCK" ]; then
  TOOLS_DIR="$(dirname "$TOOLS_LOCK")"
  PKG_CFG="$TOOLS_DIR/.dart_tool/package_config.json"
  if [ -f "$PKG_CFG" ]; then
    cp -- "$PKG_CFG" "$OUTPUT_DIR/package_config.json" || true
  else
    PKG_CFG_FALLBACK=""
    if [ -d "$WORK_DIR/.flatpak-builder/build" ]; then
      PKG_CFG_FALLBACK="$(find "$WORK_DIR/.flatpak-builder/build" -maxdepth 5 -path '*/flutter/packages/flutter_tools/.dart_tool/package_config.json' -print -quit 2>/dev/null || true)"
    fi
    if [ -n "$PKG_CFG_FALLBACK" ] && [ -f "$PKG_CFG_FALLBACK" ]; then
      cp -- "$PKG_CFG_FALLBACK" "$OUTPUT_DIR/package_config.json" || true
    else
      print_warning "Could not locate flutter_tools package_config.json for offline cache"
    fi
  fi
fi

# Fallback: if flatpak-flutter did not emit a flutter-sdk-*.json, generate one
FLUTTER_JSON_PATH=""
for candidate in "$OUTPUT_DIR"/flutter-sdk-*.json; do
  if [ -e "$candidate" ]; then
    FLUTTER_JSON_PATH="$candidate"
    break
  fi
done

if [ -z "$FLUTTER_JSON_PATH" ]; then
  print_warning "No flutter-sdk JSON produced by flatpak-flutter; generating locally..."
  GEN_INPUT_DIR="$WORK_DIR/.flatpak-builder/build/lotti/flutter"
  if [ -x "$GEN_INPUT_DIR/bin/flutter" ]; then
    GEN_OUT="$OUTPUT_DIR/flutter-sdk-${FLUTTER_TAG}.json"
    python3 "$FLATPAK_DIR/flatpak-flutter/flutter_sdk_generator/flutter_sdk_generator.py" "$GEN_INPUT_DIR" -o "$GEN_OUT" || print_error "Failed to generate flutter-sdk JSON"
    if [ -f "$GEN_OUT" ]; then
      print_status "Generated $GEN_OUT"
    fi
  else
    print_warning "Primed Flutter SDK not found at $GEN_INPUT_DIR; cannot generate flutter-sdk JSON"
  fi
fi

if [ ! -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
  print_error "pubspec-sources.json missing after preparation; offline bundle is incomplete"
  exit 1
fi

# Check if files were generated in parent directory
if [ -f "../pubspec-sources.json" ]; then
    print_info "Found generated files in parent directory, copying..."
    for candidate in ../flutter-sdk-*.json; do
      [ -f "$candidate" ] || continue
      cp -- "$candidate" "$OUTPUT_DIR/" 2>/dev/null || true
    done
    cp -- ../pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null || true
    cp -- ../cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null || true
    for candidate in ../rustup-*.json; do
      [ -f "$candidate" ] || continue
      cp -- "$candidate" "$OUTPUT_DIR/" 2>/dev/null || true
    done
    cp -- ../package_config.json "$OUTPUT_DIR/" 2>/dev/null || true
fi

# Step 6: Copy additional required files
print_status "Copying additional files..."

# Path to the output manifest for subsequent operations
OUT_MANIFEST="$OUTPUT_DIR/com.matthiasn.lotti.yml"

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

# Copy Flutter helper patches if referenced by the manifest
for flutter_patch in flutter-shared.sh.patch flutter-pre-3_35-shared.sh.patch; do
  patch_source=""
  if [ -f "$FLATPAK_DIR/flatpak-flutter/releases/flutter/$flutter_patch" ]; then
    patch_source="$FLATPAK_DIR/flatpak-flutter/releases/flutter/$flutter_patch"
  elif [ -f "$FLATPAK_DIR/flatpak-flutter/$flutter_patch" ]; then
    patch_source="$FLATPAK_DIR/flatpak-flutter/$flutter_patch"
  fi

  if [ -n "$patch_source" ]; then
    cp -- "$patch_source" "$OUTPUT_DIR/$flutter_patch"
    cp -- "$patch_source" "$WORK_DIR/$flutter_patch"
  fi

  if [ -f "$OUT_MANIFEST" ] && grep -q "$flutter_patch" "$OUT_MANIFEST" 2>/dev/null; then
    if [ -n "$patch_source" ]; then
      replace_source_url_with_path "$OUT_MANIFEST" "$flutter_patch" "$flutter_patch"
      print_info "Bundled Flutter patch $flutter_patch"
    else
      print_warning "Referenced Flutter patch $flutter_patch not found in flatpak-flutter sources"
    fi
  fi
done

# Copy patch directories if needed
if [ -d "$FLATPAK_DIR/patches" ]; then
    cp -r "$FLATPAK_DIR/patches" "$OUTPUT_DIR/"
fi

# Download Cargo.lock files from GitHub for cargokit-based plugins
# Always run this to ensure we have the correct versions (overwriting flatpak-flutter's inadequate cargo-sources.json)
if [ -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
  print_info "Downloading Cargo.lock files from GitHub to generate correct cargo-sources.json..."
  if [ -x "$FLATPAK_DIR/download_cargo_locks.sh" ]; then
    if bash "$FLATPAK_DIR/download_cargo_locks.sh"; then
      print_status "Generated cargo-sources.json from downloaded Cargo.lock files"
    else
      print_warning "Failed to generate cargo-sources.json from downloaded files"
    fi
  else
    print_warning "download_cargo_locks.sh not found or not executable"
  fi
# Legacy: Check for pre-saved Cargo.lock files (for known Rust plugins)
elif [ -d "$FLATPAK_DIR/cargo-lock-files" ] && [ ! -f "$OUTPUT_DIR/cargo-sources.json" ]; then
  print_info "Using pre-saved Cargo.lock files for cargo-sources.json generation..."
  CARGOKIT_CARGO_LOCKS=""
  for lock_file in "$FLATPAK_DIR"/cargo-lock-files/*.lock; do
    if [ -f "$lock_file" ]; then
      if [ -n "$CARGOKIT_CARGO_LOCKS" ]; then
        CARGOKIT_CARGO_LOCKS="$CARGOKIT_CARGO_LOCKS,$lock_file"
      else
        CARGOKIT_CARGO_LOCKS="$lock_file"
      fi
      print_info "Using Cargo.lock: $(basename "$lock_file")"
    fi
  done

  if [ -n "$CARGOKIT_CARGO_LOCKS" ]; then
    if python3 "$FLATPAK_DIR/flatpak-flutter/cargo_generator/cargo_generator.py" "$CARGOKIT_CARGO_LOCKS" -o "$WORK_DIR/cargo-sources-cargokit.json"; then
      cp -- "$WORK_DIR/cargo-sources-cargokit.json" "$OUTPUT_DIR/cargo-sources.json" 2>/dev/null && print_status "Generated cargo-sources.json from pre-saved Cargo.lock files"
    else
      print_warning "Failed to generate cargo-sources.json from pre-saved Cargo.lock files"
    fi
  fi
fi

# Fallback to discovery if pre-saved files don't exist or cargo-sources.json wasn't generated
if [ -d "$WORK_DIR/.flatpak-builder/build" ] && [ ! -f "$OUTPUT_DIR/cargo-sources.json" ]; then
  print_info "Looking for cargokit Cargo.lock files to generate cargo-sources.json..."
  CARGOKIT_CARGO_LOCKS=""
  for pattern in \
    '*/.pub-cache/hosted/pub.dev/*/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/android/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/ios/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/linux/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/macos/rust/Cargo.lock' \
    '*/.pub-cache/hosted/pub.dev/*/windows/rust/Cargo.lock'; do
    FOUND=$(find "$WORK_DIR/.flatpak-builder/build" -maxdepth 8 -path "$pattern" -print 2>/dev/null || true)
    if [ -n "$FOUND" ]; then
      if [ -n "$CARGOKIT_CARGO_LOCKS" ]; then
        CARGOKIT_CARGO_LOCKS="$CARGOKIT_CARGO_LOCKS
$FOUND"
      else
        CARGOKIT_CARGO_LOCKS="$FOUND"
      fi
    fi
  done

  if [ -n "$CARGOKIT_CARGO_LOCKS" ]; then
    UNIQUE_CARGO_LOCKS=$(echo "$CARGOKIT_CARGO_LOCKS" | sort -u | grep -v '^$')
    CARGO_LOCK_COUNT=$(echo "$UNIQUE_CARGO_LOCKS" | wc -l)
    print_info "Found $CARGO_LOCK_COUNT cargokit Cargo.lock file(s)"
    CARGO_LOCK_LIST=$(echo "$UNIQUE_CARGO_LOCKS" | paste -sd, -)
    if python3 "$FLATPAK_DIR/flatpak-flutter/cargo_generator/cargo_generator.py" "$CARGO_LOCK_LIST" -o "$WORK_DIR/cargo-sources-cargokit.json"; then
      cp -- "$WORK_DIR/cargo-sources-cargokit.json" "$OUTPUT_DIR/cargo-sources.json" 2>/dev/null && print_status "Generated cargo-sources.json from cargokit Cargo.lock files"
    else
      print_warning "Failed to generate cargo-sources.json from cargokit Cargo.lock files"
    fi
  fi
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
  python3 "$PYTHON_CLI" normalize-lotti-env \
    --manifest "$OUT_MANIFEST" \
    --layout top

  # Remove --share=network from build-args for Flathub compliance
  # Flathub strictly prohibits network access during builds
  python3 "$PYTHON_CLI" remove-network-from-build-args \
    --manifest "$OUT_MANIFEST"

  # Ensure flutter pub get uses --offline flag for Flathub compliance
  python3 "$PYTHON_CLI" ensure-flutter-pub-get-offline \
    --manifest "$OUT_MANIFEST"

  # Remove flutter config invocations to avoid pub upgrade cycles offline
  python3 "$PYTHON_CLI" remove-flutter-config \
    --manifest "$OUT_MANIFEST"

  # Add --no-pub flag to flutter build to skip automatic pub get
  # This prevents the internal dart pub get --example from attempting network access
  python3 "$PYTHON_CLI" ensure-dart-pub-offline-in-build \
    --manifest "$OUT_MANIFEST"

  # Add mimalloc source for media_kit_libs_linux plugin
  # This provides the mimalloc archive that the plugin needs during build
  python3 "$PYTHON_CLI" add-media-kit-mimalloc-source \
    --manifest "$OUT_MANIFEST"

  # Add SQLite source for sqlite3_flutter_libs plugin
  # This provides the SQLite archive that the plugin needs during build
  python3 "$PYTHON_CLI" add-sqlite3-source \
    --manifest "$OUT_MANIFEST"

  # Prefer Rust SDK extension over rustup installer
  python3 "$PYTHON_CLI" ensure-rust-sdk-env \
    --manifest "$OUT_MANIFEST"
  python3 "$PYTHON_CLI" remove-rustup-install \
    --manifest "$OUT_MANIFEST"

  # If a rustup JSON module is present, include it before lotti so rustup
  # is available for cargokit-based plugins that require rustup.
  RUSTUP_MOD=""
  for candidate in "$OUTPUT_DIR"/rustup-*.json; do
    if [ -e "$candidate" ]; then
      RUSTUP_MOD="$(basename "$candidate")"
      break
    fi
  done
  if [ -n "$RUSTUP_MOD" ]; then
    print_info "Including rustup module $RUSTUP_MOD before lotti"
    python3 "$PYTHON_CLI" ensure-module-include \
      --manifest "$OUT_MANIFEST" \
      --name "$RUSTUP_MOD" \
      --before lotti
  else
    print_info "No rustup module JSON found; proceeding with Rust SDK extension only"
  fi

  if [ "$PIN_COMMIT" = "true" ]; then
    APP_COMMIT=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)
    print_info "Pinning app source to commit: $APP_COMMIT"
    python3 "$PYTHON_CLI" pin-commit \
      --manifest "$OUT_MANIFEST" \
      --commit "$APP_COMMIT"
  fi

  if [ "$USE_NESTED_FLUTTER" = "true" ]; then
    python3 "$PYTHON_CLI" ensure-nested-sdk \
      --manifest "$OUT_MANIFEST" \
      --output-dir "$OUTPUT_DIR"
  fi

  # Process offline Flutter JSON (required for Flathub compliance)
  FLUTTER_JSON=""
  for candidate in "$OUTPUT_DIR"/flutter-sdk-*.json; do
    if [ -e "$candidate" ]; then
      FLUTTER_JSON="$(basename "$candidate")"
      break
    fi
  done

  REMOVE_FLUTTER_SDK=$(python3 "$PYTHON_CLI" should-remove-flutter-sdk \
    --manifest "$OUT_MANIFEST" \
    --output-dir "$OUTPUT_DIR")

  if [ "${REMOVE_FLUTTER_SDK:-0}" = "1" ]; then
    print_info "Offline Flutter JSON found and referenced; removing top-level flutter-sdk module."
    awk '
      BEGIN{skip=0}
      /^\s*- name: flutter-sdk\s*$/ {skip=1}
      skip && /^\s*- name: / {skip=0}
      !skip {print}
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"
  else
    print_info "Keeping top-level flutter-sdk module (offline JSON missing or not referenced)."
  fi

  python3 "$PYTHON_CLI" normalize-flutter-sdk-module \
    --manifest "$OUT_MANIFEST"

  PUBSPEC_JSON=""
  if [ -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
    PUBSPEC_JSON="pubspec-sources.json"
  fi

  CARGO_JSON=""
  if [ -f "$OUTPUT_DIR/cargo-sources.json" ]; then
    CARGO_JSON="cargo-sources.json"
  fi

  print_info "Adding offline sources: ${FLUTTER_JSON:-none} ${PUBSPEC_JSON:-} ${CARGO_JSON:-}"
  PYTHON_OFFLINE_ARGS=(
    "$PYTHON_CLI" add-offline-sources
    --manifest "$OUT_MANIFEST"
  )
  if [ -n "$PUBSPEC_JSON" ]; then
    PYTHON_OFFLINE_ARGS+=(--pubspec "$PUBSPEC_JSON")
  fi
  if [ -n "$CARGO_JSON" ]; then
    PYTHON_OFFLINE_ARGS+=(--cargo "$CARGO_JSON")
  fi
  if [ "$USE_NESTED_FLUTTER" = "true" ] && [ -n "$FLUTTER_JSON" ]; then
    PYTHON_OFFLINE_ARGS+=(--flutter-json "$FLUTTER_JSON")
  fi
  python3 "${PYTHON_OFFLINE_ARGS[@]}"

  if [ "${REMOVE_FLUTTER_SDK:-0}" = "1" ]; then
    python3 "$PYTHON_CLI" normalize-lotti-env \
      --manifest "$OUT_MANIFEST" \
      --layout nested \
      --append-path
    python3 "$PYTHON_CLI" ensure-lotti-setup-helper \
      --manifest "$OUT_MANIFEST" \
      --layout nested \
      --helper "$SETUP_HELPER_BASENAME"
  else
    python3 "$PYTHON_CLI" normalize-lotti-env \
      --manifest "$OUT_MANIFEST" \
      --layout top \
      --append-path
    python3 "$PYTHON_CLI" ensure-lotti-setup-helper \
      --manifest "$OUT_MANIFEST" \
      --layout top \
      --helper "$SETUP_HELPER_BASENAME"
  fi

  python3 "$PYTHON_CLI" normalize-sdk-copy \
    --manifest "$OUT_MANIFEST"

  # Ensure no rustup JSONs are referenced in sources (we rely on the Rust SDK extension)
  python3 "$PYTHON_CLI" remove-rustup-sources \
    --manifest "$OUT_MANIFEST"
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
          if ($0 ~ /CMakeLists\.txt\.patch/) { has_cmake=1 }
          buf[++buf_cnt]=$0
          if ($0 ~ /^\s{6}-\s/ ) {
            if (!has_cmake) { for (i=1;i<=buf_cnt-1;i++) print buf[i]; }
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

  if [ -z "$FLUTTER_JSON" ]; then
    FLUTTER_ARCHIVE_BASENAME="flutter_linux_${FLUTTER_TAG}-stable.tar.xz"
    FLUTTER_ARCHIVE_SOURCE=""

    if [ -f "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME" ]; then
      FLUTTER_ARCHIVE_SOURCE="$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME"
    else
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
    fi

    if [ -z "$FLUTTER_ARCHIVE_SOURCE" ] && [ "$DOWNLOAD_MISSING_SOURCES" = "true" ]; then
      FLUTTER_ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_TAG}-stable.tar.xz"
      print_info "Downloading Flutter archive ${FLUTTER_ARCHIVE_BASENAME}"
      if curl -L --fail -o "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME" "$FLUTTER_ARCHIVE_URL"; then
        FLUTTER_ARCHIVE_SOURCE="$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME"
      else
        print_warning "Failed to download Flutter archive from $FLUTTER_ARCHIVE_URL"
      fi
    fi

    if [ -n "$FLUTTER_ARCHIVE_SOURCE" ]; then
      FLUTTER_ARCHIVE_BASENAME="$(basename "$FLUTTER_ARCHIVE_SOURCE")"
      if [ "$FLUTTER_ARCHIVE_SOURCE" != "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME" ]; then
        cp -- "$FLUTTER_ARCHIVE_SOURCE" "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME"
      fi
      FLUTTER_ARCHIVE_SHA256=$(sha256sum "$OUTPUT_DIR/$FLUTTER_ARCHIVE_BASENAME" | awk '{print $1}')

      python3 "$PYTHON_CLI" convert-flutter-git-to-archive \
        --manifest "$OUT_MANIFEST" \
        --archive "$FLUTTER_ARCHIVE_BASENAME" \
        --sha256 "$FLUTTER_ARCHIVE_SHA256"
      print_info "Bundled Flutter archive ${FLUTTER_ARCHIVE_BASENAME} for offline builds"
    else
      print_warning "No cached Flutter archive found; flutter-sdk module will continue to reference upstream git"
    fi
  fi

  # Bundle all archive and file sources for offline builds (required by Flathub)
  print_info "Bundling cached archive and file sources referenced by manifest..."
  if [ -d "$FLATPAK_DIR/cache/pub.dev" ]; then
    print_info "Using staged pub.dev cache from cache/pub.dev"
  fi
  if [ "$DOWNLOAD_MISSING_SOURCES" = "true" ]; then
    python3 "$PYTHON_CLI" bundle-archive-sources \
      --manifest "$OUT_MANIFEST" \
      --output-dir "$OUTPUT_DIR" \
      --download-missing \
      --search-root "$FLATPAK_DIR/cache/pub.dev" \
      --search-root "$FLATPAK_DIR/.flatpak-builder/downloads" \
      --search-root "$LOTTI_ROOT/.flatpak-builder/downloads" \
      --search-root "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads"
  else
    python3 "$PYTHON_CLI" bundle-archive-sources \
      --manifest "$OUT_MANIFEST" \
      --output-dir "$OUTPUT_DIR" \
      --search-root "$FLATPAK_DIR/cache/pub.dev" \
      --search-root "$FLATPAK_DIR/.flatpak-builder/downloads" \
      --search-root "$LOTTI_ROOT/.flatpak-builder/downloads" \
      --search-root "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads"
  fi

  python3 "$PYTHON_CLI" rewrite-flutter-git-url \
    --manifest "$OUT_MANIFEST"

  # Bundle app source as archive for offline builds (required by Flathub)
  LOTT_ARCHIVE_NAME="lotti-${APP_COMMIT}.tar.xz"
  LOTT_ARCHIVE_PATH="$OUTPUT_DIR/$LOTT_ARCHIVE_NAME"

  if [ ! -f "$LOTT_ARCHIVE_PATH" ]; then
    print_info "Creating archived app source ${LOTT_ARCHIVE_NAME}"
    git -C "$LOTTI_ROOT" archive --format=tar --prefix=lotti/ "$APP_COMMIT" | xz > "$LOTT_ARCHIVE_PATH"
  fi

  LOTT_ARCHIVE_SHA256=$(sha256sum "$LOTT_ARCHIVE_PATH" | awk '{print $1}')

  python3 "$PYTHON_CLI" bundle-app-archive \
    --manifest "$OUT_MANIFEST" \
    --archive "$LOTT_ARCHIVE_NAME" \
    --sha256 "$LOTT_ARCHIVE_SHA256" \
    --output-dir "$OUTPUT_DIR"

  # Ensure sqlite3 plugin adds URL_HASH offline without relying on patch files
  OUT_MANIFEST="$OUT_MANIFEST" PYTHON_CLI="$PYTHON_CLI" python3 - <<'PYTHON_MANIFEST_OPS'
import os
import sys
from pathlib import Path
from textwrap import dedent

cli_path = Path(os.environ['PYTHON_CLI']).resolve()
package_root = cli_path.parent
if str(package_root) not in sys.path:
    sys.path.insert(0, str(package_root))

from manifest import ManifestDocument  # type: ignore

manifest_path = Path(os.environ['OUT_MANIFEST'])
document = ManifestDocument.load(manifest_path)
modules = document.ensure_modules()

sqlite_command = dedent(
    """python3 - <<'PY'
import pathlib

base = pathlib.Path('.pub-cache/hosted/pub.dev')
target = next(base.glob('sqlite3_flutter_libs-*/linux/CMakeLists.txt'), None)
if target is None:
    raise SystemExit('sqlite3_flutter_libs linux/CMakeLists.txt not found')
content = target.read_text()
needle = 'URL_HASH SHA256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18'
if needle not in content:
    url_line = '    URL https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz\\n'
    if url_line not in content:
        raise SystemExit('sqlite3 URL stanza missing; unable to inject URL_HASH')
    line = "    " + needle + "\\n"
    updated = content.replace(url_line, url_line + line, 2)
    if needle not in updated:
        raise SystemExit('sqlite3 URL_HASH injection failed')
    target.write_text(updated)
PY
"""
).strip() + "\n"

cargokit_command = dedent(
    """python3 - <<'PY'
import pathlib

base = pathlib.Path('.pub-cache/hosted/pub.dev')
patched = False
# Try both one and two levels deep as package structures may vary
for pattern in ['*/cargokit/run_build_tool.sh', '*/*/cargokit/run_build_tool.sh']:
    for script in base.glob(pattern):
        text = script.read_text()
        if 'pub get --offline --no-precompile' in text:
            print(f"Already patched: {script}")
            continue
        if 'pub get --no-precompile' not in text:
            continue
        script.write_text(text.replace('pub get --no-precompile', 'pub get --offline --no-precompile'))
        print(f"Patched: {script}")
        patched = True
if not patched:
    print('WARNING: No cargokit scripts found to patch!')
PY
"""
).strip() + "\n"

cargo_config_command = dedent(
    """mkdir -p "$CARGO_HOME" && cat > "$CARGO_HOME/config" <<'CARGO_CFG'
[source.vendored-sources]
directory = "/run/build/lotti/cargo/vendor"

[source.crates-io]
replace-with = "vendored-sources"

[source."https://github.com/knopp/mime_guess"]
git = "https://github.com/knopp/mime_guess"
replace-with = "vendored-sources"
branch = "super_native_extensions"
CARGO_CFG
echo "Configured Cargo to use vendored sources"
"""
).strip() + "\n"

commands_to_add = [
    ("sqlite3_flutter_libs-*/linux/CMakeLists.txt", sqlite_command),
    ("cargokit/run_build_tool.sh", cargokit_command),
    ("setup cargo vendor config", cargo_config_command),
]

modified = False

for module in modules:
    if not isinstance(module, dict) or module.get('name') != 'lotti':
        continue

    commands = module.setdefault('build-commands', [])

    for marker, _ in commands_to_add:
        if marker == "setup cargo vendor config":
            # Special marker - don't filter based on it
            continue
        filtered = [
            value
            for value in commands
            if not (
                isinstance(value, str) and marker in value
            )
        ]
        if len(filtered) != len(commands):
            module['build-commands'] = filtered
            commands = filtered
            modified = True

    for _, command in commands_to_add:
        if command in commands:
            continue
        insert_index = next(
            (
                idx
                for idx, value in enumerate(commands)
                if isinstance(value, str) and 'flutter build linux' in value
            ),
            len(commands),
        )
        commands.insert(insert_index, command)
        modified = True
    break

if modified:
    document.mark_changed()
    document.save()
PYTHON_MANIFEST_OPS

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

# Step 8.5: Check for cargo-sources.json regeneration needs
if [ -f "$OUTPUT_DIR/cargo-sources.json" ]; then
  print_warning "Note: cargo-sources.json was generated from initial pubspec.lock data"
  print_info "If the build fails with cargo version mismatch errors, you may need to:"
  print_info "  1. Run a test build: cd $OUTPUT_DIR && flatpak-builder --force-clean --disable-updates build-dir com.matthiasn.lotti.yml"
  print_info "  2. When it fails, run: ./regenerate_cargo_sources.sh"
  print_info "  3. Rebuild with the updated cargo-sources.json"
  echo ""
  print_info "This two-phase process is needed because cargo dependencies are only known after"
  print_info "the first build populates .pub-cache with the actual Rust plugin Cargo.lock files."
  echo ""
fi

# Final cleanup: Apply critical Flathub compliance fixes
# Using sed as a final pass since some Python operations might not be working properly

# Remove --share=network from finish-args for Flathub compliance
sed -i '/^- --share=network$/d' "$OUT_MANIFEST"
print_info "Removed --share=network from finish-args for Flathub compliance"

# Ensure flutter pub get uses --offline flag
sed -i 's|/flutter pub get$|/flutter pub get --offline|' "$OUT_MANIFEST"
print_info "Added --offline flag to flutter pub get commands"

# Ensure flutter build uses --no-pub flag to skip automatic pub get
sed -i 's|/flutter build linux --release|/flutter build linux --release --no-pub|' "$OUT_MANIFEST"
print_info "Added --no-pub flag to flutter build commands"

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
