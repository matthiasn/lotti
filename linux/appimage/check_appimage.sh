#!/usr/bin/env bash
#
# Check that a Lotti AppImage works on the machine this runs on.
#
# Meant for clean machines and containers that have only a desktop's usual
# libraries (GTK 3, Mesa, ALSA) and none of Lotti's build dependencies. It
#   1. extracts the AppImage (no FUSE needed),
#   2. fails if libmpv, parecord, ffmpeg or a required GStreamer plugin from
#      gstreamer-plugins.txt is missing from it,
#   3. fails if any bundled binary or library has a dependency the host
#      cannot provide,
#   4. starts the app under a virtual X server with a throwaway HOME and
#      fails if it exits within the smoke-test window.
#
# Usage:
#   linux/appimage/check_appimage.sh APPIMAGE [--seconds N] [--no-launch]
#
# Requires: ldd, timeout; for the launch: xvfb-run and dbus-run-session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=linux/appimage/lib.sh
source "$SCRIPT_DIR/lib.sh"

APPIMAGE=""
SECONDS_TO_RUN=30
LAUNCH=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds) SECONDS_TO_RUN="${2:?--seconds needs a number}"; shift 2 ;;
    --no-launch) LAUNCH=false; shift ;;
    -h | --help) sed -n '/^# Usage:/,/^# Requires:/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown argument: $1" ;;
    *) APPIMAGE="$(readlink -f "$1")"; shift ;;
  esac
done
[[ -f "$APPIMAGE" ]] || die "usage: $0 APPIMAGE [--seconds N] [--no-launch]"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

log "Extracting $(basename "$APPIMAGE")"
chmod +x "$APPIMAGE"
(cd "$WORK_DIR" && "$APPIMAGE" --appimage-extract >/dev/null)
APPDIR="$WORK_DIR/squashfs-root"
[[ -x "$APPDIR/AppRun" ]] || die "AppRun missing from the AppImage"

log "Checking the bundle layout"
compgen -G "$APPDIR/usr/lib/libmpv.so.*" >/dev/null || die "libmpv is not bundled"
[[ -x "$APPDIR/usr/lib/lotti/lotti" ]] || die "the Lotti executable is not bundled"
[[ -d "$APPDIR/usr/lib/lotti/data/flutter_assets" ]] || die "Flutter assets are not bundled"
for tool in parecord ffmpeg; do
  [[ -x "$APPDIR/usr/bin/$tool" ]] || die "$tool is not bundled"
done
[[ -x "$APPDIR/usr/lib/gstreamer-1.0/gst-plugin-scanner" ]] || die "gst-plugin-scanner is not bundled"
verify_gst_plugins "$APPDIR/usr/lib/gstreamer-1.0" "$SCRIPT_DIR/gstreamer-plugins.txt"

log "Checking that every library resolves on this host"
missing=0
checked=0
while IFS= read -r -d '' file; do
  is_elf "$file" || continue
  [[ "$(basename "$file")" == "libapp.so" ]] && continue
  checked=$((checked + 1))
  output="$(env -u LD_LIBRARY_PATH ldd "$file" 2>&1 || true)"
  # "not found" covers both missing libraries and symbol version errors
  # ("version `GLIBC_2.38' not found"), which mean the host is older than
  # the build machine.
  while IFS= read -r line; do
    echo "  ${file#"$APPDIR"/}: ${line#"${line%%[![:space:]]*}"}" >&2
    missing=$((missing + 1))
  done < <(grep "not found" <<<"$output" || true)
done < <(find "$APPDIR" -type f -print0)
[[ $missing -eq 0 ]] || die "$missing unresolved dependency problem(s) in $checked ELF files"
echo "  $checked ELF files, all dependencies resolved"

$LAUNCH || exit 0

log "Launching for $SECONDS_TO_RUN seconds"
for tool in xvfb-run dbus-run-session timeout; do
  command -v "$tool" >/dev/null || die "'$tool' is required to launch the app"
done
mkdir -p "$WORK_DIR/home"
LOG_FILE="$WORK_DIR/lotti.log"
set +e
HOME="$WORK_DIR/home" XDG_CACHE_HOME="$WORK_DIR/home/.cache" \
  XDG_CONFIG_HOME="$WORK_DIR/home/.config" XDG_DATA_HOME="$WORK_DIR/home/.local/share" \
  timeout "$SECONDS_TO_RUN" xvfb-run -a -s "-screen 0 1280x800x24" \
  dbus-run-session -- "$APPDIR/AppRun" >"$LOG_FILE" 2>&1
status=$?
set -e

# timeout exits with 124 when it had to stop the app, i.e. the app was still
# running at the end of the window.
if [[ $status -ne 124 ]]; then
  echo "--- app output ---" >&2
  tail -n 200 "$LOG_FILE" >&2
  die "Lotti exited with status $status within $SECONDS_TO_RUN seconds"
fi
echo "--- last lines of app output ---"
tail -n 40 "$LOG_FILE"
log "Lotti was still running after $SECONDS_TO_RUN seconds"
