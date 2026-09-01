#!/usr/bin/env bash
# Records the screen of an Android device or emulator while a command runs.
#
#   tool/screen_recording/android.sh [-s SERIAL] [-o OUT.mp4] -- <command...>
#
# Starts `screenrecord` on the device, runs the command on the host, stops the
# recording when the command exits, pulls the MP4 and prints its path. The
# command's exit status is this script's exit status, so a failed walk still
# leaves a recording of how it failed.
#
# `screenrecord` finalizes its file only on SIGINT or at --time-limit, and the
# limit defaults to 180 s (0 = unlimited exists only since Android 14). The
# script therefore records back-to-back segments of $LOTTI_RECORD_SEGMENT
# seconds for as long as the command runs, interrupts the last one, and
# concatenates the segments losslessly with ffmpeg when there is more than one
# — a segment boundary costs a fraction of a second of footage, which is why
# the segments are as long as the platform allows. Works on a physical phone
# over USB exactly as on an emulator; this is the one mobile target whose
# device capture is scriptable end to end.
#
# `screenrecord` encodes a frame only when the display changes, so a recording
# of a screen that sits still is a valid MP4 with a single frame and no
# duration — not a failed capture.
#
# Android's crash and "isn't responding" dialogs are hidden for the duration
# (the `hide_error_dialogs` global, restored afterwards): an emulator on a
# software GPU trips a System UI ANR under the encoder's load, and the dialog
# would sit over every frame of the recording while the walk underneath
# succeeds. Boot the emulator with `-gpu host` where the host supports it.
#
#   LOTTI_ANDROID_DEVICE   adb serial (default: emulator-5554), overridden by -s
#   LOTTI_RECORD_BITRATE   screenrecord bit rate (default: 8M)
#   LOTTI_RECORD_SEGMENT   seconds per segment (default: 180, the API < 34 cap)
#   ADB                    adb binary (default: from $ANDROID_SDK_ROOT)
set -euo pipefail

SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}
ADB=${ADB:-$SDK/platform-tools/adb}
DEVICE=${LOTTI_ANDROID_DEVICE:-emulator-5554}
BITRATE=${LOTTI_RECORD_BITRATE:-8M}
SEGMENT=${LOTTI_RECORD_SEGMENT:-180}
OUT=""

usage() {
  sed -n '2,20p' "$0" >&2
  exit 64
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s) DEVICE=$2; shift 2 ;;
    -o) OUT=$2; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[ $# -gt 0 ] || usage
OUT=${OUT:-build/screen_recordings/android_$(date +%Y%m%d-%H%M%S).mp4}
mkdir -p "$(dirname "$OUT")"

"$ADB" -s "$DEVICE" get-state >/dev/null 2>&1 || {
  echo "No device '$DEVICE' attached (adb devices):" >&2
  "$ADB" devices >&2
  exit 1
}

remote_dir="/sdcard/lotti-screen-recording-$$"
"$ADB" -s "$DEVICE" shell mkdir -p "$remote_dir"
running=$(mktemp)

previous_dialogs=$("$ADB" -s "$DEVICE" shell settings get global hide_error_dialogs | tr -d '\r')
"$ADB" -s "$DEVICE" shell settings put global hide_error_dialogs 1
restore_dialogs() {
  if [ "$previous_dialogs" = "null" ] || [ -z "$previous_dialogs" ]; then
    "$ADB" -s "$DEVICE" shell settings delete global hide_error_dialogs >/dev/null 2>&1 || true
  else
    "$ADB" -s "$DEVICE" shell settings put global hide_error_dialogs "$previous_dialogs" >/dev/null 2>&1 || true
  fi
}

# One segment after another until the flag file disappears. Each `screenrecord`
# returns when its time limit is reached or when the stop below interrupts it.
# A segment that fails within a couple of seconds is a recorder that cannot
# run at all (an unsupported device, a segment longer than the platform's
# cap), so the loop stops there rather than spinning adb calls for the whole
# command; the segment check after the command reports what was recorded.
record_segments() {
  local i=0 started
  while [ -f "$running" ]; do
    i=$((i + 1))
    started=$(date +%s)
    if ! "$ADB" -s "$DEVICE" shell screenrecord --bit-rate "$BITRATE" \
      --time-limit "$SEGMENT" "$remote_dir/$(printf 'seg_%03d.mp4' "$i")" \
      >/dev/null 2>&1 && [ $(( $(date +%s) - started )) -lt 2 ]; then
      echo "screenrecord failed at once on $DEVICE; recording stopped" >&2
      return
    fi
  done
}
record_segments &
recorder=$!
# The first frame lands once the encoder is up; give it a moment so the
# command's first screen is on the recording.
sleep 2

stop_recording() {
  rm -f "$running"
  "$ADB" -s "$DEVICE" shell 'pid=$(pidof screenrecord) && kill -INT $pid' \
    >/dev/null 2>&1 || true
  wait "$recorder" 2>/dev/null || true
}

cleanup() {
  stop_recording
  restore_dialogs
  "$ADB" -s "$DEVICE" shell rm -rf "$remote_dir" >/dev/null 2>&1 || true
}
trap cleanup EXIT

set +e
"$@"
status=$?
set -e

stop_recording
# screenrecord writes its trailer after the interrupt returns.
sleep 1

segments=$("$ADB" -s "$DEVICE" shell ls "$remote_dir" | tr -d '\r' | sort)
if [ -z "$segments" ]; then
  echo "screenrecord produced no segments on $DEVICE" >&2
  exit 1
fi

local_dir=$(mktemp -d)
for seg in $segments; do
  "$ADB" -s "$DEVICE" pull "$remote_dir/$seg" "$local_dir/$seg" >/dev/null
done

count=$(echo "$segments" | wc -l | tr -d ' ')
if [ "$count" = 1 ]; then
  mv "$local_dir/$segments" "$OUT"
elif command -v ffmpeg >/dev/null; then
  for seg in $segments; do echo "file '$local_dir/$seg'"; done > "$local_dir/list.txt"
  ffmpeg -v error -y -f concat -safe 0 -i "$local_dir/list.txt" -c copy "$OUT"
else
  echo "ffmpeg not found; leaving $count segments in $local_dir" >&2
  exit 1
fi
rm -rf "$local_dir"

echo "Recorded $OUT"
exit "$status"
