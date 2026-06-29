#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export the beat-synced character showcase by capturing a release Linux app.

This is the fast preview/master-candidate path for the current VM: it runs the
release demo inside a temporary rootful Xwayland display, prerolls the app,
captures one extra second to let x11grab/ffmpeg settle, trims that capture
preroll away, and muxes the requested song segment as AAC.

Unlike the frame-exact app exporter, this is still a real-time screen capture.
Use the built-in smoke checks after export when cadence matters.

Usage:
  tools/character_video_export/export_dance_video_realtime.sh [options]

Options:
  --preset 1440p|1080p|720p
                             Output size preset (default: 1080p)
  --width PX                Override output width (must be even)
  --height PX               Override output height (must be even)
  --render-width PX         Temporary app/capture width (default: 1440 for 1080p)
  --render-height PX        Temporary app/capture height (default: 810 for 1080p)
  --fps N                   Output frames per second (default: 60)
  --start SEC               Audio/render start time in seconds (default: 0)
  --duration SEC            Export duration in seconds (default: beatmap duration)
  --out PATH                Output MP4 path
  --audio PATH              Audio file path
  --beatmap PATH            Beat-map JSON path
  --words PATH              Optional synced words JSON path
  --cues PATH               Optional Rhubarb cues JSON path
  --crf N                   x264 CRF, lower is better/larger (default: 18)
  --audio-kbps N            AAC bitrate in kbps (default: 320)
  --x264-preset NAME        x264 preset (default: veryfast)
  --app-preroll SEC         App run time before capture starts (default: 2)
  --capture-preroll SEC     Captured preroll trimmed out of output (default: 1)
  --rebuild                 Rebuild the Linux release bundle first
  --captions                Burn lyric captions into the video
  -h, --help                Show this help

Example:
  tools/character_video_export/export_dance_video_realtime.sh \
    --preset 1080p --fps 60 \
    --out build/character_video_exports/dance_full_1080p60_fast.mp4
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

preset="1080p"
width=""
height=""
render_width=""
render_height=""
fps="60"
start="0"
duration=""
out=""
audio="${DANCE_AUDIO:-/home/parallels/Downloads/Omah_Lay-Moving.mp3}"
beatmap="${DANCE_BEATMAP:-/home/parallels/github/lotti/tools/dance_audio/out/moving.json}"
words="${DANCE_WORDS:-/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json}"
cues="${DANCE_CUES:-/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json}"
crf="18"
audio_kbps="320"
x264_preset="veryfast"
app_preroll="2"
capture_preroll="1"
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
    --render-width)
      render_width="${2:?missing value for --render-width}"
      shift 2
      ;;
    --render-height)
      render_height="${2:?missing value for --render-height}"
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
    --app-preroll)
      app_preroll="${2:?missing value for --app-preroll}"
      shift 2
      ;;
    --capture-preroll)
      capture_preroll="${2:?missing value for --capture-preroll}"
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
    render_width="${render_width:-1440}"
    render_height="${render_height:-810}"
    ;;
  1440p)
    width="${width:-2560}"
    height="${height:-1440}"
    render_width="${render_width:-2560}"
    render_height="${render_height:-1440}"
    ;;
  720p)
    width="${width:-1280}"
    height="${height:-720}"
    render_width="${render_width:-1280}"
    render_height="${render_height:-720}"
    ;;
  *)
    if [[ -z "$width" || -z "$height" ]]; then
      echo "Unknown preset '$preset'. Use 1080p, 720p, or pass --width/--height." >&2
      exit 2
    fi
    render_width="${render_width:-$width}"
    render_height="${render_height:-$height}"
    ;;
esac

if [[ -z "$out" ]]; then
  out="build/character_video_exports/dance_realtime_${width}x${height}_${fps}fps.mp4"
fi

