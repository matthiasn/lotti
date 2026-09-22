#!/usr/bin/env bash
# Records the App Store App Preview — the listing's video — on an iOS
# simulator, narrated.
#
# Drives integration_test/store_preview_test.dart with `flutter drive` and
# records the simulator's screen with `xcrun simctl io recordVideo` while it
# walks. The recorder is not started with the script: a cold build holds the
# simulator on its home screen for minutes. Instead the walk announces itself
# on stdout once the app is up ("LOTTI_PREVIEW_MARK ready <ack-dir>") and
# holds still until this script has the camera rolling and says so by
# touching <ack-dir>/ready.done — the handshake ios.sh uses for its PNGs.
#
# The narration is the tutorial-video workbench's (tools/tutorial_videos):
# its TTS pre-pass speaks the lines of config/scenarios/app_store_preview.yaml
# in the narrator's voice the manual's videos use, cached by content, and
# each beat of the walk is held until its line fits (LOTTI_PREVIEW_BEATS).
# When it is done the walk leaves a timeline — when the cut and every beat
# began, in epoch milliseconds — in <ack-dir> and prints "… end <ack-dir>";
# this script copies it and answers. A simulator runs on its host's clock,
# so tutorial_videos/app_preview.py sets that timeline against the moment the
# recorder started to find the cut and to lay each line where its beat began,
# and app_preview.sh cuts picture and narration together into the size and
# codec App Store Connect takes, refusing one outside its 15–30 seconds.
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
#   LOTTI_PREVIEW_NARRATION   on (default), or off for a silent preview
#   LOTTI_STORE_THEME         dark or light (default: dark)
#   LOTTI_MANUAL_LOCALE       fixture and narration locale (default: en)
#   TUTORIAL_PYTHON           interpreter for the workbench (default: its own
#                             tools/tutorial_videos/.venv when there is one,
#                             else python3); narration needs pyyaml in it
#
# Narration needs GEMINI_API_KEY in the repository's .env, as the tutorial
# videos do. Finding, booting and dressing the simulator is
# ios_simulator_lib.sh, shared with ios.sh; LOTTI_STORE_STATUS_TIME is
# documented there.
set -euo pipefail

FLUTTER=${FLUTTER:-fvm flutter}
DEVICE=${LOTTI_IOS_PREVIEW_DEVICE:-iPhone 17 Pro Max}
OUT=${LOTTI_PREVIEW_DIR:-build/store_preview/ios}
SIZE=${LOTTI_PREVIEW_SIZE:-886x1920}
NARRATION=${LOTTI_PREVIEW_NARRATION:-on}
THEME=${LOTTI_STORE_THEME:-dark}
LOCALE=${LOTTI_MANUAL_LOCALE:-en}

# The narration script, a scenario of the tutorial workbench.
SCENARIO=app_store_preview
# What the walk leaves in <ack-dir> (_timelineFile in store_preview_test.dart).
WALK_TIMELINE=store_preview_timeline.json

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
workbench="$repo/tools/tutorial_videos"

case "$NARRATION" in
  on | off) ;;
  *)
    echo "LOTTI_PREVIEW_NARRATION is on or off, not '$NARRATION'" >&2
    exit 1
    ;;
esac

if [ -n "${TUTORIAL_PYTHON:-}" ]; then
  python=$TUTORIAL_PYTHON
elif [ -x "$workbench/.venv/bin/python3" ]; then
  python="$workbench/.venv/bin/python3"
else
  python=python3
fi

# The workbench runs as a package from its own directory; every path handed
# to it is absolute.
workbench_run() {
  (cd "$workbench" && "$python" -m "$@")
}

# shellcheck source=tool/store_screenshots/ios_simulator_lib.sh
source "$here/ios_simulator_lib.sh"

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

