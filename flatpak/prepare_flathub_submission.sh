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

python3 - "$WORK_DIR/com.matthiasn.lotti.yml" "$SETUP_HELPER" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
helper = Path(sys.argv[2])
if not manifest_path.exists():
    sys.exit(0)

data = yaml.safe_load(manifest_path.read_text(encoding='utf-8'))
for module in data.get('modules', []):
    name = module.get('name')
    if name == 'flutter-sdk':
        sources = module.setdefault('sources', [])
        if not any(isinstance(src, dict) and src.get('dest-filename') == 'setup-flutter.sh' for src in sources):
            sources.append({
                'type': 'file',
                'path': helper.name,
                'dest': 'flutter/bin',
                'dest-filename': 'setup-flutter.sh',
            })
    if name == 'lotti':
        build_options = module.setdefault('build-options', {})
        env = build_options.setdefault('env', {})
        existing_path = env.get('PATH', '')
        path_entries = [entry for entry in existing_path.split(':') if entry]
        if '/app/flutter/bin' not in path_entries:
            env['PATH'] = '/app/flutter/bin:' + existing_path if existing_path else '/app/flutter/bin'

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY

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
python3 - "$WORK_DIR/com.matthiasn.lotti.yml" "$APP_COMMIT" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
commit = sys.argv[2]

data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') == 'lotti':
        for source in module.get('sources', []):
            if not isinstance(source, dict):
                continue
            url = source.get('url') or ''
            if url in {
                'https://github.com/matthiasn/lotti',
                'git@github.com:matthiasn/lotti'
            }:
                source['commit'] = commit
                source.pop('branch', None)
                if source.get('commit') == 'COMMIT_PLACEHOLDER':
                    source['commit'] = commit

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY

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
  TOOLS_LOCK="$WORK_DIR/.flatpak-builder/build/lotti/flutter/packages/flutter_tools/pubspec.lock"
  if [ -f "$APP_LOCK" ] && [ -f "$TOOLS_LOCK" ]; then
    python3 "$FLATPAK_DIR/flatpak-flutter/pubspec_generator/pubspec_generator.py" \
      "$APP_LOCK,$TOOLS_LOCK" -o "$OUTPUT_DIR/pubspec-sources.json" || print_error "Failed to generate pubspec-sources.json"
    # Also stage the current package_config.json if available to speed offline bootstrap
    PKG_CFG="$WORK_DIR/.flatpak-builder/build/lotti/flutter/packages/flutter_tools/.dart_tool/package_config.json"
    if [ -f "$PKG_CFG" ]; then
      cp -- "$PKG_CFG" "$OUTPUT_DIR/package_config.json" || true
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
python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8'))

for module in data.get('modules', []):
    if module.get('name') == 'lotti':
        build_options = module.setdefault('build-options', {})
        env = build_options.setdefault('env', {})
        existing_path = env.get('PATH', '')
        path_entries = [entry for entry in existing_path.split(':') if entry]
        if '/app/flutter/bin' not in path_entries:
            env['PATH'] = '/app/flutter/bin:' + existing_path if existing_path else '/app/flutter/bin'

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
  # Pin app source to commit
  if [ "$PIN_COMMIT" = "true" ]; then
    APP_COMMIT=$(cd "$LOTTI_ROOT" && git rev-parse HEAD)
    print_info "Pinning app source to commit: $APP_COMMIT"
    python3 - "$OUT_MANIFEST" "$APP_COMMIT" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
commit = sys.argv[2]

data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') == 'lotti':
        for source in module.get('sources', []):
            if not isinstance(source, dict):
                continue
            url = source.get('url') or ''
            if url in {
                'https://github.com/matthiasn/lotti',
                'git@github.com:matthiasn/lotti'
            }:
                source['commit'] = commit
                source.pop('branch', None)
                if source.get('commit') == 'COMMIT_PLACEHOLDER':
                    source['commit'] = commit

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
  fi

