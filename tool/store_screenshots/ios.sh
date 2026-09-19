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
#
# Finding, booting and dressing the simulators is ios_simulator_lib.sh, shared
# with ios_preview.sh; LOTTI_STORE_STATUS_TIME is documented there.
set -euo pipefail

FLUTTER=${FLUTTER:-fvm flutter}
DEVICES=${LOTTI_IOS_DEVICES:-iPhone 17 Pro Max;iPad Pro 13-inch (M5)}
OUT=${LOTTI_SCREENSHOT_DIR:-build/store_screenshots/ios}
THEMES=${LOTTI_STORE_THEMES:-dark light}
LOCALE=${LOTTI_MANUAL_LOCALE:-en}

# shellcheck source=tool/store_screenshots/ios_simulator_lib.sh
source "$(dirname "$0")/ios_simulator_lib.sh"
trap release_simulators EXIT

mkdir -p "$OUT"
IFS=';' read -r -a device_names <<<"$DEVICES"

for name in "${device_names[@]}"; do
  claim_simulator "$name"
  udid=$SIM_UDID

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
