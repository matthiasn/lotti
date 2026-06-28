# scenery_art

Reusable helpers for turning one generated scene plate plus full-frame masks into
stackable Flutter backdrop assets.

The intended workflow is:

1. Generate or paint one full-frame master plate.
2. Generate or paint same-size black/white masks for semantic regions.
3. Run `layer_from_masks.py` to create PNG layers whose RGB pixels come from the
   master and whose alpha comes from each mask.
4. Run `isolate_clouds.py` to lift the master's cloud pixels into same-size
   transparent PNGs and inpaint a cloudless base plate under them.

That keeps every layer in the same coordinate system. Runtime code can always draw
the full master as the base layer, then use derived layers only for independent
effects: foreground occlusion, city light anchors, yacht lights, shader masks, or
debug review.

```sh
make blue-hour
```

`isolate_clouds.py` uses OpenCV for the art-build step. If OpenCV is not
installed in the system Python, run the target through a venv:

```sh
python3 -m venv /tmp/lotti-scenery-opencv
/tmp/lotti-scenery-opencv/bin/python -m pip install -r tools/scenery_art/requirements.txt
make -C tools/scenery_art PYTHON=/tmp/lotti-scenery-opencv/bin/python blue-hour
```

or directly:

```sh
python3 tools/scenery_art/layer_from_masks.py \
  --master assets/scenery/blue_hour_master.png \
  --out-dir assets/scenery \
  --preview-dir tmp/scenery_work \
  --layer city_bridge=tools/scenery_art/scenes/blue_hour_waterfront/masks/city_bridge.png \
  --layer yacht=tools/scenery_art/scenes/blue_hour_waterfront/masks/yacht.png \
  --layer foreground=tools/scenery_art/scenes/blue_hour_waterfront/masks/foreground.png
```

The cloud tool writes:

- `assets/scenery/blue_hour_cloudless.png` — the master plate with cloud-mask
  pixels inpainted out of the sky.
- `assets/scenery/clouds_far.png`
- `assets/scenery/clouds_mid.png`
- `assets/scenery/clouds_near.png`

The cloud PNGs keep the exact source RGB pixels and only change alpha. Runtime
parallax can therefore move the painted clouds independently without stitching
different source images together.

Masks may be any RGB/RGBA/L image. Bright pixels become opaque, dark pixels
transparent; midtones are stretched into antialiased alpha.

## Scene sources

`scenes/blue_hour_waterfront/masks/` stores the current mask sources for the
generated Lagos blue-hour plate. The base RGB source is
`assets/scenery/blue_hour_master.png`, and `make blue-hour` regenerates the
stackable structure layers from that master plus these masks. Cloud layers are
derived directly from the master by local luma-contrast detection, colour gates,
and the generated structure alpha layers as exclusions.

Preview images are written to `tmp/scenery_work/` so they do not get bundled as
Flutter runtime assets.