if [ "$USE_NESTED_FLUTTER" = "true" ]; then
  # Ensure the Flutter SDK submodule is included under the lotti module so /var/lib/flutter exists
  python3 - "$OUT_MANIFEST" "$OUTPUT_DIR" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])

data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

# Determine available flutter-sdk-*.json files
flutter_jsons = sorted(p.name for p in output_dir.glob('flutter-sdk-*.json'))
if not flutter_jsons:
    # Nothing to do if no offline SDK json exists
    print('WARN no flutter-sdk-*.json in output; cannot include SDK module')
else:
    for module in data.get('modules', []):
        if module.get('name') == 'lotti':
            existing = module.get('modules') or []
            # Ensure all flutter jsons are present (typically one)
            for fj in flutter_jsons:
                if fj not in existing:
                    existing.append(fj)
            module['modules'] = existing
            break

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
fi

  if [ "$USE_OFFLINE_FLUTTER" = "true" ]; then
    FLUTTER_JSON=""
    for candidate in "$OUTPUT_DIR"/flutter-sdk-*.json; do
      if [ -e "$candidate" ]; then
        FLUTTER_JSON="$(basename "$candidate")"
        break
      fi
    done

    # Decide whether it's safe to remove the top-level flutter-sdk module:
    # Only remove it if (a) an offline flutter-sdk-*.json exists in $OUTPUT_DIR
    # AND (b) the lotti module references it via its 'modules' list.
    REMOVE_FLUTTER_SDK=$(python3 - "$OUT_MANIFEST" "$OUTPUT_DIR" <<'PY'
import sys
from pathlib import Path
import yaml
import os, glob

manifest_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

lotti = None
for module in data.get('modules', []):
    if isinstance(module, dict) and module.get('name') == 'lotti':
        lotti = module
        break

present = [p.name for p in output_dir.glob('flutter-sdk-*.json')]
mods = lotti.get('modules', []) if isinstance(lotti, dict) else []
referenced = [name for name in present if name in mods]

print('1' if present and referenced else '0')
PY
)

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

    # If we keep the top-level flutter-sdk (installed at /app/flutter), avoid
    # executing Flutter in this module to prevent arch-mismatch issues on
    # non-x86_64 builders. We'll invoke Flutter from the app module instead.
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') != 'flutter-sdk':
        continue
    cmds = list(module.get('build-commands', []))
    new_cmds = []
    for c in cmds:
        s = str(c)
        # Keep moving the SDK and PATH export; drop any direct flutter invocations here
        if s.startswith('mv flutter ') or s.startswith('export PATH=/app/flutter/bin'):
            new_cmds.append(s)
    # Ensure we at least move the SDK
    if not any(cmd.startswith('mv flutter ') for cmd in new_cmds):
        new_cmds.insert(0, 'mv flutter /app/flutter')
    module['build-commands'] = new_cmds

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY

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

    SETUP_SRC="$SETUP_HELPER_BASENAME"
    print_info "Adding offline sources: ${FLUTTER_JSON:-none} ${PUBSPEC_JSON:-} ${CARGO_JSON:-} ${RUSTUP_JSON:-}"

    if [ "$USE_NESTED_FLUTTER" = "true" ]; then
    awk -v FJ="$FLUTTER_JSON" -v PJ="$PUBSPEC_JSON" -v CJ="$CARGO_JSON" -v RJ="$RUSTUP_JSON" '
      BEGIN { in_lotti=0; inserted=0 }
      /^\s*- name: lotti\s*$/ { in_lotti=1 }
      in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
      {
        print $0
        if (in_lotti && /^\s{4}sources:\s*$/ && !inserted) {
          if (PJ != "") { print "      - " PJ }
          if (CJ != "") { print "      - " CJ }
          if (RJ != "") { print "      - " RJ }
          if (FJ != "") { print "      - type: file\n        path: " FJ }
          inserted=1
        }
      }
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"
    else
    awk -v PJ="$PUBSPEC_JSON" -v CJ="$CARGO_JSON" -v RJ="$RUSTUP_JSON" '
      BEGIN { in_lotti=0; inserted=0 }
      /^\s*- name: lotti\s*$/ { in_lotti=1 }
      in_lotti && /^\s*- name: [^l]/ { in_lotti=0 }
      {
        print $0
        if (in_lotti && /^\s{4}sources:\s*$/ && !inserted) {
          if (PJ != "") { print "      - " PJ }
          if (CJ != "") { print "      - " CJ }
          if (RJ != "") { print "      - " RJ }
          inserted=1
        }
      }
    ' "$OUT_MANIFEST" > "$OUT_MANIFEST.tmp" && mv "$OUT_MANIFEST.tmp" "$OUT_MANIFEST"
    fi

    if [ "$USE_NESTED_FLUTTER" = "true" ]; then
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
    fi

    if [ "${REMOVE_FLUTTER_SDK:-0}" = "1" ]; then
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') == 'lotti':
        # Ensure PATH contains /var/lib/flutter/bin via build-options.append-path and env.PATH
        bo = module.setdefault('build-options', {})
        append = bo.get('append-path', '')
        parts = [p for p in append.split(':') if p]
        if '/var/lib/flutter/bin' not in parts:
            parts.append('/var/lib/flutter/bin')
        bo['append-path'] = ':'.join(parts) if parts else '/var/lib/flutter/bin'
        env = bo.setdefault('env', {})
        env_path = env.get('PATH', '')
        env_parts = [p for p in env_path.split(':') if p]
        if '/var/lib/flutter/bin' not in env_parts:
            env_parts.insert(0, '/var/lib/flutter/bin')
        env['PATH'] = ':'.join(env_parts)

        commands = module.get('build-commands', [])
        # Use our local helper and run from /var/lib so ./flutter/... paths resolve when present
        insert_command = 'bash setup-flutter.sh -C /var/lib'
        if insert_command not in commands:
            for idx, command in enumerate(commands):
                if isinstance(command, str) and 'flutter ' in command:
                    commands.insert(idx, insert_command)
                    break
            else:
                commands.insert(0, insert_command)
        module['build-commands'] = commands

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
    else
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') == 'lotti':
        # Ensure PATH contains /app/flutter/bin via build-options.append-path and env.PATH
        bo = module.setdefault('build-options', {})
        append = bo.get('append-path', '')
        parts = [p for p in append.split(':') if p]
        if '/app/flutter/bin' not in parts:
            parts.append('/app/flutter/bin')
        bo['append-path'] = ':'.join(parts) if parts else '/app/flutter/bin'
        env = bo.setdefault('env', {})
        env_path = env.get('PATH', '')
        env_parts = [p for p in env_path.split(':') if p]
        if '/app/flutter/bin' not in env_parts:
            env_parts.insert(0, '/app/flutter/bin')
        env['PATH'] = ':'.join(env_parts)

        commands = module.get('build-commands', [])
        # Run helper from /app so ./flutter/... paths resolve to /app/flutter when present
        insert_command = 'bash setup-flutter.sh -C /app'
        if insert_command not in commands:
            for idx, command in enumerate(commands):
                if isinstance(command, str) and 'flutter ' in command:
                    commands.insert(idx, insert_command)
                    break
            else:
                commands.insert(0, insert_command)
        module['build-commands'] = commands

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
    fi

    # Normalize cp source for Flutter SDK with a runtime fallback (handles both layouts)
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') != 'lotti':
        continue
    cmds = module.get('build-commands', [])
    new_cmds = []
    for c in cmds:
        s = str(c)
        if 'cp -r ' in s and '/run/build/lotti/flutter_sdk' in s:
            dst = '/run/build/lotti/flutter_sdk'
            fallback = (
                'if [ -d /var/lib/flutter ]; then cp -r /var/lib/flutter ' + dst +
                '; elif [ -d /app/flutter ]; then cp -r /app/flutter ' + dst +
                '; else echo "No Flutter SDK found at /var/lib/flutter or /app/flutter"; exit 1; fi'
            )
            new_cmds.append(fallback)
            continue
        new_cmds.append(s)
    module['build-commands'] = new_cmds

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY

    # Prefer local robust helper with offline+online fallback; add it to lotti sources
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') != 'lotti':
        continue

    # Ensure setup-flutter.sh is available as a file source in lotti
    sources = module.setdefault('sources', [])
    has_helper = False
    for src in sources:
        if isinstance(src, dict) and src.get('type') == 'file' and src.get('path') == 'setup-flutter.sh':
            has_helper = True
            break
    if not has_helper:
        sources.append({'type': 'file', 'path': 'setup-flutter.sh'})

    # Ensure helper call targets our local helper and correct CWD for nested SDK
    cmds = module.get('build-commands', [])
    replaced = []
    for cmd in cmds:
        if isinstance(cmd, str) and 'setup-flutter.sh' in cmd:
            replaced.append('bash setup-flutter.sh -C /var/lib')
        else:
            replaced.append(cmd)
    if not any(isinstance(c, str) and c.strip().startswith('bash setup-flutter.sh -C /var/lib') for c in replaced):
        replaced.insert(1, 'bash setup-flutter.sh -C /var/lib')
    module['build-commands'] = replaced

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
    else
    python3 - "$OUT_MANIFEST" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') != 'lotti':
        continue

    # Ensure setup-flutter.sh is available as a file source in lotti
    sources = module.setdefault('sources', [])
    has_helper = False
    for src in sources:
        if isinstance(src, dict) and src.get('type') == 'file' and src.get('path') == 'setup-flutter.sh':
            has_helper = True
            break
    if not has_helper:
        sources.append({'type': 'file', 'path': 'setup-flutter.sh'})

    # Ensure helper call targets our local helper and correct CWD for top-level SDK
    cmds = module.get('build-commands', [])
    replaced = []
    for cmd in cmds:
        if isinstance(cmd, str) and 'setup-flutter.sh' in cmd:
            replaced.append('bash setup-flutter.sh -C /app')
        else:
            replaced.append(cmd)
    if not any(isinstance(c, str) and c.strip().startswith('bash setup-flutter.sh -C /app') for c in replaced):
        replaced.insert(1, 'bash setup-flutter.sh -C /app')
    module['build-commands'] = replaced

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
PY
    fi

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

        python3 - "$OUT_MANIFEST" "$FLUTTER_ARCHIVE_BASENAME" "$FLUTTER_ARCHIVE_SHA256" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
