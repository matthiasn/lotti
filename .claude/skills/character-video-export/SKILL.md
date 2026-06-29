---
name: character-video-export
description: Export the beat-synced character dance showcase to a verified MP4 with synced AAC audio using the repo's realtime Xwayland exporter, release-app exact-frame exporter, or Flutter-test fallback and ffmpeg. Use when the user wants a 1920x1080 or 1280x720 video for YouTube/Apple playback, a command-line render, an audio-synced capture, or one MP4 file instead of a live-app screen recording.
---

# Character Video Export

MP4 export for the character dance demo. There are four paths:

- **Fast 1080p60 path:** realtime rootful-Xwayland capture through
  `export_dance_video_realtime.sh`. Use this when the user needs a full
  1080p60 MP4 in minutes on the VM. It renders the app at 1440x810, captures at
  60 fps from a fake-60 Hz Xwayland display, trims a 1s capture preroll, upscales
  to 1920x1080, and muxes AAC audio. Verify cadence with frame hashes afterward.
- **Exact path:** release-app deterministic raw-frame rendering through
  `export_dance_video_app.sh`. Use this when absolute frame-exact readback is
  more important than speed. Full 1080p60 can take far longer than realtime on
  this VM because every frame is read back from Flutter.
- **Software fallback:** deterministic raw-frame rendering through
  `export_dance_video.sh`. Use this only when the release app path is not
  available; it runs through `flutter_test` software rendering and is much
  slower.
- **Preview path:** real-time Xvfb capture through
  `export_dance_video_capture.sh`. Use this only for quick review clips where
  occasional capture cadence jitter is acceptable.

Prefer the realtime wrapper when the user asks for a full 1080p60 export in a
reasonable time:

```bash
tools/character_video_export/export_dance_video_realtime.sh
```

It builds/runs the release Linux demo in render-only mode inside temporary
rootful Xwayland, waits for the layered backdrop to report a resource-complete
frame, prerolls the app, captures a trimmed X11 stream with `ffmpeg`, and muxes
the selected audio as AAC. Captions are off by default.

Use the deterministic wrapper when the user asks for exact frame-indexed
readback and accepts a much slower render:

```bash
tools/character_video_export/export_dance_video_app.sh
```

It builds/runs the release Linux demo in export mode, steps exact frame indices,
captures the stage `RepaintBoundary`, streams raw RGBA frames to `ffmpeg`, and
muxes the selected audio as AAC. `Xvfb` is only an offscreen render surface;
ffmpeg does not screen-capture it. Captions are off by default for clean
music-video exports; pass `--captions` only when burned-in lyrics are wanted.

Use the software fallback only if the app path is broken:

```bash
tools/character_video_export/export_dance_video.sh
```

Use the real-time capture wrapper only for fast preview:

```bash
tools/character_video_export/export_dance_video_capture.sh
```

It builds/runs the release Linux demo in render-only mode, captures the X display
with `ffmpeg`, and muxes the selected audio segment as AAC. Captions are off by
default for clean music-video exports; pass `--captions` only when burned-in
lyrics are wanted.
Because it is wall-clock screen capture, it can report `dup=`/`drop=` in ffmpeg
progress and is not cadence-safe. Do not use it for master exports.

## Contract

- Do not run the ordinary interactive desktop app unless the user explicitly
  asks. The realtime exporter uses a temporary rootful Xwayland display window;
  keep it short for smoke tests and clean it up on exit.
- Use `fvm` for Flutter commands.
- Do not say the export is done unless the MP4 file exists and `ffprobe`
  confirms video + audio properties.
- If ffmpeg reports duplicated or dropped frames in a realtime/capture export,
  inspect content hashes. A timestamp-side `dup=` can still produce unique
  rendered frames after trim/upscale, but repeated full-color frame hashes mean
  the file is not a cadence-clean master.
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
   command -v Xwayland
   command -v Xvfb
   ```

3. Inspect the wrapper help and current defaults:

   ```bash
   tools/character_video_export/export_dance_video_realtime.sh --help
   tools/character_video_export/export_dance_video_app.sh --help
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

Run a 5s 1080p60 inspection clip through the realtime Xwayland path:

```bash
tools/character_video_export/export_dance_video_realtime.sh \
  --preset 1080p \
  --fps 60 \
  --start 80 \
  --duration 5 \
  --out build/character_video_exports/dance_realtime_smoke_1080p60.mp4 \
  --x264-preset ultrafast \
  --crf 23
```

