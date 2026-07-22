#!/usr/bin/env bash
# Phase-0 smoke: virtual-microphone loopback.
#
# Proves the core audio-injection mechanism of the tutorial-video workbench:
# a PipeWire/PulseAudio null sink whose .monitor acts as the default source
# (= microphone), so audio played into the sink is what any app records —
# the same path Lotti's `record` plugin uses via `parecord`.
#
# Steps: load null sink -> set default source to its monitor -> play a test
# tone into the sink while recording from the default source (like the app
# would) -> assert the recording is non-silent and tone-like.
#
# Usage: smoke_virtual_mic.sh [OUT_DIR]   (default: build/tutorial_videos/smoke)
set -euo pipefail

OUT_DIR="${1:-build/tutorial_videos/smoke}"
mkdir -p "$OUT_DIR"
SINK=lotti_tutorial_mic_smoke
TONE="$OUT_DIR/tone_440.wav"
REC="$OUT_DIR/mic_loopback.wav"

PREV_SOURCE=$(pactl get-default-source)
MODULE_ID=$(pactl load-module module-null-sink "sink_name=$SINK" \
  "sink_properties=device.description=LottiTutorialMicSmoke")

cleanup() {
  pactl set-default-source "$PREV_SOURCE" 2>/dev/null || true
  pactl unload-module "$MODULE_ID" 2>/dev/null || true
}
trap cleanup EXIT

pactl set-default-source "$SINK.monitor"

# 2s 440 Hz tone, mono 48 kHz (the app records 48 kHz).
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=440:duration=2" \
  -ar 48000 -ac 1 "$TONE"

# Record from the DEFAULT source (exactly what parecord/the app does), while
# playing the tone into the sink.
parecord --rate=48000 --channels=1 --file-format=wav "$REC" &
REC_PID=$!
sleep 0.3
paplay --device="$SINK" "$TONE"
sleep 0.3
kill "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

# Assert non-silence: mean volume of a pure looped-back tone must be well
# above the silence floor.
STATS=$(ffmpeg -hide_banner -i "$REC" -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume')
echo "$STATS"
MEAN=$(echo "$STATS" | sed -n 's/.*mean_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p')
if [[ -n "$MEAN" ]] && awk "BEGIN{exit !($MEAN > -50)}"; then
  echo "PASS: virtual mic loopback carries audio (mean ${MEAN} dB) -> $REC"
else
  echo "FAIL: recording is silent or unmeasurable (mean '${MEAN}' dB)"
  exit 1
fi