archive_name = sys.argv[2]
archive_sha = sys.argv[3]

data = yaml.safe_load(manifest_path.read_text(encoding='utf-8')) or {}

for module in data.get('modules', []):
    if module.get('name') == 'flutter-sdk':
        for source in module.setdefault('sources', []):
            if isinstance(source, dict) and source.get('type') == 'git':
                source['type'] = 'archive'
                source['path'] = archive_name
                source['sha256'] = archive_sha
                source.pop('url', None)
                source.pop('branch', None)
                source.pop('tag', None)
    elif module.get('name') == 'lotti':
        filtered = []
        for source in module.get('sources', []):
            if isinstance(source, dict) and source.get('type') == 'git' and source.get('dest') == 'flutter':
                continue
            filtered.append(source)
        module['sources'] = filtered

manifest_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding='utf-8')
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
    python3 - "$OUT_MANIFEST" "$OUTPUT_DIR" "$DOWNLOAD_MISSING_SOURCES" \
      "$FLATPAK_DIR/.flatpak-builder/downloads" \
      "$LOTTI_ROOT/.flatpak-builder/downloads" \
      "$(dirname "$LOTTI_ROOT")/.flatpak-builder/downloads" <<'PY'
import os
import sys
from pathlib import Path
import shutil
import urllib.request
import yaml

