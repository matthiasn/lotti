---
name: character-video-export
description: Export the beat-synced character dance showcase to a verified MP4 with synced AAC audio using the repo's Flutter-test renderer and ffmpeg. Use when the user wants a 1920x1080 or 1280x720 video for YouTube/Apple playback, a command-line render, an audio-synced capture, or one MP4 file instead of a live-app screen recording.
---

# Character Video Export

MP4 export for the character dance demo. Prefer the real-time capture wrapper:

```bash
tools/character_video_export/export_dance_video_capture.sh
```

It builds/runs the release Linux demo in render-only mode, captures the X display
with `ffmpeg`, and muxes the selected audio segment as AAC. Captions are off by
default for clean music-video exports; pass `--captions` only when burned-in
lyrics are wanted.

Use the deterministic fallback wrapper only when exact offscreen frames matter
more than speed:

```bash
tools/character_video_export/export_dance_video.sh
```

That fallback runs `test/features/character/dance_video_export_test.dart`,
renders Flutter frames through the software test engine, streams raw RGBA frames
to `ffmpeg`, and muxes the selected audio as AAC. It is very slow at 1080p.

## Contract

- Do not run the visible desktop app unless the user explicitly asks. The fast
  path should use `Xvfb` for an offscreen X display.
- Use `fvm` for Flutter commands.
- Do not say the export is done unless the MP4 file exists and `ffprobe`
  confirms video + audio properties.
- If only the exporter/tooling was created or changed, say that clearly; that is
  not the same as producing the requested video artifact.
- Keep audio, lyrics, beat maps, cue JSON, and rendered videos out of git unless
  the user explicitly asks otherwise. Put outputs under `build/`.
- Do not use `--keep-frames` by default. It can consume a lot of disk; the
  exporter normally streams raw frames directly to `ffmpeg`.

## Before Exporting

1. Read `test/README.md`.
2. Check required tools:

   ```bash
   command -v ffmpeg
   command -v ffprobe
   command -v Xvfb
   ```

3. Inspect the wrapper help and current defaults:

   ```bash
   tools/character_video_export/export_dance_video_capture.sh --help
   tools/character_video_export/export_dance_video.sh --help
   ```

   If the default audio or beat-map paths are stale, pass explicit `--audio`,
   `--beatmap`, `--words`, and `--cues` paths. Use `dance-track-prep` and
   `dance-lipsync` if those song artifacts need to be generated first.

4. Check disk before long renders:

   ```bash
   df -h .
   ```

5. If a prior export was interrupted, check for stale exporter processes before
   starting another run. Do not kill unrelated user processes.

   ```bash
   pgrep -af 'flutter_tester|ffmpeg' || true
   ```

## Fast Smoke Test

Run a 20s 1080p inspection clip through the real-time capture path:

```bash
tools/character_video_export/export_dance_video_capture.sh \
  --preset 1080p \
  --fps 30 \
  --start 80 \
  --duration 20 \
  --out build/character_video_exports/dance_20s_fast.mp4
```

This requires `Xvfb`. If `Xvfb` is missing, do not fall back silently to the
visible desktop; either install `xvfb` or use the slow deterministic fallback and
clearly report that the speed requirement is not met on this machine.

For a tiny codec smoke of the deterministic fallback:

```bash
tools/character_video_export/export_dance_video.sh \
  --width 320 \
  --height 180 \
  --fps 10 \
  --duration 0.5 \
  --out build/character_video_exports/smoke.mp4 \
  --x264-preset ultrafast
```

Verify the smoke output:

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,color_space,color_transfer,color_primaries \
  -of default=noprint_wrappers=1 build/character_video_exports/smoke.mp4

ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,sample_rate,channels \
  -of default=noprint_wrappers=1 build/character_video_exports/smoke.mp4
```

Expected shape: H.264 video, `yuv420p`, BT.709 color tags, and AAC audio at
48 kHz. The exact dimensions and frame rate should match the requested smoke
settings.

## Export Commands

Use 30 fps unless the user specifically asks for 60 fps.

Short 1080p clip:

```bash
tools/character_video_export/export_dance_video_capture.sh \
  --preset 1080p \
  --fps 30 \
  --start 80 \
  --duration 12 \
  --out build/character_video_exports/dance_hook_1080p.mp4
```

Full 1080p track:

```bash
tools/character_video_export/export_dance_video_capture.sh \
  --preset 1080p \
  --fps 30 \
  --duration 144 \
  --out build/character_video_exports/dance_1920x1080_30fps.mp4
```

Fast 720p review export:

```bash
tools/character_video_export/export_dance_video_capture.sh \
  --preset 720p \
  --fps 30 \
  --duration 30 \
  --out build/character_video_exports/dance_review_720p.mp4
```

Both exporters encode with H.264 High profile, `yuv420p`, BT.709 tags,
`+faststart`, and AAC audio. Defaults are CRF 18 and 320 kbps audio.

## Verify The Deliverable

For a final 1080p upload file, verify at least:

```bash
out=build/character_video_exports/dance_1920x1080_30fps.mp4

test -s "$out"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,color_space,color_transfer,color_primaries \
  -of default=noprint_wrappers=1 "$out"

ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,sample_rate,channels \
  -of default=noprint_wrappers=1 "$out"

ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$out"
```

Acceptance for a YouTube/Apple-friendly 1080p export:

- `codec_name=h264`
- `width=1920`
- `height=1080`
- `pix_fmt=yuv420p`
- `color_space=bt709`, `color_transfer=bt709`, `color_primaries=bt709`
- `codec_name=aac`
- `sample_rate=48000`
- nonzero duration matching the requested clip or track window

## If You Change The Exporter

Run focused checks:

```bash
bash -n tools/character_video_export/export_dance_video_capture.sh
bash -n tools/character_video_export/export_dance_video.sh
fvm flutter analyze \
  lib/features/character/demo/character_dance_to_track_demo.dart \
  test/features/character/dance_video_export_test.dart
```

Then rerun the smoke export and `ffprobe` checks. Do not run the full test suite
for this skill unless the user asks or the code change has broad impact.

## Performance Notes

- Full 1080p exports through `flutter test` software rendering are far slower
  than real time. Use the capture wrapper for deliverables.
- The capture wrapper needs `Xvfb` for non-disruptive offscreen rendering. If it
  is missing and sudo is unavailable, the fast requirement is not yet verifiable
  on that machine.
- `--x264-preset ultrafast` is for smoke/proof only; use `medium`, `slow`, or
  the wrapper default for deliverables.
- 60 fps doubles frame count versus 30 fps. Use it only when motion quality
  justifies the render time.
- If an export is cancelled, remove partial MP4s before reporting results.

## See Also

- `dance-track-prep` for preparing beat maps, sections, waveform, and lyrics.
- `dance-lipsync` for Rhubarb mouth-shape cue generation.
- `character-motion-review-panel` for judging rendered motion quality before
  committing to a long export.
