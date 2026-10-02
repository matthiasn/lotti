#!/usr/bin/env bash
#
# Package the Flutter Linux release bundle as an AppImage.
#
# Run after `flutter build linux --release`. The script
#   1. lays out an AppDir: the untouched Flutter bundle in usr/lib/lotti,
#      desktop entry, icons, metainfo and AppRun,
#   2. copies every shared library the bundle needs into usr/lib, following
#      DT_NEEDED from object to object and stopping at the libraries the
#      host must provide (see excludelist),
#   3. adds libmpv (media_kit dlopen()s it, so ldd cannot see it), the
#      GStreamer plugins from gstreamer-plugins.txt, and the `parecord` and
#      `ffmpeg` executables that audio recording runs,
#   4. rewrites RUNPATHs so all of it is found inside the AppImage,
#   5. checks that every library resolves to the right place, and
#   6. packs the AppDir with a pinned, checksum-verified appimagetool and
#      AppImage runtime.
#
# The AppImage runs on distributions whose glibc is at least as new as the
# build machine's, so build on the oldest distribution you want to support
# (CI uses Ubuntu 22.04).
#
# Usage:
#   linux/appimage/build_appimage.sh [--bundle DIR] [--output DIR]
#                                    [--version VERSION]
#
# Environment:
#   APPIMAGETOOL          appimagetool to use instead of the pinned download
#   APPIMAGE_RUNTIME      AppImage runtime to use instead of the pinned download
#   APPIMAGETOOL_URL      where to download the pinned appimagetool from
#   APPIMAGE_RUNTIME_URL  where to download the pinned runtime from
#
# Requires: ldd, patchelf, pkg-config, sha256sum, gstreamer development
# files, libmpv, parecord, ffmpeg, and curl unless both downloads are
# replaced through the environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_ID="com.matthiasn.lotti"
# shellcheck source=linux/appimage/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  sed -n '/^# Usage:/,/^# Requires:/p' "$0" | sed 's/^# \{0,1\}//'
}

case "$(uname -m)" in
  x86_64) ARCH="x86_64" FLUTTER_ARCH="x64" ;;
  aarch64) ARCH="aarch64" FLUTTER_ARCH="arm64" ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

# --- Pinned upstream tools ------------------------------------------------------

# appimagetool packs the AppDir, and the runtime it prepends is the first
# thing users execute. Both come from tagged upstream releases and must match
# these hashes; the `continuous` builds are deliberately not used. To update,
# pick new tags, download the assets, run `sha256sum`, and change the tags
# and hashes together.
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGE_RUNTIME_VERSION="20251108"
declare -A APPIMAGETOOL_SHA256=(
  [x86_64]="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
  [aarch64]="f0837e7448a0c1e4e650a93bb3e85802546e60654ef287576f46c71c126a9158"
)
declare -A APPIMAGE_RUNTIME_SHA256=(
  [x86_64]="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"
  [aarch64]="00cbdfcf917cc6c0ff6d3347d59e0ca1f7f45a6df1a428a0d6d8a78664d87444"
)

BUNDLE_DIR="$PROJECT_ROOT/build/linux/$FLUTTER_ARCH/release/bundle"
OUTPUT_DIR="$PROJECT_ROOT/build/appimage"
VERSION="$(sed -n 's/^version: *\([^+]*\).*/\1/p' "$PROJECT_ROOT/pubspec.yaml")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE_DIR="$(cd "${2:?--bundle needs a directory}" && pwd)"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?--output needs a directory}"; shift 2 ;;
    --version) VERSION="${2:?--version needs a value}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

[[ -x "$BUNDLE_DIR/lotti" ]] ||
  die "no Flutter bundle at $BUNDLE_DIR; run 'flutter build linux --release' first"
[[ -n "$VERSION" ]] || die "could not read the version from pubspec.yaml"
for tool in ldd patchelf pkg-config parecord ffmpeg sha256sum; do
  command -v "$tool" >/dev/null || die "'$tool' is required but not installed"
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
APPDIR="$OUTPUT_DIR/Lotti.AppDir"
APP_LIB_DIR="$APPDIR/usr/lib"
APP_BIN_DIR="$APPDIR/usr/bin"
APP_BUNDLE_DIR="$APP_LIB_DIR/lotti"
APP_GST_DIR="$APP_LIB_DIR/gstreamer-1.0"
APPIMAGE="$OUTPUT_DIR/Lotti-$VERSION-$ARCH.AppImage"

