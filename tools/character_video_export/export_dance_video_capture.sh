#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export the beat-synced character showcase by capturing the release Linux demo.

This is the fast preview path: the app renders normally into an X display,
ffmpeg captures that display in real time, and the original song segment is
muxed as AAC. It requires Xvfb for non-disruptive offscreen capture.

Do not use this wrapper for master exports when dropped/duplicated frames must
be avoided. Real-time X capture is wall-clock scheduled and can report ffmpeg
dup/drop cadence corrections. Use export_dance_video.sh for exact frame-indexed
master renders.

Usage:
  tools/character_video_export/export_dance_video_capture.sh [options]

Options:
  --preset 1080p|720p       Output size preset (default: 1080p)
  --width PX                Override output width (must be even)
  --height PX               Override output height (must be even)
  --fps N                   Capture frames per second (default: 30)
  --start SEC               Audio/render start time in seconds (default: 0)
  --duration SEC            Export duration in seconds (default: 20)
  --out PATH                Output MP4 path
  --audio PATH              Audio file path
  --beatmap PATH            Beat-map JSON path
  --words PATH              Optional synced words JSON path
  --cues PATH               Optional Rhubarb cues JSON path
  --crf N                   x264 CRF, lower is better/larger (default: 18)
  --audio-kbps N            AAC bitrate in kbps (default: 320)
  --x264-preset NAME        x264 preset (default: veryfast)
  --warmup SEC              Pre-capture visual warmup while timeline is paused (default: 2)
  --rebuild                 Rebuild the Linux release bundle first
  --captions                Burn lyric captions into the video
  -h, --help                Show this help

Example:
  tools/character_video_export/export_dance_video_capture.sh \
    --preset 1080p --start 80 --duration 20 \
    --out build/character_video_exports/dance_20s_fast.mp4
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

preset="1080p"
width=""
height=""
fps="30"
start="0"
duration="20"
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
  out="build/character_video_exports/dance_capture_${width}x${height}_${fps}fps.mp4"
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
Xvfb is required for non-disruptive real-time export, but it is not installed.
Install it in the VM, then rerun:

  sudo apt-get install -y xvfb

The deterministic fallback exporter still works, but it is much slower because
Flutter's test engine uses software rendering and per-frame image readback.
EOF
  exit 2
fi

app="build/linux/arm64/release/bundle/lotti"
if [[ "$rebuild" == "1" || ! -x "$app" ]]; then
  fvm flutter build linux --release \
    -t lib/features/character/demo/character_dance_to_track_demo.dart
fi

mkdir -p "$(dirname "$out")"
tmpdir="$(mktemp -d -t lotti-dance-export.XXXXXX)"
ready_file="$tmpdir/ready"
start_file="$tmpdir/start"
display=":$((90 + RANDOM % 100))"
xvfb_pid=""
app_pid=""

cleanup() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ -n "$xvfb_pid" ]]; then
    kill "$xvfb_pid" 2>/dev/null || true
    wait "$xvfb_pid" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
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
DANCE_RENDER_READY_FILE="$ready_file" \
DANCE_RENDER_START_FILE="$start_file" \
DANCE_RENDER_CAPTIONS="$captions" \
DANCE_AUDIO="$audio" \
DANCE_BEATMAP="$beatmap" \
DANCE_WORDS="$words" \
DANCE_CUES="$cues" \
"$app" >/tmp/lotti-dance-export-app.log 2>&1 &
app_pid="$!"

for _ in {1..300}; do
  if [[ -f "$ready_file" ]]; then
    break
  fi
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App exited before it became ready:" >&2
    cat /tmp/lotti-dance-export-app.log >&2 || true
    exit 1
  fi
  sleep 0.1
done
if [[ ! -f "$ready_file" ]]; then
  echo "Timed out waiting for the render window to become ready" >&2
  cat /tmp/lotti-dance-export-app.log >&2 || true
  exit 1
fi

# The render-only app holds the timeline on the requested start frame until
# start_file exists. Give async backdrop image/shader loads time to resolve
# before ffmpeg captures frame 0, otherwise the first frames can show shader
# fallbacks without the bitmap city/yacht/palm layers.
sleep "$warmup"

ffmpeg \
  -y \
  -f x11grab \
  -video_size "${width}x${height}" \
  -framerate "$fps" \
  -draw_mouse 0 \
  -i "${display}.0+0,0" \
  -ss "$start" \
  -t "$duration" \
  -i "$audio" \
  -map 0:v:0 \
  -map 1:a:0 \
  -c:v libx264 \
  -preset "$x264_preset" \
  -crf "$crf" \
  -pix_fmt yuv420p \
  -profile:v high \
  -level 4.2 \
  -r "$fps" \
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -c:a aac \
  -b:a "${audio_kbps}k" \
  -ar 48000 \
  -movflags +faststart \
  -shortest \
  "$out" &
ffmpeg_pid="$!"

# Start the app's deterministic render clock immediately after ffmpeg begins
# capture. The held first frame keeps startup/loading out of the captured range.
touch "$start_file"
wait "$ffmpeg_pid"

echo "wrote $out"
