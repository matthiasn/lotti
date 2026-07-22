#!/usr/bin/env bash
# Phase-0 smoke: headless screen capture.
#
# Proves the recording mechanism of the tutorial-video workbench: an app
# rendering on a dedicated Xvfb display is captured by ffmpeg x11grab to a
# lightly-compressed intermediate, exactly as the real pipeline will record
# the Flutter app.
#
# Uses ffplay (an X client we know is installed) showing a moving test
# pattern as the stand-in app, then asserts the capture has the requested
# geometry, duration, and non-constant frames.
#
# Usage: smoke_capture.sh [OUT_DIR]   (default: build/tutorial_videos/smoke)
set -euo pipefail

OUT_DIR="${1:-build/tutorial_videos/smoke}"
mkdir -p "$OUT_DIR"
DISPLAY_NUM=":97"
SIZE=1280x720
OUT="$OUT_DIR/capture.mkv"
XVFB_PID=""
FFPLAY_PID=""

Xvfb "$DISPLAY_NUM" -screen 0 "${SIZE}x24" &
XVFB_PID=$!
cleanup() {
  kill "$FFPLAY_PID" 2>/dev/null || true
  kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT
sleep 1

DISPLAY="$DISPLAY_NUM" ffplay -hide_banner -loglevel error \
  -f lavfi -i "testsrc2=size=${SIZE}:rate=30" -fs &
FFPLAY_PID=$!
sleep 2

ffmpeg -hide_banner -loglevel error -y \
  -f x11grab -framerate 30 -video_size "$SIZE" -i "$DISPLAY_NUM" \
  -t 3 -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "$OUT"

read -r W H NFRAMES <<< "$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -count_frames \
  -show_entries stream=nb_read_frames -of csv=p=0 "$OUT" | tr ',' ' ')"
echo "capture: ${W}x${H}, ${NFRAMES} frames -> $OUT"

# Frames must vary (moving test pattern), i.e. not a stuck black screen:
# compare first and last frame signatures.
SIG1=$(ffmpeg -hide_banner -loglevel error -i "$OUT" -vf "select=eq(n\,0)" -frames:v 1 -f md5 - )
SIG2=$(ffmpeg -hide_banner -loglevel error -i "$OUT" -vf "select=eq(n\,60)" -frames:v 1 -f md5 - )

if [[ "$W" == "1280" && "$H" == "720" && "$NFRAMES" -ge 80 && "$SIG1" != "$SIG2" ]]; then
  echo "PASS: Xvfb + x11grab capture works (geometry, frame count, moving content)"
else
  echo "FAIL: W=$W H=$H frames=$NFRAMES sig_equal=$([[ "$SIG1" == "$SIG2" ]] && echo yes || echo no)"
  exit 1
fi