# Narration first: a missing key or a script that cannot fit 30 seconds
# fails here, before a simulator boots and the app builds.
beats=""
manifest=""
if [ "$NARRATION" = on ]; then
  if ! grep -q '^GEMINI_API_KEY=.' "$repo/.env" 2>/dev/null; then
    echo "Narration speaks through Gemini TTS: put GEMINI_API_KEY in $repo/.env" \
      "(as for make tutorial_video), or run with LOTTI_PREVIEW_NARRATION=off." >&2
    exit 1
  fi
  if ! "$python" -c 'import yaml' 2>/dev/null; then
    echo "$python has no pyyaml, which the narration pass reads its script" \
      "with. Create the workbench's venv:" >&2
    echo "  (cd tools/tutorial_videos && python3 -m venv .venv &&" \
      ".venv/bin/pip install pyyaml)" >&2
    exit 1
  fi
  echo "== narration: $SCENARIO, $LOCALE =="
  workbench_run tutorial_videos tts \
    --scenario "$SCENARIO" --locale "$LOCALE" --out-dir "$OUT/narration"
  manifest="$OUT/narration/${SCENARIO}_${LOCALE}.manifest.json"
  beats=$(workbench_run tutorial_videos.app_preview pacing --manifest "$manifest")
  echo "beats: $beats"
fi

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

# Epoch milliseconds: the clock the walk's timeline is written in.
now_ms() {
  python3 -c 'import time; print(int(time.time() * 1000))'
}

claim_simulator "$DEVICE"
device_out="$OUT/$(slug_for "$DEVICE")"
mkdir -p "$device_out"
name="store_preview_${LOCALE}_${THEME}"
raw="$device_out/$name.mov"
preview="$device_out/$name.mp4"
timeline="$device_out/$name.timeline.json"
narration_track="$device_out/$name.narration.wav"
# A stale file from an earlier run must not pass for this run's.
rm -f "$raw" "$preview" "$timeline" "$narration_track"

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
  started_at_ms=$(now_ms)
}

started_at_ms=""
drive_status=""

echo "== store preview: device=$DEVICE locale=$LOCALE theme=$THEME narration=$NARRATION =="
while IFS= read -r line; do
  printf '%s\n' "$line"
  case "$line" in
    'LOTTI_PREVIEW_DRIVE_EXIT '*)
      drive_status="${line#LOTTI_PREVIEW_DRIVE_EXIT }"
      ;;
    *'LOTTI_PREVIEW_MARK '*)
      marker="${line##*LOTTI_PREVIEW_MARK }"
      marker="${marker%$'\r'}"
      ack_dir="${marker#* }"
      case "${marker%% *}" in
        ready)
          start_recorder
          # Only now may the walk begin.
          touch "$ack_dir/ready.done"
          echo "recording $raw"
          ;;
        end)
          # Copied while the app is still up to wait for the answer.
          cp "$ack_dir/$WALK_TIMELINE" "$timeline"
          touch "$ack_dir/end.done"
          ;;
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
    --dart-define=LOTTI_STORE_THEME="$THEME" \
    --dart-define=LOTTI_PREVIEW_BEATS="$beats" 2>&1 || status=$?
  echo "LOTTI_PREVIEW_DRIVE_EXIT $status"
)
stop_recorder

if [ "$drive_status" != "0" ]; then
  echo "The walk failed (exit ${drive_status:-unknown}); no preview cut." >&2
  [ -f "$raw" ] && echo "What it looked like: $raw" >&2
  exit 1
fi
if [ ! -f "$timeline" ]; then
  echo "The walk passed without handing over its timeline; no preview cut." >&2
  exit 1
fi

if [ "$NARRATION" = on ]; then
  cut=$(workbench_run tutorial_videos.app_preview narrate \
    --manifest "$manifest" --timeline "$timeline" \
    --recorder-start "$started_at_ms" --out "$narration_track")
  audio=$narration_track
else
  cut=$(workbench_run tutorial_videos.app_preview cut \
    --timeline "$timeline" --recorder-start "$started_at_ms")
  audio=""
fi
read -r cut_from cut_length <<<"$cut"

LOTTI_PREVIEW_AUDIO="$audio" "$here/app_preview.sh" "$raw" "$preview" "$SIZE" \
  "$cut_from" "$cut_length"
echo "Raw recording: $raw"
