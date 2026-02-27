#!/usr/bin/env bash
# Builds a combined sqlite3 + sqlite-vec shared library for tests.
#
# Usage:
#   ./scripts/build_test_sqlite_vec.sh <sqlite_url> <expected_sha256> <amalgamation_name>
#
# Example:
#   ./scripts/build_test_sqlite_vec.sh \
#     https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip \
#     77823cb110929c2bcb0f5d48e4833b5c59a8a6e40cdea3936b99e199dbbe5784 \
#     sqlite-amalgamation-3460100

set -euo pipefail

SQLITE_URL="$1"
EXPECTED_SHA256="$2"
SQLITE_AMALGAMATION="$3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/packages/sqlite_vec"
VEC_SOURCE="$OUTPUT_DIR/src/sqlite-vec.c"

echo "Building test sqlite3+vec library..."

# Download sqlite3 amalgamation into a temp directory.
SQLITE3_DIR=$(mktemp -d)
trap 'rm -rf "$SQLITE3_DIR"' EXIT

curl -fsL "$SQLITE_URL" -o "$SQLITE3_DIR/sqlite3.zip"

# Verify SHA256 — use sha256sum if available, fall back to shasum (macOS).
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA256=$(sha256sum "$SQLITE3_DIR/sqlite3.zip" | cut -d' ' -f1)
else
  ACTUAL_SHA256=$(shasum -a 256 "$SQLITE3_DIR/sqlite3.zip" | cut -d' ' -f1)
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "ERROR: SHA256 mismatch for $SQLITE_AMALGAMATION.zip" >&2
  echo "  Expected: $EXPECTED_SHA256" >&2
  echo "  Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

unzip -q -o "$SQLITE3_DIR/sqlite3.zip" -d "$SQLITE3_DIR"

# Detect platform-specific flags.
NEON_FLAG=""
AVX_FLAG=""
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  NEON_FLAG="-DSQLITE_VEC_ENABLE_NEON -flax-vector-conversions"
# On x86_64 we intentionally skip AVX — scalar fallback is sufficient and
# avoids illegal-instruction crashes on CI runners without AVX support.
fi

if [ "$(uname -s)" = "Darwin" ]; then
  EXT="dylib"
  LINK_FLAG="-dynamiclib"
else
  EXT="so"
  LINK_FLAG="-shared"
fi

OUTPUT="$OUTPUT_DIR/test_sqlite3_with_vec.$EXT"

# shellcheck disable=SC2086
cc $LINK_FLAG -O3 -fPIC \
  $NEON_FLAG $AVX_FLAG \
  -DSQLITE_ENABLE_FTS5 \
  -I"$SQLITE3_DIR/$SQLITE_AMALGAMATION/" \
  "$SQLITE3_DIR/$SQLITE_AMALGAMATION/sqlite3.c" \
  "$VEC_SOURCE" \
  -lm \
  -o "$OUTPUT"

echo "Built $OUTPUT"
