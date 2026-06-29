#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export the beat-synced character showcase from the release Linux app, frame-exact.

This is the preferred master path when duplicate/dropped capture frames must be
avoided but the flutter_test software renderer is too slow. The release app
steps a fixed timeline, captures its stage RepaintBoundary, streams raw RGBA
frames to one ffmpeg process, and muxes AAC audio. Xvfb is used only as an
offscreen render surface; ffmpeg does not screen-capture it.

Usage:
  tools/character_video_export/export_dance_video_app.sh [options]

Options:
  --preset 1080p|720p       Output size preset (default: 1080p)
  --width PX                Override output width (must be even)
  --height PX               Override output height (must be even)
  --fps N                   Output frames per second (default: 60)
  --start SEC               Audio/render start time in seconds (default: 0)
  --duration SEC            Export duration in seconds; 0/rest by default
  --out PATH                Output MP4 path
  --audio PATH              Audio file path
  --beatmap PATH            Beat-map JSON path
  --words PATH              Optional synced words JSON path
  --cues PATH               Optional Rhubarb cues JSON path
  --crf N                   x264 CRF, lower is better/larger (default: 18)
  --audio-kbps N            AAC bitrate in kbps (default: 320)
  --x264-preset NAME        x264 preset (default: veryfast)
  --warmup SEC              Asset/shader warmup before frame 0 (default: 2)
  --rebuild                 Rebuild the Linux release bundle first
  --captions                Burn lyric captions into the video
  -h, --help                Show this help

Example:
  tools/character_video_export/export_dance_video_app.sh \
    --preset 1080p --fps 60 --duration 144.091429 \
    --out build/character_video_exports/dance_full_1080p60_master.mp4
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

preset="1080p"
width=""
height=""
fps="60"
start="0"
duration="0"
out=""
audio="${DANCE_AUDIO:-/home/parallels/Downloads/Omah_Lay-Moving.mp3}"
beatmap="${DANCE_BEATMAP:-/home/parallels/github/lotti/tools/dance_audio/out/moving.json}"
words="${DANCE_WORDS:-/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json}"
cues="${DANCE_CUES:-/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json}"
crf="18"
audio_kbps="320"
x264_preset="veryfast"
warmup="2"
rebuild="0"
captions="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      preset="${2:?missing value for --preset}"
      shift 2
      ;;
    --width)
      width="${2:?missing value for --width}"
      shift 2
      ;;
    --height)
      height="${2:?missing value for --height}"
      shift 2
      ;;
    --fps)
      fps="${2:?missing value for --fps}"
      shift 2
      ;;
    --start)
      start="${2:?missing value for --start}"
      shift 2
      ;;
    --duration)
      duration="${2:?missing value for --duration}"
      shift 2
      ;;
    --out)
      out="${2:?missing value for --out}"
      shift 2
      ;;
    --audio)
      audio="${2:?missing value for --audio}"
      shift 2
      ;;
    --beatmap)
      beatmap="${2:?missing value for --beatmap}"
      shift 2
      ;;
    --words)
      words="${2:?missing value for --words}"
      shift 2
      ;;
    --cues)
      cues="${2:?missing value for --cues}"
      shift 2
      ;;
    --crf)
      crf="${2:?missing value for --crf}"
      shift 2
      ;;
    --audio-kbps)
      audio_kbps="${2:?missing value for --audio-kbps}"
      shift 2
      ;;
    --x264-preset)
      x264_preset="${2:?missing value for --x264-preset}"
      shift 2
      ;;
    --warmup)
      warmup="${2:?missing value for --warmup}"
      shift 2
      ;;
    --rebuild)
      rebuild="1"
      shift
      ;;
    --captions)
      captions="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$preset" in
  1080p)
    width="${width:-1920}"
    height="${height:-1080}"
    ;;
  720p)
    width="${width:-1280}"
    height="${height:-720}"
    ;;
  *)
    if [[ -z "$width" || -z "$height" ]]; then
      echo "Unknown preset '$preset'. Use 1080p, 720p, or pass --width/--height." >&2
      exit 2
    fi
    ;;
esac

if [[ -z "$out" ]]; then
  out="build/character_video_exports/dance_app_${width}x${height}_${fps}fps.mp4"
fi

for path in "$audio" "$beatmap"; do
  if [[ ! -f "$path" ]]; then
    echo "Required input not found: $path" >&2
    exit 2
  fi
done

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg is required" >&2
  exit 2
fi

if ! command -v Xvfb >/dev/null; then
  cat >&2 <<'EOF'
Xvfb is required for non-disruptive app export, but it is not installed.
Install it in the VM, then rerun:

  sudo apt-get install -y xvfb
EOF
  exit 2
fi

app="build/linux/arm64/release/bundle/lotti"
if [[ "$rebuild" == "1" || ! -x "$app" ]]; then
  fvm flutter build linux --release \
    -t lib/features/character/demo/character_dance_to_track_demo.dart
fi

mkdir -p "$(dirname "$out")"
display=":$((90 + RANDOM % 100))"
xvfb_pid=""

cleanup() {
  if [[ -n "$xvfb_pid" ]]; then
    kill "$xvfb_pid" 2>/dev/null || true
    wait "$xvfb_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

Xvfb "$display" -screen 0 "${width}x${height}x24" -nolisten tcp -ac -nocursor &
xvfb_pid="$!"
for _ in {1..50}; do
  if xdpyinfo -display "$display" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

DISPLAY="$display" \
GDK_BACKEND=x11 \
DANCE_RENDER_ONLY=1 \
DANCE_RENDER_WIDTH="$width" \
DANCE_RENDER_HEIGHT="$height" \
DANCE_RENDER_START="$start" \
DANCE_RENDER_CAPTIONS="$captions" \
DANCE_APP_EXPORT=1 \
DANCE_APP_EXPORT_FPS="$fps" \
DANCE_APP_EXPORT_DURATION="$duration" \
DANCE_APP_EXPORT_OUT="$out" \
DANCE_APP_EXPORT_CRF="$crf" \
DANCE_APP_EXPORT_AUDIO_KBPS="$audio_kbps" \
DANCE_APP_EXPORT_X264_PRESET="$x264_preset" \
DANCE_APP_EXPORT_WARMUP="$warmup" \
DANCE_AUDIO="$audio" \
DANCE_BEATMAP="$beatmap" \
DANCE_WORDS="$words" \
DANCE_CUES="$cues" \
"$app"
