#!/usr/bin/env bash
# Captures the App Store listing screenshots on iOS simulators.
#
# Drives integration_test/store_screenshots_test.dart with `flutter drive`
# against each simulator in $LOTTI_IOS_DEVICES (booting the ones that are not
# running), once per theme, and collects the PNGs the driver writes into
# $LOTTI_SCREENSHOT_DIR/<device-slug>/.
#
# No window pinning is needed here, unlike the Android script: the simulators
# render at their device's native size, and Apple's listing sizes *are* device
# sizes — the 6.9" iPhone slot takes 1320x2868 (iPhone 17 Pro Max) and the 13"
# iPad slot takes 2064x2752 (iPad Pro 13-inch). The status bar is overridden
# to Apple's marketing convention (9:41, full battery, full signal) for the
# run and cleared afterwards. It shows up because this script, not the
# device, takes the PNGs: the device-side plugin renders the Flutter view
# alone, so the test announces each capture point on stdout
# ("LOTTI_STORE_CAPTURE <name> <ack-dir>") and holds the screen until this
# script has taken the whole screen with `simctl io screenshot`, flattened it
# to opaque RGB with strip_alpha.py (App Store Connect rejects an alpha
# channel) and acknowledged by touching <ack-dir>/<name>.done — a directory
# inside the app's sandbox, which on a simulator is a plain host directory.
# LOTTI_SIMULATOR_UDID tells the driver to leave the device-side bytes
# unwritten.
#
#   FLUTTER               flutter command (default: fvm flutter)
#   LOTTI_IOS_DEVICES     simulator names, ';'-separated
#                         (default: "iPhone 17 Pro Max;iPad Pro 13-inch (M5)")
#   LOTTI_SCREENSHOT_DIR  output directory (default: build/store_screenshots/ios)
#   LOTTI_STORE_THEMES    space-separated themes (default: "dark light")
#   LOTTI_MANUAL_LOCALE   fixture locale (default: en)
#   LOTTI_STORE_STATUS_TIME  status bar clock (default: 9:41)
set -euo pipefail

FLUTTER=${FLUTTER:-fvm flutter}
DEVICES=${LOTTI_IOS_DEVICES:-iPhone 17 Pro Max;iPad Pro 13-inch (M5)}
OUT=${LOTTI_SCREENSHOT_DIR:-build/store_screenshots/ios}
THEMES=${LOTTI_STORE_THEMES:-dark light}
LOCALE=${LOTTI_MANUAL_LOCALE:-en}
STATUS_TIME=${LOTTI_STORE_STATUS_TIME:-9:41}

# "<udid> <state>" of the available simulator called $1: one already booted
# first, else the one on the newest runtime, so two runs land on the same
# iOS version when Xcode ships the same device under several. Prints nothing
# when no simulator carries that name.
device_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
name = sys.argv[1]
def version(runtime):
    return tuple(int(n) for n in re.findall(r"\d+", runtime.split(".")[-1]))
devices = [(version(runtime), d)
           for runtime, listed in json.load(sys.stdin)["devices"].items()
           for d in listed if d["name"] == name]
devices.sort(key=lambda item: (item[1]["state"] != "Booted", tuple(-n for n in item[0])))
if devices:
    print(devices[0][1]["udid"], devices[0][1]["state"])
' "$1"
}

slug_for() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_|_$//g'
}

booted_here=()
overridden_here=()
cleanup() {
  # Every status bar this run dressed is cleared, including on simulators
  # that were already running — an early exit must not leave one at 9:41.
  for udid in "${overridden_here[@]:-}"; do
    [ -n "$udid" ] || continue
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  done
  for udid in "${booted_here[@]:-}"; do
    [ -n "$udid" ] || continue
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

mkdir -p "$OUT"
IFS=';' read -r -a device_names <<<"$DEVICES"

for name in "${device_names[@]}"; do
  read -r udid state <<<"$(device_for "$name")"
  if [ -z "${udid:-}" ]; then
    echo "No available simulator named '$name'. Available:" >&2
    xcrun simctl list devices available | grep -E '^\s+(iPhone|iPad)' >&2 || true
    exit 1
  fi
  if [ "$state" != "Booted" ]; then
    echo "Booting $name ($udid)"
    xcrun simctl boot "$udid"
    booted_here+=("$udid")
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override \
    --time "$STATUS_TIME" \
    --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 --operatorName ''
  overridden_here+=("$udid")

  slug=$(slug_for "$name")
  device_out="$OUT/$slug"
  mkdir -p "$device_out"
  # A stale frame from an earlier run must not survive into this set, nor
  # satisfy the driver's check for a capture that never happened.
  rm -f "$device_out"/*.png
  for theme in $THEMES; do
    echo "== store screenshots: device=$name locale=$LOCALE theme=$theme =="
    LOTTI_SCREENSHOT_DIR="$device_out" LOTTI_SIMULATOR_UDID="$udid" $FLUTTER drive \
      --driver=test_driver/manual_screenshots_driver.dart \
      --target=integration_test/store_screenshots_test.dart \
      -d "$udid" \
      --dart-define=LOTTI_MANUAL_LOCALE="$LOCALE" \
      --dart-define=LOTTI_STORE_THEME="$theme" 2>&1 |
      while IFS= read -r line; do
        printf '%s\n' "$line"
        case "$line" in
          *'LOTTI_STORE_CAPTURE '*)
            marker="${line##*LOTTI_STORE_CAPTURE }"
            marker="${marker%$'\r'}"
            shot="${marker%% *}"
            ack_dir="${marker#* }"
            xcrun simctl io "$udid" screenshot --type=png \
              "$device_out/$shot.png" >/dev/null
            # simctl writes RGBA; App Store Connect rejects any alpha channel
            # (with its wrong-dimensions message, confusingly).
            python3 "$(dirname "$0")/strip_alpha.py" "$device_out/$shot.png" >/dev/null
            # Only now may the test move on to the next screen.
            touch "$ack_dir/$shot.done"
            echo "captured $device_out/$shot.png"
            ;;
        esac
      done
  done
done

echo "Store screenshots written to $OUT:"
find "$OUT" -name '*.png' | sort