# --- Exclusions -------------------------------------------------------------

EXCLUDE_PATTERNS=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -n "$line" ]] && EXCLUDE_PATTERNS+=("$line")
done <"$SCRIPT_DIR/excludelist"

# True for a library the host provides. Only the patterns decide: what a
# host library itself links is never looked at, so it is host-provided
# unless a bundled object links it directly (see bundle_dependencies).
is_excluded() {
  local name="$1" pattern
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    # shellcheck disable=SC2053 # $pattern is a glob on purpose
    [[ "$name" == $pattern ]] && return 0
  done
  return 1
}

# --- Dependency collection ----------------------------------------------------

# Prints "name path" for every library in the given ELF file's dependency
# tree, resolved the way the dynamic linker resolves them for that file on
# this machine; "name not" when one is missing.
resolved_libraries() {
  env -u LD_LIBRARY_PATH ldd "$1" | awk '/=>/ { print $1, $3 }'
}

# Copies into usr/lib every library the given ELF files need, following
# DT_NEEDED from object to object. A host-provided library (excludelist) is
# left out together with everything only it pulls in: the host copy resolves
# its own dependencies on the host, and a bundled copy of one of those would
# at best go unused and at worst be loaded first and shadow the host's. A
# library that a bundled object links directly is always bundled, even when
# a host library links it too, because its name can differ between
# distributions: Ubuntu's libjpeg.so.8 is libjpeg.so.62 on Debian and Fedora.
bundle_dependencies() {
  local -a queue=("$@")
  local -A resolved
  local elf name path
  while [[ ${#queue[@]} -gt 0 ]]; do
    elf="${queue[0]}"
    queue=("${queue[@]:1}")
    resolved=()
    while read -r name path; do
      resolved[$name]="$path"
    done < <(resolved_libraries "$elf")
    while read -r name; do
      is_excluded "$name" && continue
      path="${resolved[$name]:-not}"
      [[ "$path" == "not" ]] && die "$(basename "$elf") needs $name, which is not installed"
      [[ "$path" == "$APPDIR"/* ]] && continue
      [[ -e "$APP_LIB_DIR/$name" ]] && continue
      cp -L "$path" "$APP_LIB_DIR/$name"
      chmod 0644 "$APP_LIB_DIR/$name"
      queue+=("$APP_LIB_DIR/$name")
    done < <(patchelf --print-needed "$elf")
  done
}

# Finds the installed libmpv. Returns "<path> <soname>".
find_libmpv() {
  local dev_lib real soname
  dev_lib="$(pkg-config --variable=libdir mpv 2>/dev/null)/libmpv.so"
  [[ -e "$dev_lib" ]] || die "libmpv is not installed (install libmpv-dev)"
  real="$(readlink -f "$dev_lib")"
  soname="$(patchelf --print-soname "$real")"
  echo "$real $soname"
}

# Downloads URL to DEST unless a copy with the expected SHA-256 is already
# there, and fails if what is there afterwards does not match.
fetch_pinned() {
  local url="$1" dest="$2" sha256="$3"
  if [[ ! -e "$dest" ]] || ! sha256_matches "$dest" "$sha256"; then
    command -v curl >/dev/null || die "'curl' is required to download $(basename "$dest")"
    log "Downloading $(basename "$dest")"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL --retry 3 -o "$dest" "$url"
  fi
  sha256_matches "$dest" "$sha256" ||
    die "$(basename "$dest") does not match its pinned SHA-256 (expected $sha256, got $(sha256_of "$dest"))"
}

sha256_of() {
  sha256sum "$1" | cut -d' ' -f1
}

sha256_matches() {
  [[ "$(sha256_of "$1")" == "$2" ]]
}

# --- AppDir layout ----------------------------------------------------------

log "Creating AppDir for Lotti $VERSION ($ARCH)"
rm -rf "$APPDIR" "$APPIMAGE"
mkdir -p "$APP_BIN_DIR" "$APP_GST_DIR" "$APP_BUNDLE_DIR" \
  "$APPDIR/usr/share/applications" "$APPDIR/usr/share/metainfo"
cp -a "$BUNDLE_DIR/." "$APP_BUNDLE_DIR/"

install -m 0755 "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
sed "/^Version=/a X-AppImage-Version=$VERSION" \
  "$PROJECT_ROOT/linux/$APP_ID.desktop" >"$APPDIR/usr/share/applications/$APP_ID.desktop"
ln -s "usr/share/applications/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp "$PROJECT_ROOT/flatpak/$APP_ID.metainfo.xml" "$APPDIR/usr/share/metainfo/$APP_ID.metainfo.xml"
for size in 16 32 48 64 128 256 512; do
  install -D -m 0644 "$PROJECT_ROOT/flatpak/app_icon_$size.png" \
    "$APPDIR/usr/share/icons/hicolor/${size}x$size/apps/$APP_ID.png"
done
ln -s "usr/share/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

# --- Runtime pieces ldd cannot see -------------------------------------------

log "Adding libmpv"
read -r LIBMPV_PATH LIBMPV_SONAME < <(find_libmpv) || true
[[ -n "${LIBMPV_SONAME:-}" ]] || die "could not locate libmpv"
cp -L "$LIBMPV_PATH" "$APP_LIB_DIR/$LIBMPV_SONAME"

log "Adding GStreamer plugins"
GST_SYSTEM_DIR="$(pkg-config --variable=pluginsdir gstreamer-1.0)"
# Debian and Ubuntu install gst-plugin-scanner under the multiarch libdir
# while their .pc file still reports upstream's libexec location, which is
# where Fedora really keeps it. Try the .pc answer, then the Debian layout.
GST_LIBDIR="$(pkg-config --variable=libdir gstreamer-1.0)"
GST_SCANNER=""
for dir in "$(pkg-config --variable=pluginscannerdir gstreamer-1.0)" \
  "$GST_LIBDIR/gstreamer1.0/gstreamer-1.0" "$GST_LIBDIR/gstreamer-1.0"; do
  if [[ -x "$dir/gst-plugin-scanner" ]]; then
    GST_SCANNER="$dir/gst-plugin-scanner"
    break
  fi
done
[[ -n "$GST_SCANNER" ]] ||
  die "gst-plugin-scanner not found under $GST_LIBDIR or $(pkg-config --variable=pluginscannerdir gstreamer-1.0)"
cp -L "$GST_SCANNER" "$APP_GST_DIR/gst-plugin-scanner"
while read -r kind name; do
  plugin="$GST_SYSTEM_DIR/libgst$name.so"
  if [[ -e "$plugin" ]]; then
    cp -L "$plugin" "$APP_GST_DIR/"
  elif [[ "$kind" == optional ]]; then
    echo "warning: optional GStreamer plugin '$name' not found, skipping" >&2
  else
    die "GStreamer plugin '$name' not found in $GST_SYSTEM_DIR"
  fi
done < <(gst_plugin_list "$SCRIPT_DIR/gstreamer-plugins.txt")
verify_gst_plugins "$APP_GST_DIR" "$SCRIPT_DIR/gstreamer-plugins.txt"

log "Adding parecord and ffmpeg"
for tool in parecord ffmpeg; do
  cp -L "$(command -v "$tool")" "$APP_BIN_DIR/$tool"
  chmod 0755 "$APP_BIN_DIR/$tool"
done

# --- Shared libraries ----------------------------------------------------------

log "Collecting shared libraries"
mapfile -t ROOTS < <(
  find "$APP_BUNDLE_DIR" "$APP_BIN_DIR" "$APP_GST_DIR" -type f ! -name libapp.so
  echo "$APP_LIB_DIR/$LIBMPV_SONAME"
)
ELF_ROOTS=()
for file in "${ROOTS[@]}"; do
  is_elf "$file" && ELF_ROOTS+=("$file")
done
bundle_dependencies "${ELF_ROOTS[@]}"

# Every directory's binaries look for libraries next to themselves first,
# then in usr/lib. libapp.so is the Dart AOT snapshot and has no
# dependencies; it is left untouched.
log "Rewriting RUNPATHs"
set_runpath() {
  local runpath="$1" file
  shift
  for file in "$@"; do
    is_elf "$file" || continue
    [[ "$(basename "$file")" == "libapp.so" ]] && continue
    patchelf --set-rpath "$runpath" "$file"
  done
}
# shellcheck disable=SC2016 # $ORIGIN is expanded by the dynamic linker
{
  set_runpath '$ORIGIN/lib:$ORIGIN/..' "$APP_BUNDLE_DIR/lotti"
  set_runpath '$ORIGIN:$ORIGIN/../..' "$APP_BUNDLE_DIR"/lib/*
  set_runpath '$ORIGIN' "$APP_LIB_DIR"/*.so*
  set_runpath '$ORIGIN/..' "$APP_GST_DIR"/*
  set_runpath '$ORIGIN/../lib' "$APP_BIN_DIR"/*
}

# --- Verification ---------------------------------------------------------------

# Nothing may be missing, and every direct dependency of a bundled object
# that is not host-provided must resolve to the copy inside the AppDir. The
# second check catches a wrong RUNPATH, which would otherwise go unnoticed on
# the build machine because the system copy is installed there too. What a
# host library pulls in on its own is the host's business and not checked.
log "Verifying library resolution"
problems=0
while IFS= read -r -d '' file; do
  is_elf "$file" || continue
  [[ "$(basename "$file")" == "libapp.so" ]] && continue
  declare -A resolved=()
  while read -r name path; do
    resolved[$name]="$path"
    if [[ "$path" == "not" ]]; then
      echo "  $file: $name not found" >&2
      problems=$((problems + 1))
    fi
  done < <(resolved_libraries "$file")
  while read -r name; do
    is_excluded "$name" && continue
    [[ "${resolved[$name]:-}" == "$APPDIR"/* ]] && continue
    echo "  $file: $name resolves to ${resolved[$name]:-nothing} instead of the bundled copy" >&2
    problems=$((problems + 1))
  done < <(patchelf --print-needed "$file")
done < <(find "$APPDIR" -type f -print0)
[[ $problems -eq 0 ]] || die "$problems library resolution problem(s)"

# --- Packing ------------------------------------------------------------------

TOOLS_DIR="$OUTPUT_DIR/tools"
if [[ -z "${APPIMAGETOOL:-}" ]]; then
  APPIMAGETOOL="$TOOLS_DIR/appimagetool-$APPIMAGETOOL_VERSION-$ARCH.AppImage"
  fetch_pinned \
    "${APPIMAGETOOL_URL:-https://github.com/AppImage/appimagetool/releases/download/$APPIMAGETOOL_VERSION/appimagetool-$ARCH.AppImage}" \
    "$APPIMAGETOOL" "${APPIMAGETOOL_SHA256[$ARCH]}"
  chmod +x "$APPIMAGETOOL"
fi
if [[ -z "${APPIMAGE_RUNTIME:-}" ]]; then
  APPIMAGE_RUNTIME="$TOOLS_DIR/runtime-$APPIMAGE_RUNTIME_VERSION-$ARCH"
  fetch_pinned \
    "${APPIMAGE_RUNTIME_URL:-https://github.com/AppImage/type2-runtime/releases/download/$APPIMAGE_RUNTIME_VERSION/runtime-$ARCH}" \
    "$APPIMAGE_RUNTIME" "${APPIMAGE_RUNTIME_SHA256[$ARCH]}"
fi

log "Packing $(basename "$APPIMAGE")"
# Extract-and-run lets appimagetool (itself an AppImage) work without FUSE,
# e.g. in containers. --runtime-file keeps it from downloading a runtime of
# its own.
APPIMAGE_EXTRACT_AND_RUN=1 ARCH="$ARCH" "$APPIMAGETOOL" --no-appstream \
  --runtime-file "$APPIMAGE_RUNTIME" "$APPDIR" "$APPIMAGE"
(cd "$OUTPUT_DIR" && sha256sum "$(basename "$APPIMAGE")" >"$(basename "$APPIMAGE").sha256")

log "Done: $APPIMAGE ($(du -h "$APPIMAGE" | cut -f1))"
