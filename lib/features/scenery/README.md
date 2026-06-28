# Scenery

Reusable animated backdrops for character/demo surfaces. The current production
scene is the Lagos-inspired blue-hour waterfront used by
`CharacterDanceToTrackDemo`: a generated bitmap plate split into full-frame PNG
layers, with shader and canvas effects composited between those layers.

The module is deliberately independent from `features/character`. Consumers pass
a clock and optional child into `LayeredBackdrop`; scenery code owns image/shader
loading, reduced-motion handling, and layer composition.

## Runtime Architecture

```mermaid
flowchart TD
  demo[CharacterDanceToTrackDemo] -->|audio position seconds| lb[LayeredBackdrop]
  self[Standalone use] -->|null timeSeconds| lb
  lb --> loader[async loaders]
  loader --> imgs[decoded ui.Image assets]
  loader --> shaders[FragmentProgram cache]
  lb --> painter[_BackdropPainter]
  painter --> ctx[BackdropContext]
  ctx --> layers[BackdropLayer stack]
  imgs --> ctx
  shaders --> ctx
  layers --> canvas[Canvas]
```

`LayeredBackdrop` has two clock modes:

- External clock: pass `timeSeconds`, used by the audio dance player so scenery
  seeks, pauses, and resumes with playback.
- Self clock: leave `timeSeconds` and `timeOverride` null; the widget starts its
  own `Ticker`.

`MediaQuery.disableAnimationsOf(context)` freezes the scene at
`kSceneryCalmFrameSeconds`. Tests can pin `timeOverride`.

## Layer Stack

`BackdropScene.blueHourWaterfront()` defines the current stack. Every bitmap is
authored at `kSceneryCanvasSize` (`2560x1440`) and cover-fit into the viewport.
The same cover-fit mapping is used by bitmap layers, cloud drift, ocean band
placement, and city/yacht light sampling.

```mermaid
flowchart BT
  child[Dancers / caller child]
  vignette[VignetteLayer foreground]
  glow[DeckGlowLayer]
  fg[foreground.png]
  lights[CityLightsLayer]
  yacht[yacht.png]
  city[city_bridge.png]
  ocean[OceanLayer shader/fallback]
  drones[DroneShowLayer]
  near[clouds_near.png parallax]
  mid[clouds_mid.png parallax]
  far[clouds_far.png parallax]
  base[blue_hour_cloudless.png]

  base --> far --> mid --> near --> drones --> ocean --> city --> yacht --> lights --> fg --> glow --> child --> vignette
```

The ordering is the important contract:

- The base is `blue_hour_cloudless.png`, not the original master plate.
- Clouds are reintroduced as transparent full-frame PNGs and drift with
  `CloudParallaxLayer`.
- `DroneShowLayer` paints additive sky lights after clouds but before the
  animated water and fixed structure redraw. Its final formation spells
  `Omah Lay`.
- `OceanLayer` adds animated foam/glint over the painted lagoon.
- `city_bridge.png` and `yacht.png` are redrawn after the moving
  clouds/drones/ocean so clouds, drones, and foam never slide across solid
  structure.
- `CityLightsLayer` draws additive windows, yacht lamps, and beacon glows on top
  of the structure layers.
- `foreground.png` and `DeckGlowLayer` sit over the animated water/deck area.
- Foreground layers, currently the vignette, paint over the caller child.

## Bitmap Assets

`SceneryAssets` names the runtime assets:

- `blue_hour_master.png`: immutable full-frame source plate.
- `blue_hour_cloudless.png`: source plate with selected cloud pixels removed or
  blended toward sky color.
- `clouds_far.png`, `clouds_mid.png`, `clouds_near.png`: exact-size transparent
  cloud plates derived from the master. They are not cropped.
- `city_bridge.png`, `yacht.png`, `foreground.png`: structure/occluder layers
  cut from same-size masks.
- `city_windows.png`: sampled window field used by `CityLightsLayer`.

Full-frame assets are intentional. Cropping would require independent alignment
metadata and creates visible drift errors when layers are cover-fit at different
viewport ratios.

## Cloud Parallax