for value in "$width" "$height" "$render_width" "$render_height"; do
  if (( value % 2 != 0 )); then
    echo "All output/render dimensions must be even for yuv420p H.264" >&2
    exit 2
  fi
done

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
if ! command -v Xwayland >/dev/null; then
  echo "Xwayland is required for the realtime exporter" >&2
  exit 2
fi

if [[ -z "$duration" ]]; then
  duration="$(
    python3 - "$beatmap" "$start" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
start = float(sys.argv[2])
duration = data.get("audio", {}).get("duration_sec")
if duration is None:
    last_beat = data["beats"][-1]
    duration = last_beat["time_sec"] if isinstance(last_beat, dict) else last_beat
duration = float(duration)
print(f"{max(0.0, duration - start):.6f}")
PY
  )"
fi

if awk -v d="$duration" 'BEGIN { exit !(d > 0) }'; then
  :
else
  echo "Export duration must be positive" >&2
  exit 2
fi

app="build/linux/arm64/release/bundle/lotti"
if [[ "$rebuild" == "1" || ! -x "$app" ]]; then
  fvm flutter build linux --release \
    -t lib/features/character/demo/character_dance_to_track_demo.dart
fi

mkdir -p "$(dirname "$out")"
tmpdir="$(mktemp -d -t lotti-dance-realtime.XXXXXX)"
ready_file="$tmpdir/ready"
start_file="$tmpdir/start"
display=":$((120 + RANDOM % 80))"
xwayland_pid=""
app_pid=""

cleanup() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ -n "$xwayland_pid" ]]; then
    kill "$xwayland_pid" 2>/dev/null || true
    wait "$xwayland_pid" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

render_start="$(
  awk \
    -v s="$start" \
    -v a="$app_preroll" \
    -v c="$capture_preroll" \
    'BEGIN { printf "%.6f", s - a - c }'
)"

Xwayland "$display" \
  -geometry "${render_width}x${render_height}" \
  -fakescreenfps "$fps" \
  -ac \
  -noreset \
  -nocursor \
  >"$tmpdir/xwayland.log" 2>&1 &
xwayland_pid="$!"
for _ in {1..80}; do
  if xdpyinfo -display "$display" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

DISPLAY="$display" \
GDK_BACKEND=x11 \
DANCE_RENDER_ONLY=1 \
DANCE_RENDER_WIDTH="$render_width" \
DANCE_RENDER_HEIGHT="$render_height" \
DANCE_RENDER_START="$render_start" \
DANCE_RENDER_READY_FILE="$ready_file" \
DANCE_RENDER_START_FILE="$start_file" \
DANCE_RENDER_CAPTIONS="$captions" \
DANCE_AUDIO="$audio" \
DANCE_BEATMAP="$beatmap" \
DANCE_WORDS="$words" \
DANCE_CUES="$cues" \
"$app" >"$tmpdir/app.log" 2>&1 &
app_pid="$!"

for _ in {1..400}; do
  if [[ -f "$ready_file" ]]; then
    break
  fi
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App exited before it became ready:" >&2
    cat "$tmpdir/app.log" >&2 || true
    exit 1
  fi
  sleep 0.1
done
if [[ ! -f "$ready_file" ]]; then
  echo "Timed out waiting for the render window to become ready" >&2
  cat "$tmpdir/app.log" >&2 || true
  exit 1
fi

touch "$start_file"
sleep "$app_preroll"

ffmpeg \
  -y \
  -thread_queue_size 1024 \
  -f x11grab \
  -video_size "${render_width}x${render_height}" \
  -framerate "$fps" \
  -draw_mouse 0 \
  -i "${display}.0+0,0" \
  -ss "$start" \
  -t "$duration" \
  -i "$audio" \
  -map 0:v:0 \
  -map 1:a:0 \
  -vf "trim=start=${capture_preroll}:duration=${duration},setpts=PTS-STARTPTS,scale=${width}:${height}:flags=lanczos" \
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
  "$out"

echo "wrote $out"