This requires `Xwayland`. If it is missing, use the slow exact path or install
the missing tool; do not fall back silently to an ordinary visible app window.

Verify the smoke's content cadence:

```bash
ffmpeg -v error -i build/character_video_exports/dance_realtime_smoke_1080p60.mp4 \
  -map 0:v:0 -an -vf "scale=480:-1,format=rgb24" -f framemd5 - |
  awk 'BEGIN{prev="";same=0;maxrun=0;run=0;n=0}
    /^0,/ {hash=$NF; n++; if(hash==prev){same++; run++} else {if(run>maxrun) maxrun=run; run=0} prev=hash}
    END{if(run>maxrun) maxrun=run; print "frames=" n, "same=" same, "maxrun=" maxrun}'
```

Expected for a clean 5s smoke at 60 fps: `frames=300 same=0 maxrun=0`.

For a tiny codec smoke of the release-app exact exporter:

```bash
tools/character_video_export/export_dance_video_app.sh \
  --width 320 \
  --height 180 \
  --fps 10 \
  --duration 0.5 \
  --out build/character_video_exports/smoke_app.mp4 \
  --x264-preset ultrafast
```

For a tiny codec smoke of the software fallback:

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
tools/character_video_export/export_dance_video_realtime.sh \
  --preset 1080p \
  --fps 60 \
  --start 80 \
  --duration 12 \
  --out build/character_video_exports/dance_hook_1080p60_fast.mp4
```

Full 1080p track:

```bash
tools/character_video_export/export_dance_video_realtime.sh \
  --preset 1080p \
  --fps 60 \
  --out build/character_video_exports/dance_full_1080p60_fast.mp4
```

Fast 720p review export:

```bash
tools/character_video_export/export_dance_video_capture.sh \
  --preset 720p \
  --fps 30 \
  --duration 30 \
  --out build/character_video_exports/dance_review_720p.mp4
```

All exporters encode with H.264 High profile, `yuv420p`, BT.709 tags,
`+faststart`, and AAC audio. Defaults are CRF 18 and 320 kbps audio.

## Verify The Deliverable

For a final 1080p upload file, verify at least:

```bash
out=build/character_video_exports/dance_1920x1080_60fps_master.mp4

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
bash -n tools/character_video_export/export_dance_video_app.sh
bash -n tools/character_video_export/export_dance_video_realtime.sh
bash -n tools/character_video_export/export_dance_video_capture.sh
bash -n tools/character_video_export/export_dance_video.sh
fvm flutter analyze \
  lib/features/scenery/layered_backdrop.dart \
  lib/features/character/demo/character_dance_to_track_demo.dart \
  test/features/scenery/layered_backdrop_test.dart \
  test/features/character/dance_video_export_test.dart
```

Then rerun the smoke export and `ffprobe` checks. Do not run the full test suite
for this skill unless the user asks or the code change has broad impact.

## Performance Notes

- Full 1080p exports through `flutter test` software rendering are far slower
  than real time. Use the realtime Xwayland wrapper for speed.
- The release-app exact exporter is slower than realtime on the VM because each
  frame still requires render readback, but it avoids X11 capture dup/drop and
  is much faster than the software fallback.
- On this VM, the verified fast setting is 1440x810 realtime capture upscaled to
  1920x1080. Capturing 1920x1080 directly or using Xvfb has produced visible
  repeated frames.
- The capture wrapper needs `Xvfb` for non-disruptive offscreen rendering. If it
  is missing and sudo is unavailable, the fast requirement is not yet verifiable
  on that machine.
- `--x264-preset ultrafast` is for smoke/proof only; use `medium`, `slow`, or
  the wrapper default for deliverables.
- 60 fps doubles frame count versus 30 fps. Use it only when motion quality
  justifies the render time.
- Full 1080p60 release-app exact exports can take around 1-2 hours on the VM.
  This is expected: the tradeoff is exact frame indexing with no wall-clock
  capture dup/drop.
- If an export is cancelled, remove partial MP4s before reporting results.

## See Also

- `dance-track-prep` for preparing beat maps, sections, waveform, and lyrics.
- `dance-lipsync` for Rhubarb mouth-shape cue generation.
- `character-motion-review-panel` for judging rendered motion quality before
  committing to a long export.