`CloudParallaxLayer` shifts one full-frame transparent cloud plate horizontally
and wraps it with three draws (`-1`, `0`, `+1` art widths). The movement is
one-way and cyclic. `dxPerSecond` is a fraction of the cover-fitted art width per
second; `0.001` equals 12% of the art width over a two-minute track.

Vertical motion is a very small sine "breathing" offset. Cloud bands use
different phases and speeds:

- Far/dark upper clouds: subtle but now visible motion.
- Mid clouds: slightly faster.
- Near/bright cloud details: most visible motion.

The current asset extraction keeps the left skyline-adjacent cloud band mostly
baked into the base. That is a deliberate quality tradeoff: those clouds overlap
tall tower silhouettes in the source art, and moving them independently makes
building-shaped artifacts read as drifting architecture.

## Shader And Canvas Layers

`SceneryShaderProgramCache` loads:

- `scenery_sky.frag`: procedural fallback scene for
  `BackdropScene.proceduralBlueHour()`.
- `scenery_ocean.frag`: additive lagoon foam and glint.
- `scenery_city_lights.frag`: additive window and yacht-cabin lighting.

Shader load failure is non-fatal. Layers either use CPU fallback rendering or
no-op until their programs/assets load.

`CityLightsLayer` also paints canvas beacons and yacht lamps. It maps normalized
art anchors through `coverFit`, so lights stay attached to the painted structures
on desktop and phone aspect ratios.

## Drone Show

`layers/drone_show_layer.dart` is a deterministic background performance layer,
not a bitmap asset. It samples normalized drone positions from the scene clock
and paints additive glows in the sky. The current show is intentionally slow:
220 drones launch along the cable-stayed bridge deck over a 144-second cycle,
climb into a controlled beam, fan into the sky, then settle into a held
dot-matrix `Omah Lay` formation.

```mermaid
stateDiagram-v2
  [*] --> Launch
  Launch --> Beam: grouped ascent
  Beam --> Fan: vertical beam opens
  Fan --> Formation: spread into text points
  Formation --> Launch: loop wraps
```

The pure functions are the contract:

- `droneShowTimelineAt(timeSeconds)` resolves the current phase and local
  progress inside the repeatable loop.
- `droneShowFormationPoints()` generates the final text destination points for
  the denser dot-matrix `Omah Lay` formation.
- `sampleDroneShow(timeSeconds)` returns per-drone normalized positions,
  opacity, radius, and phase; reduced-motion samples a static formation frame.
  During formation, drones settle into the text early and then hold, so the
  lettering stays readable instead of morphing until the loop wraps.

The layer belongs behind the city/yacht redraw. That lets the launch read as
coming from the bridge area while solid painted structures still occlude the
lights naturally.

## Stage Lighting And Effects

The dance-to-track demo lights the trio like a stage act with a **graphic
rim/backlight** look (chosen because the cats are flat cartoon shapes — front-lit
colored cones read as glowing capsules, but a colored edge hugging the silhouette
reads as real backlight). One scheduler drives two halves so the body glow and
its floor pool always share a gel:

- **`runtime/stage_lights.dart` — `StageLightRig` (pure).** A deterministic,
  canvas-free scheduler: feed it the scene time + the 0..1 beat envelope and it
  returns each light's gel `color`, pool `targetX` and `intensity`. The gel cycle
  (warm gold / hot fuchsia / UV violet) **snaps** (never lerps) on a `colorPeriod`
  wired to the track tempo (`60 / bpm`), offset per lane so the row rotates R/G/B
  rather than flashing in unison; brightness is `baseIntensity + beatBoost * beat`.
- **The rim/halo is drawn by `CharacterPainter`** (`memberBacklights`, not in this
  module): each cat is rendered as a blurred, solid-gel silhouette behind itself
  (a soft bloom + a tight rim pass) so it ends up ringed in a crisp gel edge, with
  `bodyDim` dropping the front body into shadow so the rim wins. It reuses the
  member transform, so the halo tracks the dancer through any camera move.
