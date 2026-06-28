---
name: scenery-art-layer-prep
description: "Prepare generated or hand-painted scenery art for layered Flutter backdrops: full-frame PNG plates, alpha masks, cloud/wave isolation, OpenCV cleanup, runtime stacking, parallax validation, and visual QA. Use when Codex needs to split a base backdrop into aligned layers, refine masks, make clouds/water independently movable, debug drifting building pixels, or document the asset-prep side of a scenery change."
---

# Scenery Art Layer Prep

Turns one good full-frame scene plate into stackable runtime assets without
coordinate drift. The current repo pipeline lives in `tools/scenery_art/` and
feeds `lib/features/scenery/`.

## Rules

- Keep one native coordinate space. Current scenery art is `2560x1440`.
- Do not crop runtime layers. Every output plate must be full-frame and line up
  by pixel coordinate alone.
- Treat the master plate as immutable. Generated assets are derived from it.
- Use alpha plates for movable/occluding elements. Avoid separate positioning
  metadata unless the runtime already has it.
- Visual QA before claiming success. Inspect the generated stack and at least
  one motion preview.
- Full restart the Flutter app after regenerating PNG assets. Hot reload can
  keep cached image bytes.

## Main Workflow

1. **Identify the art contract.** Read `lib/features/scenery/README.md`,
   `tools/scenery_art/README.md`, `lib/features/scenery/model/scenery_assets.dart`,
   and `lib/features/scenery/model/backdrop_scene.dart`.

2. **Preserve or create the base plate.** If creating new art with a generative
   image model, make one high-quality full-frame base first. Do not try to stitch
   unrelated crops. If editing an existing scene, keep the exact canvas size.

3. **Build structure layers from masks.** Use full-frame masks for fixed
   occluders such as city, bridge, yacht, palms, foreground deck, or props:

   ```bash
   python3 tools/scenery_art/layer_from_masks.py \
     --master assets/scenery/blue_hour_master.png \
     --out-dir assets/scenery \
     --preview-dir tmp/scenery_work \
     --layer city_bridge=tools/scenery_art/scenes/blue_hour_waterfront/masks/city_bridge.png \
     --layer yacht=tools/scenery_art/scenes/blue_hour_waterfront/masks/yacht.png \
     --layer foreground=tools/scenery_art/scenes/blue_hour_waterfront/masks/foreground.png
   ```

4. **Extract moving atmosphere.** For the current blue-hour scene, use OpenCV:

   ```bash
   python3 -m venv /tmp/lotti-scenery-opencv
   /tmp/lotti-scenery-opencv/bin/python -m pip install -r tools/scenery_art/requirements.txt
   make -C tools/scenery_art PYTHON=/tmp/lotti-scenery-opencv/bin/python blue-hour
   ```

   This generates `blue_hour_cloudless.png`, `clouds_far.png`,
   `clouds_mid.png`, and `clouds_near.png`.

5. **Validate layer order.** Runtime order should usually be:

   ```text
   cloudless base -> moving clouds -> water shader -> fixed city/bridge
   -> fixed yacht -> additive lights -> fixed foreground -> dancers/vignette
   ```

   Fixed structure must be redrawn above moving cloud/water layers so buildings
   and yacht edges do not drift.

6. **Run targeted scenery checks.**

   ```bash
   fvm flutter analyze lib/features/scenery lib/features/character/demo/character_dance_to_track_demo.dart
   fvm flutter test test/features/scenery/runtime/scenery_shaders_test.dart \
     test/features/scenery/layers/cloud_parallax_layer_test.dart \
     test/features/scenery/model/backdrop_scene_test.dart \
     test/features/scenery/scenery_assets_test.dart
   ```

## Visual QA Checklist

Inspect these after regeneration:

- `tmp/scenery_work/cloud_mask_preview.png`: no obvious city, yacht, deck, or
  palm pixels should be marked as moving cloud.
- `tmp/scenery_work/blue_hour_cloudless.png`: no blocky scars in open sky.
- `tmp/scenery_work/clouds_recomposed.png`: close to the master before motion.
- Runtime or offline preview at two distant times: bright clouds should move
  clearly; darker cloud bodies should move subtly; skyline chunks should not
  move.

## Common Failures

- **Buildings move with clouds:** the cloud mask or repaired cloud source still
  contains structure pixels. Tighten structure exclusions or repair RGB under
  occluders.
- **Clouds have building-shaped holes:** alpha was cut out under occluders but
  not repaired near the cloud mass.
- **Dark clouds look static:** too much of the body remains baked into the base,
  or far-layer opacity/speed is too low.
- **Open sky has ugly inpaint scars:** the erase/stencil mask is too broad. Keep
  broad dark bodies as low-alpha overlays and inpaint only confident highlights.
- **Runtime still shows old assets:** restart the app; hot reload can cache PNGs.

## See Also

- `cinematic-render-panel` for scoring final rendered art.
- `flutter-shader-validation` for shader compile/runtime issues in scenery.
