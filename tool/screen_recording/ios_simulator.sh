#!/usr/bin/env bash
# Records an iOS simulator's display while a command runs.
#
#   tool/screen_recording/ios_simulator.sh [-d UDID] [-o OUT.mov] [-c h264|hevc] -- <command...>
#
# Starts `xcrun simctl io <udid> recordVideo`, waits until it reports its first
# frame, runs the command on the host, interrupts the recorder so it finalizes
# the file, and prints its path. The command's exit status is this script's
# exit status. The simulator records at its device's native size (an iPhone 17
# is 1206×2622); tool/screen_recording/app_preview.sh turns that into the size
# and codec App Store Connect takes.
#
# A physical iPhone has no equivalent: `devicectl` cannot record or screenshot,
# so device footage is QuickTime Player over USB (File › New Movie Recording,
# pick the phone as camera) or the phone's own Control Center recording.
#
#   LOTTI_SIMULATOR_UDID   simulator to record (default: "booted"), overridden by -d
set -euo pipefail

UDID=${LOTTI_SIMULATOR_UDID:-booted}
CODEC=h264
OUT=""

usage() {
  sed -n '2,17p' "$0" >&2
  exit 64
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d) UDID=$2; shift 2 ;;
    -o) OUT=$2; shift 2 ;;
    -c) CODEC=$2; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[ $# -gt 0 ] || usage
OUT=${OUT:-build/screen_recordings/ios_simulator_$(date +%Y%m%d-%H%M%S).mov}
mkdir -p "$(dirname "$OUT")"

recorder_log=$(mktemp)
xcrun simctl io "$UDID" recordVideo --codec="$CODEC" --force "$OUT" \
  2>"$recorder_log" &
recorder=$!

# simctl writes "Recording started" once the first frame is in; a recorder
# that never gets there (no such simulator, not booted) exits instead.
for _ in $(seq 1 60); do
  grep -q 'Recording started' "$recorder_log" 2>/dev/null && break
  if ! kill -0 "$recorder" 2>/dev/null; then
    cat "$recorder_log" >&2
    exit 1
  fi
  sleep 0.5
done
if ! grep -q 'Recording started' "$recorder_log" 2>/dev/null; then
  echo "simctl never reported its first frame; not running the command" >&2
  kill "$recorder" 2>/dev/null || true
  exit 1
fi

stop_recording() {
  if kill -0 "$recorder" 2>/dev/null; then
    kill -INT "$recorder"
    wait "$recorder" 2>/dev/null || true
  fi
}
trap stop_recording EXIT

set +e
"$@"
status=$?
set -e

stop_recording
trap - EXIT
echo "Recorded $OUT"
exit "$status"
