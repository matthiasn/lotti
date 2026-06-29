#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export the beat-synced character showcase to MP4 without running the app.

Usage:
  tools/character_video_export/export_dance_video.sh [options]

Options:
  --preset 1080p|720p       Output size preset (default: 1080p)
  --width PX                Override output width (must be even)
  --height PX               Override output height (must be even)
  --fps N                   Frames per second (default: 60)
  --start SEC               Audio start time in seconds (default: 0)
  --duration SEC            Export duration; omit/0 for rest of track
  --out PATH                Output MP4 path
  --audio PATH              Audio file path
  --beatmap PATH            Beat-map JSON path
  --words PATH              Optional synced words JSON path
  --cues PATH               Optional Rhubarb cues JSON path
  --crf N                   x264 CRF, lower is better/larger (default: 18)
  --audio-kbps N            AAC bitrate in kbps (default: 320)
  --x264-preset NAME        x264 preset (default: slow)
  --keep-frames             Keep rendered PNG frames beside the MP4
  --captions                Burn lyric captions into the video
  --no-captions             Do not burn lyric captions into the video (default)
  -h, --help                Show this help

Examples:
  tools/character_video_export/export_dance_video.sh --preset 1080p --fps 60
  tools/character_video_export/export_dance_video.sh --preset 720p --duration 30
  tools/character_video_export/export_dance_video.sh --start 80 --duration 12 --out build/hook.mp4
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
audio=""
beatmap=""
words=""
cues=""
crf="18"
audio_kbps="320"
x264_preset="slow"
keep_frames="0"
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
    --keep-frames)
      keep_frames="1"
      shift
      ;;
    --captions)
      captions="1"
      shift
      ;;
    --no-captions)
      captions="0"
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
  out="build/character_video_exports/dance_${width}x${height}_${fps}fps.mp4"
fi

export DANCE_EXPORT=1
export DANCE_EXPORT_WIDTH="$width"
export DANCE_EXPORT_HEIGHT="$height"
export DANCE_EXPORT_FPS="$fps"
export DANCE_EXPORT_START="$start"
export DANCE_EXPORT_DURATION="$duration"
export DANCE_EXPORT_OUT="$out"
export DANCE_EXPORT_CRF="$crf"
export DANCE_EXPORT_AUDIO_KBPS="$audio_kbps"
export DANCE_EXPORT_X264_PRESET="$x264_preset"
export DANCE_EXPORT_KEEP_FRAMES="$keep_frames"
export DANCE_EXPORT_CAPTIONS="$captions"

if [[ -n "$audio" ]]; then
  export DANCE_AUDIO="$audio"
fi
if [[ -n "$beatmap" ]]; then
  export DANCE_BEATMAP="$beatmap"
fi
if [[ -n "$words" ]]; then
  export DANCE_WORDS="$words"
fi
if [[ -n "$cues" ]]; then
  export DANCE_CUES="$cues"
fi

fvm flutter test \
  test/features/character/dance_video_export_test.dart \
  --plain-name 'exports beat-synced dance video'
