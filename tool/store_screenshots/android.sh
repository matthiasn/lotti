#!/usr/bin/env bash
# Captures the Play Store listing screenshots on an Android emulator.
#
# Drives integration_test/store_screenshots_test.dart with `flutter drive`
# against a booted emulator (or boots one from $LOTTI_AVD), once per theme,
# and collects the PNGs the driver writes into $LOTTI_SCREENSHOT_DIR.
#
# The emulator window is pinned to $LOTTI_STORE_WINDOW for the run and reset
# afterwards: Play rejects a screenshot whose long side is more than twice
# its short side, and the stock Pixel profiles are 20:9. 1080x1920 is 9:16,
# the ratio Play also asks for when it features a listing.
#
#   FLUTTER            flutter command (default: fvm flutter)
#   LOTTI_AVD          AVD to boot when no device is attached
#   LOTTI_ANDROID_DEVICE  adb serial (default: emulator-5554)
#   LOTTI_SCREENSHOT_DIR  output directory (default: build/store_screenshots/android)
#   LOTTI_STORE_THEMES    space-separated themes (default: "dark light")
#   LOTTI_MANUAL_LOCALE   fixture locale (default: en)
#   LOTTI_STORE_WINDOW    WxH forced on the emulator (default: 1080x1920)
set -euo pipefail

FLUTTER=${FLUTTER:-fvm flutter}
DEVICE=${LOTTI_ANDROID_DEVICE:-emulator-5554}
OUT=${LOTTI_SCREENSHOT_DIR:-build/store_screenshots/android}
THEMES=${LOTTI_STORE_THEMES:-dark light}
LOCALE=${LOTTI_MANUAL_LOCALE:-en}
WINDOW=${LOTTI_STORE_WINDOW:-1080x1920}
SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}
ADB=${ADB:-$SDK/platform-tools/adb}
EMULATOR=${EMULATOR:-$SDK/emulator/emulator}

booted_here=0
if ! "$ADB" -s "$DEVICE" get-state >/dev/null 2>&1; then
  if [ -z "${LOTTI_AVD:-}" ]; then
    echo "No device '$DEVICE' attached and LOTTI_AVD is unset." >&2
    echo "Boot an emulator first, or set LOTTI_AVD to one of:" >&2
    "$EMULATOR" -list-avds >&2 || true
    exit 1
  fi
  echo "Booting AVD $LOTTI_AVD as $DEVICE"
  "$EMULATOR" -avd "$LOTTI_AVD" -no-snapshot-load -no-boot-anim -no-audio \
    -gpu "${LOTTI_EMULATOR_GPU:-swiftshader_indirect}" >/dev/null 2>&1 &
  booted_here=1
  "$ADB" -s "$DEVICE" wait-for-device
  until [ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done
fi

cleanup() {
  "$ADB" -s "$DEVICE" shell wm size reset >/dev/null 2>&1 || true
  if [ "$booted_here" = 1 ]; then
    "$ADB" -s "$DEVICE" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Android's opportunistic Private DNS (DNS-over-TLS) "validates" against the
# emulator's virtual resolver at 10.0.2.3 and then fails every real lookup
# over it, silently: ICMP works, no hostname resolves, and the fixture media
# on R2 never arrives. Plain DNS through the same resolver is fine.
"$ADB" -s "$DEVICE" shell settings put global private_dns_mode off
"$ADB" -s "$DEVICE" shell wm size "$WINDOW"
mkdir -p "$OUT"

for theme in $THEMES; do
  echo "== store screenshots: locale=$LOCALE theme=$theme =="
  LOTTI_SCREENSHOT_DIR="$OUT" $FLUTTER drive \
    --driver=test_driver/manual_screenshots_driver.dart \
    --target=integration_test/store_screenshots_test.dart \
    -d "$DEVICE" \
    --dart-define=LOTTI_MANUAL_LOCALE="$LOCALE" \
    --dart-define=LOTTI_STORE_THEME="$theme"
done

echo "Store screenshots written to $OUT:"
ls -1 "$OUT"