manifest_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
download_flag = sys.argv[3].lower() in {'1', 'true', 'yes'}
search_roots = [Path(p) for p in sys.argv[4:] if p and Path(p).exists()]

if not manifest_path.exists():
    sys.exit(0)

def ensure_local(filename: str, source_url: str):
    candidate = output_dir / filename
    if candidate.exists():
        return candidate

    for root in search_roots:
        for dirpath, _, filenames in os.walk(root):
            if filename in filenames:
                candidate = Path(dirpath) / filename
                dest = output_dir / filename
                dest.parent.mkdir(parents=True, exist_ok=True)
                if candidate.resolve() != dest.resolve():
                    shutil.copy2(candidate, dest)
                return dest

    if not download_flag:
        return None

    dest = output_dir / filename
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(source_url) as response, open(dest, 'wb') as handle:
            shutil.copyfileobj(response, handle)
        print(f"DOWNLOAD {filename} {source_url}")
        return dest
    except Exception as exc:
        print(f"ERROR {filename} {exc}")
        if dest.exists():
            dest.unlink(missing_ok=True)
        return None

with open(manifest_path, encoding='utf-8') as handle:
    manifest = yaml.safe_load(handle)

modified = False
for module in manifest.get('modules', []):
    if not isinstance(module, dict):
        continue

    sources = module.get('sources')
    if not isinstance(sources, list):
        continue

    for source in sources:
        if not isinstance(source, dict):
            continue

        source_type = source.get('type')
        if source_type not in {'archive', 'file'}:
            continue
        url = source.get('url')
        if not url:
            continue
        filename = os.path.basename(url)
        local_path = ensure_local(filename, url)
        if local_path is None:
            print(f"MISSING {filename} {url}")
            continue
        source['path'] = filename
        source.pop('url', None)
        modified = True
        print(f"BUNDLE {filename}")

