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

    if [ -n "${PYTHON_CLI:-}" ] && [ -f "$PYTHON_CLI" ]; then
        python3 "$PYTHON_CLI" replace-url-with-path \
            --manifest "$manifest" \
            --identifier "$identifier" \
            --path "$path_value"
    fi
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
: "${USE_OFFLINE_FLUTTER:=true}"      # Rewrite manifest to consume generated Flutter JSON
: "${USE_NESTED_FLUTTER:=false}"      # Prefer nested SDK module under lotti (false = keep top-level flutter-sdk)
: "${USE_OFFLINE_PYTHON:=true}"       # Prefer cached Python artifacts for offline builds
: "${USE_OFFLINE_ARCHIVES:=true}"     # Prefer cached archive/file sources in manifest
: "${USE_OFFLINE_APP_SOURCE:=true}"   # Bundle app source as archive for offline testing
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

SETUP_HELPER="$WORK_DIR/setup-flutter.sh"
cat >"$SETUP_HELPER" <<'EOF'
#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
usage: setup-flutter.sh [-C dir] [flutter pub get args...]
USAGE
}

OPTIND=1
TARGET_DIR="."
while getopts "C:h" opt; do
  case "$opt" in
    C)
      TARGET_DIR="$OPTARG"
      ;;
    h|*)
      usage
      exit 0
      ;;
  esac
done

shift $((OPTIND - 1))
pushd "$TARGET_DIR" >/dev/null

TOOLS_DIR="$PWD/flutter/packages/flutter_tools"
mkdir -p /var/lib/flutter/packages/flutter_tools/.dart_tool
PACKAGE_CONFIG="flutter/packages/flutter_tools/.dart_tool/package_config.json"
if [ -f "$PACKAGE_CONFIG" ]; then
  cp "$PACKAGE_CONFIG" /var/lib/flutter/packages/flutter_tools/.dart_tool/
fi

# If package_config.json wasn't present inside the SDK tree, try a staged copy
if [ ! -f /var/lib/flutter/packages/flutter_tools/.dart_tool/package_config.json ]; then
  if [ -f /run/build/lotti/package_config.json ]; then
    cp /run/build/lotti/package_config.json /var/lib/flutter/packages/flutter_tools/.dart_tool/package_config.json || true
  fi
fi

# Resolve flutter binary robustly
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  for cand in \
    /var/lib/flutter/bin/flutter \
    /app/flutter/bin/flutter \
    "$PWD/flutter/bin/flutter"; do
    if [ -x "$cand" ]; then
      FLUTTER_BIN="$cand"
      break
    fi
  done
fi

if ! "$FLUTTER_BIN" pub get --offline -C "$TOOLS_DIR" "$@"; then
  echo "Offline pub get failed, retrying with network access..." >&2
  "$FLUTTER_BIN" pub get -C "$TOOLS_DIR" "$@"
fi

popd >/dev/null
EOF
chmod +x "$SETUP_HELPER"
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
cp -- rustup-*.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No rustup JSON found"
cp -- package_config.json "$OUTPUT_DIR/" 2>/dev/null || print_warning "No package_config.json found"
cp -- "$WORK_DIR/setup-flutter.sh" "$OUTPUT_DIR/" 2>/dev/null || true

# Collect JSON artifacts from build directories when generated elsewhere
for search_root in . ..; do
  for pattern in \
    '*/.flatpak-builder/*/pubspec-sources.json' \
    '*/.flatpak-builder/*/cargo-sources.json' \
    '*/.flatpak-builder/*/rustup-*.json' \
    '*/.flatpak-builder/*/flutter-sdk-*.json'; do
    while IFS= read -r json; do
      [ -n "${json:-}" ] || continue
      base=$(basename "$json")
      cp -- "$json" "$OUTPUT_DIR/" 2>/dev/null && print_info "Bundled $base" || true
    done < <(find "$search_root" -maxdepth 10 -path "$pattern" -print 2>/dev/null)
  done