- **`stage_lights_overlay.dart` — `StageLightsOverlay` / `StageLightsPainter`.**
  The grounding half: an additive (`BlendMode.plus`) screen-space pass over the
  dancers drawing a soft elliptical gel pool + hot core under each foot. It eases
  its pool toward the live dancer foot (lazy on small moves, fast catch-up on a
  camera cut), tracking the anchors the painter publishes via `onDancerAnchors`.

The demo samples the rig once per frame and feeds the gels to both halves, so the
whole rig pulses with the music. Reduce-motion freezes it to a calm static frame.

`runtime/stage_effects.dart` adds the event score for concert particles. It is
also pure and audio-clock-driven: `StageEffectCueBuilder` derives cues from beat
times, downbeats, and classified track sections, then `StageEffectScheduler`
samples only the active cues for the current playback position. The visual
language is deliberately stage-local:

- rear cold-spark fountains on energetic downbeats;
- side confetti cannons on hero section hits;
- bubble drift in calmer/bridge spans;
- warm ember fallout after sparks.

`stage_effects_overlay.dart` paints those samples over the dancers with
deterministic index-seeded motion. It does not import the design-system
celebration particles; the math is adapted locally so the character/scenery
showcase can be extracted without pulling the app celebration package with it.
Reduce-motion suppresses transient particles.

## Asset Preparation

The generated PNG stack lives under `assets/scenery/`; the tooling lives under
`tools/scenery_art/`.

```mermaid
flowchart LR
  master[blue_hour_master.png] --> masks[layer masks]
  masks --> layerer[layer_from_masks.py]
  layerer --> city[city_bridge.png]
  layerer --> yacht[yacht.png]
  layerer --> fg[foreground.png]
  master --> clouds[isolate_clouds.py]
  city --> clouds
  yacht --> clouds
  fg --> clouds
  clouds --> base[blue_hour_cloudless.png]
  clouds --> far[clouds_far.png]
  clouds --> mid[clouds_mid.png]
  clouds --> near[clouds_near.png]
```

Regenerate with:

```bash
python3 -m venv /tmp/lotti-scenery-opencv
/tmp/lotti-scenery-opencv/bin/python -m pip install -r tools/scenery_art/requirements.txt
make -C tools/scenery_art PYTHON=/tmp/lotti-scenery-opencv/bin/python blue-hour
```

Preview/debug outputs go to `tmp/scenery_work/` and are not runtime assets. See
`tools/scenery_art/README.md` for the mask-generation details and visual QA
checks.

## Tests

Focused checks for this feature:

```bash
fvm flutter analyze lib/features/scenery lib/features/character/demo/character_dance_to_track_demo.dart test/features/scenery/layers/cloud_parallax_layer_test.dart test/features/scenery/model/backdrop_scene_test.dart test/features/scenery/scenery_assets_test.dart
fvm flutter test test/features/scenery/runtime/scenery_shaders_test.dart test/features/scenery/runtime/stage_effects_test.dart test/features/scenery/stage_effects_overlay_test.dart test/features/scenery/layers/cloud_parallax_layer_test.dart test/features/scenery/layers/drone_show_layer_test.dart test/features/scenery/model/backdrop_scene_test.dart test/features/scenery/scenery_assets_test.dart
```

Coverage responsibilities:

- `backdrop_scene_test.dart`: layer order and declared assets.
- `scenery_assets_test.dart`: full-frame asset geometry and alpha sanity.
- `cloud_parallax_layer_test.dart`: deterministic offset/wrap math.
- `scenery_shaders_test.dart`: registered shader assets compile through Flutter's
  runtime-effect compiler.
- `runtime/stage_lights_test.dart`: the `StageLightRig` gel-cycle / sweep /
  beat-intensity maths.
- `stage_lights_overlay_test.dart`: the floor pools land their gel, track the
  dancer foot (lazy follow) and pulse on the beat.
- `runtime/stage_effects_test.dart`: cue derivation and deterministic active
  sample scheduling.
- `stage_effects_overlay_test.dart`: particle painters light expected pixels and
  honor reduce-motion.
- `drone_show_layer_test.dart`: drone timeline phases, final `Omah Lay`
  formation bounds, deterministic sampling, and paint contract.
