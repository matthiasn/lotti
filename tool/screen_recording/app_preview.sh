#!/usr/bin/env bash
# Transcodes a screen recording into an App Store App Preview.
#
#   tool/screen_recording/app_preview.sh IN OUT.mp4 [WIDTHxHEIGHT] [START] [DURATION]
#
# App Store Connect takes H.264 High profile up to level 4.0, at most 30 fps,
# 10–12 Mbps, in one of its fixed sizes: 886x1920 for the 6.9" and 6.5" iPhone
# slots (the default here) and 1200x1600 for the 13" iPad slot. A preview runs
# 15–30 seconds, so START and DURATION (seconds) cut the slice; they default to
# the whole input. A variable-frame-rate simulator recording is resampled to
# constant 30 fps, which is what the duration check upstream wants to see.
#
# Apple's own guidance says previews use "footage captured on device"; this
# recipe applies to a QuickTime capture of a phone exactly as to a simulator
# recording. The audio track is dropped by default — a simulator recording has
# none worth keeping — and kept as 256 kbps AAC, App Store Connect's spec,
# with LOTTI_PREVIEW_AUDIO=keep for a narrated device capture.
set -euo pipefail

IN=${1:?input recording}
OUT=${2:?output .mp4}
SIZE=${3:-886x1920}
START=${4:-0}
DURATION=${5:-}

W=${SIZE%x*}
H=${SIZE#*x}
mkdir -p "$(dirname "$OUT")"

args=(-v error -y -i "$IN" -ss "$START")
[ -n "$DURATION" ] && args+=(-t "$DURATION")
args+=(
  -vf "scale=${W}:${H}:flags=lanczos"
  -fps_mode cfr -r 30
  -c:v libx264 -profile:v high -level 4.0
  -b:v 10M -maxrate 12M -bufsize 20M -pix_fmt yuv420p
)
if [ "${LOTTI_PREVIEW_AUDIO:-}" = "keep" ]; then
  args+=(-c:a aac -b:a 256k)
else
  args+=(-an)
fi
args+=("$OUT")
ffmpeg "${args[@]}"
ffprobe -v error -show_entries stream=width,height,r_frame_rate:format=duration \
  -of default=nw=1 "$OUT"
echo "Wrote $OUT"