done

# Fallback: generate pubspec-sources.json and package_config.json if missing
if [ ! -f "$OUTPUT_DIR/pubspec-sources.json" ]; then
  print_warning "No pubspec-sources.json; generating from pubspec.lock files..."
  APP_LOCK="$WORK_DIR/pubspec.lock"
  TOOLS_LOCK=""
  if [ -d "$WORK_DIR/.flatpak-builder/build" ]; then
    TOOLS_LOCK="$(find "$WORK_DIR/.flatpak-builder/build" -maxdepth 5 -path '*/flutter/packages/flutter_tools/pubspec.lock' -print -quit 2>/dev/null || true)"
  fi

  if [ -z "$TOOLS_LOCK" ]; then
    print_warning "Could not locate flutter_tools pubspec.lock within .flatpak-builder cache"
  fi

  if [ -f "$APP_LOCK" ] && [ -n "$TOOLS_LOCK" ] && [ -f "$TOOLS_LOCK" ]; then
    python3 "$FLATPAK_DIR/flatpak-flutter/pubspec_generator/pubspec_generator.py" \
      "$APP_LOCK,$TOOLS_LOCK" -o "$OUTPUT_DIR/pubspec-sources.json" || print_error "Failed to generate pubspec-sources.json"
    # Also stage the current package_config.json if available to speed offline bootstrap
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
  else
    print_warning "Missing pubspec.lock paths; cannot generate pubspec-sources.json"
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
    cp -- ../flutter-sdk-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../pubspec-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../cargo-sources.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../rustup-*.json "$OUTPUT_DIR/" 2>/dev/null
    cp -- ../package_config.json "$OUTPUT_DIR/" 2>/dev/null
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

  if [ "$USE_OFFLINE_FLUTTER" = "true" ]; then
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

    RUSTUP_JSON=""
    for candidate in "$OUTPUT_DIR"/rustup-*.json; do
      if [ -e "$candidate" ]; then
        RUSTUP_JSON="$(basename "$candidate")"
        break
      fi
    done

    print_info "Adding offline sources: ${FLUTTER_JSON:-none} ${PUBSPEC_JSON:-} ${CARGO_JSON:-} ${RUSTUP_JSON:-}"
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
    if [ -n "$RUSTUP_JSON" ]; then
      PYTHON_OFFLINE_ARGS+=(--rustup "$RUSTUP_JSON")
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
  fi

  if [ "$USE_OFFLINE_PYTHON" = "true" ]; then
    print_info "Ensuring python3-jinja2 module sources use cached artifacts..."

    JINJA_FILENAME="jinja2-3.1.4-py3-none-any.whl"
    JINJA_URL="https://files.pythonhosted.org/packages/31/80/3a54838c3fb461f6fec263ebf3a3a41771bd05190238de3486aae8540c36/jinja2-3.1.4-py3-none-any.whl"
    if [ -f "$OUTPUT_DIR/$JINJA_FILENAME" ]; then
      JINJA_SOURCE="$OUTPUT_DIR/$JINJA_FILENAME"
    else
      JINJA_SOURCE=$(find_cached_source_file "$JINJA_FILENAME" || true)
    fi
    if [ -z "${JINJA_SOURCE:-}" ] && [ "$DOWNLOAD_MISSING_SOURCES" = "true" ]; then
      print_info "Downloading $JINJA_FILENAME from upstream"
      if curl -L --fail -o "$OUTPUT_DIR/$JINJA_FILENAME" "$JINJA_URL"; then
        JINJA_SOURCE="$OUTPUT_DIR/$JINJA_FILENAME"
      else
        print_warning "Failed to download $JINJA_FILENAME; manifest will reference upstream URL"
      fi
    fi
    if [ -n "${JINJA_SOURCE:-}" ]; then
      if [ "$JINJA_SOURCE" != "$OUTPUT_DIR/$JINJA_FILENAME" ]; then
        cp -- "$JINJA_SOURCE" "$OUTPUT_DIR/$JINJA_FILENAME"
      fi
      replace_source_url_with_path "$OUT_MANIFEST" "$JINJA_FILENAME" "$JINJA_FILENAME"
      print_info "Bundled $JINJA_FILENAME from ${JINJA_SOURCE#$LOTTI_ROOT/}"
    else
      print_warning "No local copy of $JINJA_FILENAME available; leaving upstream URL"
    fi

    MARKUPSAFE_FILENAME="MarkupSafe-2.1.5.tar.gz"
    MARKUPSAFE_URL="https://files.pythonhosted.org/packages/87/5b/aae44c6655f3801e81aa3eef09dbbf012431987ba564d7231722f68df02d/MarkupSafe-2.1.5.tar.gz"
    if [ -f "$OUTPUT_DIR/$MARKUPSAFE_FILENAME" ]; then
      MARKUPSAFE_SOURCE="$OUTPUT_DIR/$MARKUPSAFE_FILENAME"
    else
      MARKUPSAFE_SOURCE=$(find_cached_source_file "$MARKUPSAFE_FILENAME" || true)
    fi
    if [ -z "${MARKUPSAFE_SOURCE:-}" ] && [ "$DOWNLOAD_MISSING_SOURCES" = "true" ]; then
      print_info "Downloading $MARKUPSAFE_FILENAME from upstream"
      if curl -L --fail -o "$OUTPUT_DIR/$MARKUPSAFE_FILENAME" "$MARKUPSAFE_URL"; then
        MARKUPSAFE_SOURCE="$OUTPUT_DIR/$MARKUPSAFE_FILENAME"
      else
        print_warning "Failed to download $MARKUPSAFE_FILENAME; manifest will reference upstream URL"
      fi
    fi
    if [ -n "${MARKUPSAFE_SOURCE:-}" ]; then
      if [ "$MARKUPSAFE_SOURCE" != "$OUTPUT_DIR/$MARKUPSAFE_FILENAME" ]; then
        cp -- "$MARKUPSAFE_SOURCE" "$OUTPUT_DIR/$MARKUPSAFE_FILENAME"
      fi
      replace_source_url_with_path "$OUT_MANIFEST" "$MARKUPSAFE_FILENAME" "$MARKUPSAFE_FILENAME"
      print_info "Bundled $MARKUPSAFE_FILENAME from ${MARKUPSAFE_SOURCE#$LOTTI_ROOT/}"
    else
      print_warning "No local copy of $MARKUPSAFE_FILENAME available; leaving upstream URL"
    fi
  fi

  if [ "$USE_OFFLINE_ARCHIVES" = "true" ]; then
    print_info "Bundling cached archive and file sources referenced by manifest..."
    if [ "$DOWNLOAD_MISSING_SOURCES" = "true" ]; then
      python3 "$PYTHON_CLI" bundle-archive-sources \
        --manifest "$OUT_MANIFEST" \
        --output-dir "$OUTPUT_DIR" \
        --download-missing \
        --search-root "$FLATPAK_DIR/.flatpak-builder/downloads" \
        --search-root "$LOTTI_ROOT/.flatpak-builder/downloads" \
        --search-root "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads"
    else
      python3 "$PYTHON_CLI" bundle-archive-sources \
        --manifest "$OUT_MANIFEST" \
        --output-dir "$OUTPUT_DIR" \
        --search-root "$FLATPAK_DIR/.flatpak-builder/downloads" \
        --search-root "$LOTTI_ROOT/.flatpak-builder/downloads" \
        --search-root "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads"
    fi
  fi

  python3 "$PYTHON_CLI" rewrite-flutter-git-url \
    --manifest "$OUT_MANIFEST"

  if [ "$USE_OFFLINE_APP_SOURCE" = "true" ]; then
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
  fi
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
