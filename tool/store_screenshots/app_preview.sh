#!/usr/bin/env bash
# Transcodes a screen recording into an App Store App Preview.
#
#   tool/store_screenshots/app_preview.sh IN OUT.mp4 [WIDTHxHEIGHT] [START] [DURATION]
#
# App Store Connect takes H.264 up to High profile level 4.0, progressive, at
# most 30 fps, 10–12 Mbps as a target, in one of its fixed sizes: 886x1920 for
# the 6.9" and 6.5" iPhone slots (the default here) and 1200x1600 for the 13"
# iPad slot. START and DURATION (seconds) cut the slice and default to the
# whole input. A simulator recording has a variable frame rate — simctl writes
# a frame when the screen changes — so it is resampled to constant 30 fps.
#
# A preview runs 15 to 30 seconds. The result is measured, and one outside
# that range fails the script and is removed: a file App Store Connect would
# refuse must not be left looking like a deliverable.
#
# Apple's spec describes the audio track (stereo, 256 kbps AAC, 44.1 or 48
# kHz) without saying whether one is required. LOTTI_PREVIEW_AUDIO picks it:
#
#   (unset or empty)  a silent track — it conforms either way
#   keep              the input's own track, for a capture narrated live
#   <file>            an audio file on the INPUT's clock (0 = the recording's
#                     first frame), cut with the same START and DURATION as
#                     the picture — the narration ios_preview.sh lays down.
#                     It is normalized to -16 LUFS, the tutorial videos'
#                     loudness, and padded with silence so it never ends
#                     before the picture does.
#
# The recipe does not care where the recording came from: it applies to a
# QuickTime capture of an iPhone exactly as to ios_preview.sh's simulator
# recording.
set -euo pipefail

IN=${1:?input recording}
OUT=${2:?output .mp4}
SIZE=${3:-886x1920}
START=${4:-0}
DURATION=${5:-}

AUDIO=${LOTTI_PREVIEW_AUDIO:-}

W=${SIZE%x*}
H=${SIZE#*x}
mkdir -p "$(dirname "$OUT")"

args=(-v error -y -i "$IN")
audio_filter=()
case "$AUDIO" in
  "")
    args+=(-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000)
    audio_map=(-map 0:v:0 -map 1:a:0 -shortest)
    ;;
  keep)
    audio_map=(-map 0:v:0 -map 0:a:0)
    ;;
  *)
    if [ ! -f "$AUDIO" ]; then
      echo "LOTTI_PREVIEW_AUDIO names no file: $AUDIO" >&2
      exit 1
    fi
    # -ss below is an output option, so it cuts this track exactly as it
    # cuts the picture: both are on the recording's clock.
    args+=(-i "$AUDIO")
    audio_map=(-map 0:v:0 -map 1:a:0 -shortest)
    audio_filter=(-af "loudnorm=I=-16:TP=-1.5:LRA=11,apad")
    ;;
esac
args+=(-ss "$START")
[ -n "$DURATION" ] && args+=(-t "$DURATION")
args+=(
  "${audio_map[@]}"
  # Expanded this way because bash 3.2, macOS's own, calls an empty array
  # unbound under `set -u`.
  ${audio_filter[@]+"${audio_filter[@]}"}
  -vf "scale=${W}:${H}:flags=lanczos"
  -fps_mode cfr -r 30
  -c:v libx264 -profile:v high -level 4.0
  -b:v 10M -maxrate 12M -bufsize 20M -pix_fmt yuv420p
  -c:a aac -b:a 256k -ar 48000 -ac 2
  -movflags +faststart
  "$OUT"
)
ffmpeg "${args[@]}"

ffprobe -v error \
  -show_entries stream=codec_name,profile,width,height,r_frame_rate,channels:format=duration \
  -of default=nw=1 "$OUT"

length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
if ! python3 -c 'import sys; sys.exit(0 if 15.0 <= float(sys.argv[1]) <= 30.0 else 1)' "$length"; then
  rm -f "$OUT"
  echo "App Preview is ${length}s; App Store Connect takes 15 to 30. Not written." >&2
  exit 1
fi
echo "Wrote $OUT (${length}s)"
