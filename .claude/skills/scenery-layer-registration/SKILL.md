---
name: scenery-layer-registration
description: Verify, regenerate, and debug full-frame scenery masks and alpha layers against a single master plate. Use when derived backdrop layers, masks, moving clouds, aircraft, drones, reflections, or other animated scenery appear shifted, clipped, ghosted, deregistered, or incorrectly occluded; use before claiming visual fixes to layer alignment.
---

# Scenery Layer Registration

Use this skill for scenery/backdrop work where every mask and runtime asset must
share one native coordinate space. In this repo the blue-hour waterfront source
space is `2560x1440`; masks and stackable layers must be full-frame, never
cropped, and aligned by coordinates alone.

## Non-Negotiables

- Treat registration as binary: aligned or not aligned.
- Never fix registration by moving the subject until it looks acceptable.
- Never crop a layer/mask to its visible content. Runtime stacking depends on
  exact same-size plates.
- Source-space proof comes first: master plate + mask/layer overlay at native
  coordinates.
- Runtime proof comes second: exact timestamp/frame screenshot from the same
  harness the user is inspecting.
- Do not claim fixed from intuition. Inspect the generated PNG/crop.

## Workflow

1. Identify the master plate and every derived layer/mask involved.
   For the current scene:
   - `assets/scenery/blue_hour_master.webp`
   - `tools/scenery_art/scenes/blue_hour_waterfront/masks/*.png`
   - `assets/scenery/*.webp`

2. Run the registration probe before editing:

   ```sh
   python3 .claude/skills/scenery-layer-registration/scripts/registration_probe.py \
     --master assets/scenery/blue_hour_master.webp \
     --layer assets/scenery/city_bridge.webp \
     --mask tools/scenery_art/scenes/blue_hour_waterfront/masks/city_bridge.png \
     --crop 430,260,700,440 \
     --jet-time 41.388 \
     --out-dir tmp/scenery_work/registration_probe
   ```

   Inspect the output overlay/crop. If a real source object is visible in the
   master but absent from the mask, the mask is incomplete. If the mask covers a
   non-existing object, the mask is ghosted. If the mask shape is shifted from
   the source object, the mask is deregistered.

3. Recreate faulty masks from the master, preferably with deterministic image
   processing. Use OpenCV at build time, not in the app:

   ```sh
   python3 -m venv /tmp/lotti-scenery-opencv
   /tmp/lotti-scenery-opencv/bin/python -m pip install \
     -r tools/scenery_art/requirements.txt
   ```

   Segment in native `2560x1440` coordinates. Write the mask as a full-frame
   grayscale PNG. Save a red overlay preview over the master and inspect it.

4. Bake runtime layers from the full-frame masks:

   ```sh
   python3 tools/scenery_art/layer_from_masks.py \
     --master assets/scenery/blue_hour_master.webp \
     --out-dir assets/scenery \
     --preview-dir tmp/scenery_work \
     --layer city_bridge=tools/scenery_art/scenes/blue_hour_waterfront/masks/city_bridge.png \
     --layer yacht=tools/scenery_art/scenes/blue_hour_waterfront/masks/yacht.png \
     --layer foreground=tools/scenery_art/scenes/blue_hour_waterfront/masks/foreground.png
   python3 tools/scenery_art/bake_city_windows.py
   python3 tools/scenery_art/inspect_layers.py
   ```

   If cloud assets depend on the structure masks, rerun the full blue-hour
   target with the OpenCV Python:

   ```sh
   make -C tools/scenery_art \
     PYTHON=/tmp/lotti-scenery-opencv/bin/python blue-hour
   ```

5. Render the exact problem timestamp, not a nearby approximation. For the dance
   export harness:

   ```sh
   rm -rf build/character_video_exports/exact_check_frames
   DANCE_EXPORT=1 \
   DANCE_EXPORT_WIDTH=1600 \
   DANCE_EXPORT_HEIGHT=900 \
   DANCE_EXPORT_FPS=60 \
   DANCE_EXPORT_START=41.388 \
   DANCE_EXPORT_DURATION=0.017 \
   DANCE_EXPORT_KEEP_FRAMES=1 \
   DANCE_EXPORT_CAPTIONS=0 \
   DANCE_EXPORT_X264_PRESET=ultrafast \
   DANCE_EXPORT_OUT=build/character_video_exports/exact_check.mp4 \
   fvm flutter test test/features/character/dance_video_export_test.dart
   ```

   Inspect `build/character_video_exports/exact_check_frames/000000.png` and a
   crop around the issue.

6. Only after visual proof, run focused checks:

   ```sh
   fvm flutter test test/features/scenery/scenery_assets_test.dart
   fvm flutter test test/features/scenery/layers/distant_jet_layer_test.dart
   fvm flutter analyze lib/features/scenery test/features/scenery
   ```

## Debugging Rules

- If an object appears in the master but not in the alpha mask, regenerate the
  mask. Do not add a one-off runtime exception unless the art contract changes.
- If an alpha mask contains objects that do not exist in the master, remove them
  at the mask-generation source. Do not compensate with opacity or draw order.
- If a moving object should be behind a fixed structure, prove the structure
  alpha exists at the moving object's source-space footprint before touching
  z-order.
- If the live app and export differ, use the export/test harness first. Do not
  run the GUI app just to inspect frames unless the user asks.
- If a helper command fails because `cv2` is missing, install/use the documented
  `/tmp/lotti-scenery-opencv` venv and rerun the same command.

## Helper Script

`scripts/registration_probe.py` validates layer/mask dimensions and writes:

- full-frame red alpha overlays over the master;
- optional scaled crops for issue inspection;
- optional source-space 747 footprint at a timestamp, matching the current
  `DistantJetLayer` constants.

Use it to create evidence before and after changes.