if modified:
    manifest_path.write_text(yaml.safe_dump(manifest, sort_keys=False), encoding='utf-8')
PY
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

    python3 - "$OUT_MANIFEST" "$LOTT_ARCHIVE_NAME" "$LOTT_ARCHIVE_SHA256" "$OUTPUT_DIR" <<'PY'
import sys
from pathlib import Path
import yaml

manifest_path = Path(sys.argv[1])
archive_name = sys.argv[2]
archive_sha = sys.argv[3]
output_dir = Path(sys.argv[4])

if not manifest_path.exists():
    sys.exit(0)

manifest = yaml.safe_load(manifest_path.read_text()) or {}

# Detect offline flutter jsons available in output dir
extra_modules = [candidate.name for candidate in sorted(output_dir.glob('flutter-sdk-*.json'))]

# Only remove top-level flutter-sdk if we actually have nested offline SDK jsons to use
if extra_modules and isinstance(manifest.get('modules'), list):
    manifest['modules'] = [
        module for module in manifest['modules']
        if not (isinstance(module, dict) and module.get('name') == 'flutter-sdk')
    ]

for module in manifest.get('modules', []):
    if module.get('name') != 'lotti':
        continue

    extra_sources = []
    # Include JSON source lists as bare strings so flatpak-builder loads them
    for candidate in (
        output_dir / 'pubspec-sources.json',
        output_dir / 'cargo-sources.json',
    ):
        if candidate.exists():
            extra_sources.append(candidate.name)
    for candidate in sorted(output_dir.glob('rustup-*.json')):
        extra_sources.append(candidate.name)

    # Ensure our local helper is available in the lotti build dir
    helper = output_dir / 'setup-flutter.sh'
    if helper.exists():
        extra_sources.append({'type': 'file', 'path': helper.name})

    module['sources'] = [{
        'type': 'archive',
        'path': archive_name,
        'sha256': archive_sha,
        'strip-components': 1,
    }] + extra_sources

    # Attach nested flutter-sdk jsons only when present; otherwise keep top-level module
    if extra_modules:
        module['modules'] = extra_modules
    break

manifest_path.write_text(yaml.safe_dump(manifest, sort_keys=False), encoding='utf-8')
PY
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
