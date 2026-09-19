#!/usr/bin/env bash
# Records the App Store App Preview — the listing's video — on an iOS
# simulator.
#
# Drives integration_test/store_preview_test.dart with `flutter drive` and
# records the simulator's screen with `xcrun simctl io recordVideo` while it
# walks. The recorder is not started with the script: a cold build holds the
# simulator on its home screen for minutes. Instead the walk announces itself
# on stdout once the app is up ("LOTTI_PREVIEW_MARK ready <ack-dir>") and
# holds still until this script has the camera rolling and says so by
# touching <ack-dir>/ready.done — the handshake ios.sh uses for its PNGs. The
# walk then prints "LOTTI_PREVIEW_MARK start" and "… end" around the footage
# worth keeping; both are timed against the recorder's first frame, and
# app_preview.sh cuts that slice into the size and codec App Store Connect
# takes, refusing one outside its 15–30 seconds. The walk stands still for a
# second and a half on either side of each mark, which is what absorbs the
# fraction of a second a line takes to get from the device to this loop.
#
# The raw recording is kept next to the preview: when the walk fails, it is
# the footage of how. The walk drives the phone layout, so this is the iPhone
# slot only; the 13" iPad slot (1200x1600) needs a walk of its own.
#
# Apple wants a preview built from footage captured on a device, and nothing
# on the command line records a physical iPhone (`devicectl` can neither
# record nor screenshot). What this produces is the rehearsal and the
# storyboard; the same walk on a phone, captured with QuickTime Player over
# USB, goes through app_preview.sh unchanged.
#
#   FLUTTER                   flutter command (default: fvm flutter)
#   LOTTI_IOS_PREVIEW_DEVICE  simulator name (default: "iPhone 17 Pro Max")
#   LOTTI_PREVIEW_DIR         output directory (default: build/store_preview/ios)
#   LOTTI_PREVIEW_SIZE        App Store Connect size (default: 886x1920)
#   LOTTI_STORE_THEME         dark or light (default: dark)
#   LOTTI_MANUAL_LOCALE       fixture locale (default: en)
#
# Finding, booting and dressing the simulator is ios_simulator_lib.sh, shared
# with ios.sh; LOTTI_STORE_STATUS_TIME is documented there.
set -euo pipefail

FLUTTER=${FLUTTER:-fvm flutter}
DEVICE=${LOTTI_IOS_PREVIEW_DEVICE:-iPhone 17 Pro Max}
OUT=${LOTTI_PREVIEW_DIR:-build/store_preview/ios}
SIZE=${LOTTI_PREVIEW_SIZE:-886x1920}
THEME=${LOTTI_STORE_THEME:-dark}
LOCALE=${LOTTI_MANUAL_LOCALE:-en}

# shellcheck source=tool/store_screenshots/ios_simulator_lib.sh
source "$(dirname "$0")/ios_simulator_lib.sh"

recorder=""
recorder_log=$(mktemp)

# SIGINT is how simctl is told to finalize the file; anything harsher leaves
# a recording without its index.
stop_recorder() {
  if [ -n "$recorder" ] && kill -0 "$recorder" 2>/dev/null; then
    kill -INT "$recorder"
    wait "$recorder" 2>/dev/null || true
  fi
  recorder=""
}

cleanup() {
  stop_recorder
  release_simulators
  rm -f "$recorder_log"
}
trap cleanup EXIT

now() {
  python3 -c 'import time; print("%.3f" % time.time())'
}

seconds_between() {
  python3 -c 'import sys; print("%.3f" % (float(sys.argv[2]) - float(sys.argv[1])))' "$1" "$2"
}

claim_simulator "$DEVICE"
device_out="$OUT/$(slug_for "$DEVICE")"
mkdir -p "$device_out"
raw="$device_out/store_preview_${LOCALE}_${THEME}.mov"
preview="$device_out/store_preview_${LOCALE}_${THEME}.mp4"
# A stale file from an earlier run must not pass for this run's.
rm -f "$raw" "$preview"

# simctl writes "Recording started" once its first frame is in; a recorder
# that never gets there exits instead, and the walk must not run unfilmed.
start_recorder() {
  xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 --force "$raw" \
    2>"$recorder_log" &
  recorder=$!
  local _
  for _ in $(seq 1 600); do
    grep -q 'Recording started' "$recorder_log" 2>/dev/null && break
    if ! kill -0 "$recorder" 2>/dev/null; then
      cat "$recorder_log" >&2
      exit 1
    fi
    sleep 0.05
  done
  if ! grep -q 'Recording started' "$recorder_log" 2>/dev/null; then
    echo "simctl never reported its first frame; not walking unfilmed" >&2
    exit 1
  fi
  started_at=$(now)
}

started_at=""
cut_from=""
cut_to=""
drive_status=""

echo "== store preview: device=$DEVICE locale=$LOCALE theme=$THEME =="
while IFS= read -r line; do
  printf '%s\n' "$line"
  case "$line" in
    'LOTTI_PREVIEW_DRIVE_EXIT '*)
      drive_status="${line#LOTTI_PREVIEW_DRIVE_EXIT }"
      ;;
    *'LOTTI_PREVIEW_MARK '*)
      marker="${line##*LOTTI_PREVIEW_MARK }"
      marker="${marker%$'\r'}"
      case "${marker%% *}" in
        ready)
          start_recorder
          # Only now may the walk begin.
          touch "${marker#* }/ready.done"
          echo "recording $raw"
          ;;
        start) cut_from=$(seconds_between "$started_at" "$(now)") ;;
        end) cut_to=$(seconds_between "$started_at" "$(now)") ;;
      esac
      ;;
  esac
done < <(
  # `|| status=$?`: under `set -e` a failed drive would end this subshell
  # before it could report how it ended.
  status=0
  $FLUTTER drive \
    --driver=test_driver/tutorial_driver.dart \
    --target=integration_test/store_preview_test.dart \
    -d "$SIM_UDID" \
    --dart-define=LOTTI_MANUAL_LOCALE="$LOCALE" \
    --dart-define=LOTTI_STORE_THEME="$THEME" 2>&1 || status=$?
  echo "LOTTI_PREVIEW_DRIVE_EXIT $status"
)
stop_recorder

if [ "$drive_status" != "0" ]; then
  echo "The walk failed (exit ${drive_status:-unknown}); no preview cut." >&2
  [ -f "$raw" ] && echo "What it looked like: $raw" >&2
  exit 1
fi
if [ -z "$cut_from" ] || [ -z "$cut_to" ]; then
  echo "The walk passed without printing both marks; no preview cut." >&2
  exit 1
fi

"$(dirname "$0")/app_preview.sh" "$raw" "$preview" "$SIZE" \
  "$cut_from" "$(seconds_between "$cut_from" "$cut_to")"
echo "Raw recording: $raw"
