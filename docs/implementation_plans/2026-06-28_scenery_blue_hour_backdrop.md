# Blue-Hour Layered Waterfront Backdrop (audio-player scene)

> Status: in progress. Module scaffolding (`lib/features/scenery/`) + physics palette landed; sky shader / layer compositor / props / artwork integration follow the build order below. The companion **Codex artwork brief** is the last section — hand it to Codex to produce the bitmap layers.

## Context

The new **beat-synced audio player** `lib/features/character/demo/character_dance_to_track_demo.dart` (commit `7a6903dee`) plays a track with `media_kit`, pumps a 60 fps `Ticker` whose time comes from the audio position warped through `BeatMap.clipSecondsAt`, and renders the dancing cat via `CustomPaint(CharacterPainter(... backdrop: CharacterBackdrop.waterfront ...))` over a single **opaque** plate (`lagos_waterfront.png` + 2 scrolling alpha masks). That flat plate reads as cheap/lifeless.

We're replacing **just this player's** backdrop with a **reusable, layered, blue-hour cartoon scene**: multiple **transparent bitmap (PNG) layers** for the static structures (skyline tiers, bridge, yacht, foreground), with **GLSL shaders drawn in between** the bitmaps as needed (sky gradient + moon + stars + drifting clouds *behind* everything; water + foam + moon-glint *in front of* the structures, below the dancer), plus a cheap canvas layer for the "alive" signals (lit windows, blinking aircraft beacons, police sweeps on the bridge, a helicopter crossing, ships + a moored yacht with running lights). Because the clock is the audio position, the scene moves **with the music**, and `BeatMap` lets chosen elements pulse on the beat. Cartoonish but production-quality ("expensive animated feature establishing shot"), visually popping, grimy/lived-in, **not** photorealistic.

The scene subject is unchanged from today's plate: the **Lagos lagoon waterfront**, the **cable-stayed bridge**, **palms**, and a **luxury yacht** — reborn as a layered, animated, blue-hour version.

## Decisions locked (from the user)

- **Multiple transparent BITMAP (PNG) layers**, not SVG, not one flat plate. Shaders interleave between layers ("draw in between with shaders, on individual ones, layer as needed").
- **Codex builds the artwork layers** — a committed, regenerable generator that emits the transparent PNGs + art-matched manifest values. Detailed brief at the end. We build everything else. (Runtime only *loads* PNGs + manifest, so a hand-painted PNG set can later drop in over Codex's without code changes.)
- **Physics-guided palette** (blue-hour twilight optics), defined below — one tweakable source of truth; it art-directs both the shaders and the Codex bitmaps.
- **Grimy, not pristine** — weathered/lived-in, not shiny-new.
- **Reusable** — self-contained module `lib/features/scenery/` exposing one `LayeredBackdrop` widget; **only** the audio player is wired to it now. The old `CharacterBackdrop.waterfront` plate path is left fully intact (still used by the other demo + main dance). No enum/painter changes, no removals this pass.
- **Web out of scope** — shaders target native; keep only a lightweight CPU fallback as load-failure insurance.

## Division of labor

| Who | Builds |
|-----|--------|
| **Codex** (brief at end) | `tools/scenery_art/` generator → `assets/scenery/skyline_far.png`, `skyline_near.png`, `bridge.png`, `yacht.png`, optional `foreground.png` (transparent, colored per palette, mostly dark grimy silhouettes — **no baked windows/beacons**); art-matched values for `lib/features/scenery/model/skyline_manifest.dart` (the `SkylineManifest` type already exists); a preview screenshot. |
| **Us** | `lib/features/scenery/` framework + reusable `LayeredBackdrop` (interleaved bitmap/shader/props compositor); physics `BackdropPalette`; sky + ocean fragment shaders (+ loaders/painters/fallbacks); `PropsLayer` (windows, beacons, police, helicopter, ships, yacht) driven by the manifest + audio/beat clock; wiring into the audio player; tests; docs/CHANGELOG. |

## Reusable architecture

New module `lib/features/scenery/` (depends only on `dart:ui`, `flutter`, its own palette — never on the old plate code):

```
lib/features/scenery/
  layered_backdrop.dart        # reusable widget: layer stack + clock + program/PNG loading + reduced-motion + RepaintBoundary
  model/
    backdrop_palette.dart      # physics palette (single source of truth) + copyWith
    backdrop_scene.dart        # ordered layer list + knobs
    skyline_manifest.dart      # normalized anchors (type + placeholder; Codex fills art-matched values)
  runtime/
    scenery_shaders.dart       # FragmentProgram cache (mirrors AiStateShaderProgramCache) + setSceneryColor
    backdrop_props.dart        # pure time/beat-driven schedulers (no canvas) — unit-testable
  layers/
    backdrop_layer.dart        # BackdropLayer interface + BackdropContext
    sky_layer.dart             # full-screen sky shader (+ CPU fallback) + buildSkyUniforms
    bitmap_layer.dart          # generic transparent-PNG layer (parallax offset, opacity, optional tint)
    ocean_layer.dart           # band-clipped water/foam shader (+ CPU fallback) + buildOceanUniforms
    props_layer.dart           # canvas signals
```

**`LayeredBackdrop`** builds one `CustomPaint` whose painter walks an **ordered list of `BackdropLayer`s**, composited back-to-front so shaders interleave with bitmaps:
- **Sky layer** — full-screen fragment shader.
- **Bitmap layers** — transparent PNGs (skyline_far, skyline_near, bridge, yacht, foreground), drawn with optional parallax x-offset, opacity, and optional `srcIn` tint. (A bitmap's alpha can also *mask* a shader via `BlendMode.dstIn` for animating an individual layer later.)
- **Ocean layer** — lower-band fragment shader (clipped/translated so frag coords are band-local → cheap).
- **Props layer** — canvas point/sprite lights from `SkylineManifest`.

Default scene (back→front): `sky → skyline_far → skyline_near → bridge → yacht → ocean (band) → props → foreground → [dancer on top]`. Missing bitmaps no-op, so the scene degrades gracefully before Codex's art lands. The widget takes a `BackdropScene` + `BackdropPalette`, an injected `timeSeconds` (the audio/dance clock; standalone it self-drives a `Ticker`), an optional beat pulse, and `reducedMotion`. Light positions are normalized 0..1 from the manifest so they pin onto the PNGs at any size.

**Integration (audio player only):** in `character_dance_to_track_demo.dart`, wrap the render in a `Stack`: `LayeredBackdrop(timeSeconds: danceSeconds, palette: kBlueHourPalette, scene: BackdropScene.blueHourWaterfront())` **behind** the existing `CustomPaint(CharacterPainter(...))`. Flip that painter to `backdrop: CharacterBackdrop.none` and drop its `backdropImage/Clouds/Waves` args (the painter renders a transparent background for `none`, so **no CharacterPainter change**). Remove the file's `_loadBackdrop()` + `_backdrop/_clouds/_waves` fields. The audio position already drives the ticker; reuse it as the backdrop clock, and optionally pulse beacons/foam/windows on `BeatMap` beats.

## Physics-guided palette (blue hour)

Blue hour ≈ sun 4–8° below horizon. Look driven by **Rayleigh scattering** (∝1/λ⁴ → short wavelengths survive) and **ozone Chappuis-band absorption** (removes residual orange/red → the deep, pure twilight blue); a thin warm ember only on the sunset azimuth; **moonlight** ≈ reflected sunlight (~4300 K, slight regolith warmth) with a cool atmospheric halo; artificial lights at real CCTs; narrow-band signal emitters at fixed wavelengths; water as Fresnel sky-reflection minus red absorption. One `BackdropPalette` const of raw `Color` literals (artistic asset palette, intentionally **not** design-system tokens — matching the existing backdrop's raw literals). Implemented in `lib/features/scenery/model/backdrop_palette.dart` as `kBlueHourPalette`.

| Token | Hex | Physical justification |
|-------|-----|------------------------|
| skyZenith | `#0A1733` | Deep indigo; ozone removes orange, Rayleigh leaves blue; darkest overhead. |
| skyUpper | `#12305C` | Mid-altitude blue. |
| skyHorizonCool | `#285E78` | Teal-cyan horizon band; forward-scattered short-λ + Earth-shadow boundary. |
| skyEmber | `#9C5A33` | Muted warm residual, sunset azimuth only, thin low band. |
| hazeSmog | `#3A4252` | Low pollution/haze band over the lagoon — warm-grey, desaturating; grime. |
| moonDisk | `#F2E9CF` | Warm pale white; moonlight ~4300 K + regolith warmth. |
| moonHalo | `#9FBBD6` | Cool bluish bloom; scatter of moonlight in nearby sky. |
| star | `#EAF0FF` | Faint near-white; scintillation = twinkle. |
| cloudLit / cloudBase | `#C4D2E2` / `#2B3754` | Moon/sky-lit tops; shadowed undersides. |
| skylineFar / skylineNear | `#213A5C` / `#0D1A30` | Aerial perspective lifts distant towers toward sky blue; near is near-black. |
| buildingRim | `#6C8098` | Cool moon-side edge light. |
| windowSodium / windowLed | `#FFB257` / `#DCEBFF` | Sodium ~2000 K amber (dominant); LED ~4500 K cool white (minority). |
| bridgeStruct / bridgeCable | `#14233B` / `#43536D` | Bridge silhouette; thin moonlit cables. |
| yachtHull / yachtCabinGlow | `#16283C` / `#FFCE86` | Dark hull; warm interior cabin spill (~2700 K). |
| oceanHorizon / oceanNear / foam | `#123847` / `#08202D` / `#D7E6EA` | Fresnel sky reflection minus red absorption; cool foam. |
| moonGlint | `#E6D6A8` | Warm broken reflection column on ripples. |
| beaconRed | `#FF2A1F` | Aircraft obstruction light ~630 nm; flashing. |
| policeRed / policeBlue | `#FF1736` / `#1E59FF` | LED strobes ~630 nm / ~465 nm. |
| shipPort / shipStarboard / shipMast | `#E23A2E` / `#1FB85A` / `#FFF3DE` | COLREGS nav lights: red port, green starboard, white masthead/stern. |
| heliBeacon / heliStrobe | `#FF2A1F` / `#FFFFFF` | Red anti-collision beacon + white strobe. |

**Grime, not pristine:** the shaders add a low warm-grey **smog/haze band** at the horizon (lifts blacks, desaturates) and a faint **film grain** over sky+ocean. The Codex bitmaps carry the structural grit (soot streaks, uneven tones, dark/derelict patches, irregular silhouettes).

## Shaders

Mirror the repo convention (`shaders/ai_voice_input.frag` + `ai_voice_input_shader.dart`): `#include <flutter/runtime_effect.glsl>`, `precision highp float`, indexed `uniform`s, `hash`/`noise`/`fbm` helpers; colors via a local `setSceneryColor`; pure `buildSky/OceanUniforms` as the testable wiring seam; programs memo-cached + loaded once; CPU fallback painter until/if the program loads.

- **`shaders/scenery_sky.frag`** — vertical gradient `skyZenith→skyUpper→skyHorizonCool`; **cumulus clouds via 2D fbm + domain warp** (`fbm(uv + fbm(uv))`, drifting, coverage-thresholded, confined to the upper band); **moon** = smoothstep disc + `exp(-d²)` bloom + faint crescent + slow sparkle spikes; **stars** = per-cell hash + `0.5+0.5·sin` twinkle, faded toward the horizon; **smog band + film grain** for grime. Opaque (back layer).
- **`shaders/scenery_ocean.frag`** — band only. `oceanHorizon→oceanNear`; **foam** = smoothstep of layered `sin(x·scale + fbm)` crest ridges advected by time; **moon glint** = shimmering broken vertical column at the moon's x; optional `beat` swell.

## Props/lights layer (canvas)

Pure schedulers in `backdrop_props.dart` (time + optional beat phase, unit-testable), rendered via `SkylineManifest` anchors: **lit windows** (seeded subset, mostly sodium + some LED, slow flicker); **aircraft beacons** (red blink at building/tower tops, staggered); **police sweep** (occasional red/blue strobe along the bridge deck, zero most frames); **helicopter** (crosses occasionally); **ships + moored yacht** (drift / static, with COLREGS port/starboard/mast lights + warm cabin glow). Glows via pre-blended radial sprite or additive `BlendMode.plus` (no `MaskFilter.blur`, no `saveLayer`); counts capped. Optional beat-pulse on beacons/windows.

## Determinism / reduced motion

Clock = the audio player's dance seconds (injected). `MediaQuery.disableAnimationsOf` → freeze to a calm constant frame. A `timeOverride` pins time for tests (mirrors `ai_voice_input_shader.dart`). Hot path allocation-free (const layer list, reused `Paint`s, schedulers return small records).

## Performance

Sky is the only heavy shader (fixed ~5 octaves, slow drift). Ocean band-clipped (~30–40% height, fewer octaves). PNGs decode once to `ui.Image` and `drawImageRect` per frame. Props capped/mostly-zero. `RepaintBoundary` around the backdrop. Overscan layer rects for parallax. Escalate sky to a throttled cached image only if profiled hot (default: direct draw).

## Tests (repo-strict: one file per source, meaningful assertions, no real timers, deterministic, centralized helpers)

- `backdrop_palette_test.dart` — channel invariants (zenith bluer/darker than horizon; ocean b>r; foam near-white; beaconRed red-dominant; policeBlue blue-dominant; sodium r>b; required opaque); `copyWith`.
- `backdrop_scene_test.dart` — default layer order; knobs propagate.
- `scenery_shaders_test.dart` — pubspec registers both `.frag`; both compile via `FragmentProgram.fromAsset`; cache identity + `reset()`; `setSceneryColor` packs r,g,b,a.
- `sky_layer_test.dart` / `ocean_layer_test.dart` — uniform-builder indices (res@0/1, time@2, colors at offsets); fallback paints non-blank, top reads blue, moon/foam/glint brighter; same time → byte-identical.
- `bitmap_layer_test.dart` — parallax offset + opacity + tint math; draws the image at the expected rect.
- `backdrop_props_test.dart` — Glados over schedulers: beacon period/duty + phase independence; helicopter x-monotonic-in-window & invisible-between; ship drift/wrap & correct nav-light sides; police active only in windows; beat-pulse maps beat→intensity; frozen time → constant.
- `props_layer_test.dart` — beacon-red pixels at building tops when on; helicopter only in-window; reduced motion static.
- `layered_backdrop_test.dart` — builds with injected fake program + image loaders; fallback before programs resolve, shader painter after a pump; reduced-motion; standalone vs injected clock.
- `skyline_manifest_test.dart` — anchors within 0..1, tower/deck/waterline sane.
- `character_dance_to_track_demo_test.dart` — the player composes `LayeredBackdrop` behind `CharacterPainter(backdrop: none)`; no longer references the waterfront PNGs; backdrop clock tracks the (faked) audio position.

## Docs / CHANGELOG / version

- New `lib/features/scenery/README.md` (architecture-first + Mermaid layer-stack + clock/loader/reduced-motion + beat-sync hook). Note the new backdrop in `lib/features/character/README.md` + this plan.
- `CHANGELOG.md` `### Changed` under `## [0.9.1031]`; matching line in `flatpak/com.matthiasn.lotti.metainfo.xml` top `<release version="0.9.1031">`. (Confirm: ride 0.9.1031 vs bump; and whether this dev/demo player is user-visible enough to warrant a line.)

## Build order (each stage: compiles, analyzer zero warnings, tests green before next)

`make build_runner` not needed.
0. `lib/features/scenery/` scaffolding: palette, scene/layer interfaces, shader cache, minimal valid `.frag`s, pubspec `shaders:` (+ `assets/scenery/` once PNGs exist).
a. Sky shader + `sky_layer` + `LayeredBackdrop` (sky only) + wire into the audio player (Stack behind `CharacterPainter(none)`), driven by the dance clock.
b. `bitmap_layer` + load + composite Codex's PNGs (skyline tiers, bridge, yacht, foreground) over the sky.
c. Ocean shader + `ocean_layer` (band, in front of structures).
d. `props_layer` + schedulers from the manifest (windows + beacons first; then police/helicopter/ships/yacht; then optional beat-pulse). Run `app-screenshots` + `design-review-panel` to tune palette/cloud/foam/beat.
e. Docs + CHANGELOG + flatpak.

## Verification

- Analyzer zero warnings; `fvm dart format .`.
- Targeted tests per new file, then `character_dance_to_track_demo_test.dart`.
- Visual: `app-screenshots` of the audio player at desktop + phone; iterate shader/palette/beat knobs with `design-review-panel`; with a real track, confirm clouds/waves/beacons move in time with playback.

---

## CODEX PROMPT — build the bitmap artwork layers (copy-paste)

> **Task:** Build the static *structure* artwork for a reusable blue-hour waterfront backdrop in a Flutter app (repo root is the working dir). The dynamic sky (gradient, moon, stars, clouds) and ocean (water, foam, glint) are GLSL fragment shaders built separately — **do not** build those. Your job is the city **skyline**, the lagoon **bridge**, and a moored **yacht** as **multiple transparent bitmap (PNG) layers with opacity**, produced by a **committed, regenerable generator**, plus art-matched values for the geometry manifest so runtime code can pin lights/windows onto them.
>
> **Style (hard constraints):** Cartoon, production-quality — an expensive animated feature's establishing shot. NOT photorealistic, NOT AI-painterly. Clean flat shapes, but **grimy, weathered, lived-in — NOT impeccable/shiny/new**: uneven building tones, soot streaks, a few dark/derelict/under-construction patches, irregular rooflines, antennae and water tanks, a worn bridge. Subject: a tropical lagoon waterfront (Lagos-inspired) — a varied high-rise skyline plus a long cable-stayed/suspension bridge over the water, with a luxury yacht moored at mid-distance. Each layer is a **separate transparent PNG**; the structures are **mostly dark silhouettes** colored from the palette below, with only a faint cool moon-side rim light and subtle ambient at the base. **Do NOT bake windows, beacons, police lights, cabin lights, or any glow into the bitmaps** — those are drawn dynamically at runtime from the manifest. Shape + base tone (with grime) only.
>
> **Color palette to paint against (physics-guided blue hour):** skyline_far `#213A5C` (distant, lower-contrast, aerial perspective), skyline_near `#0D1A30` (near-black blue), bridge `#14233B`, yacht hull `#16283C`, optional moon-side rim `#6C8098`. Design the tiers to separate clearly against a deep-blue moonlit sky (height/width contrast, overlap; near reads in front of far).
>
> **Deliverables (exact):**
> 1. `tools/scenery_art/` — a committed, documented generator (Python+Pillow/cairo **or** a Dart/Flutter `PictureRecorder→toImage→PNG` export harness; your choice) with a README + Makefile, that **regenerably** renders the PNGs below to `assets/scenery/`. Deterministic (seeded). This is how the art is produced and re-tuned.
> 2. `assets/scenery/skyline_far.png` — distant skyline tier, transparent, canvas `2560×1440`, baseline ≈ 58% height, colored ~`#213A5C`.
> 3. `assets/scenery/skyline_near.png` — foreground tier (taller, varied: setbacks, antennae, water tanks, 2–3 distinctive towers), same canvas, baseline ≈ 63% height, colored ~`#0D1A30`, reads clearly in front of the far tier.
> 4. `assets/scenery/bridge.png` — full-width cable-stayed/suspension span: two proportional towers, catenary main cables, vertical hangers, deck ≈ 65% height, piers into the water; colored ~`#14233B`. Towers tall enough to carry aircraft beacons.
> 5. `assets/scenery/yacht.png` — a moored luxury motor yacht (multi-deck) at mid-distance on the lagoon, transparent, dark hull silhouette ~`#16283C`. **No baked cabin lights** — the runtime adds warm cabin windows + red/green/white nav lights from the manifest.
> 6. *(optional)* `assets/scenery/foreground.png` — subtle bottom foreground (quay railing / palms / pier posts) for depth, transparent, restrained.
> 7. `lib/features/scenery/model/skyline_manifest.dart` — this file already exists with the `SkylineManifest` type and a `kPlaceholderSkylineManifest` const. **Replace that const's values** (or add a new named const the runtime can point at) with **art-derived normalized 0..1 coordinates** relative to the 2560×1440 canvas, generated from the *same* parameters that drew the PNGs so they cannot drift: `buildingTops` (apex points for beacons/roof lights), `windowCells` (rects where lit windows go), `bridgeTowerTops` (two points), `bridgeDeck` (deck polyline for police sweeps), `yachtCabin` (rect for warm cabin windows), `yachtNavLights` (bow/stern/mast points), `waterline` (normalized y). Do **not** change the type's field set without coordinating. Anchors MUST match the PNG art exactly — this is the contract the runtime light layer relies on.
> 8. A preview screenshot of the stacked PNGs over a flat blue-hour gradient (1920×1080 + a phone aspect).
>
> **Quality bar / acceptance:** Varied, believable skyline rhythm (no obviously repeating buildings; mixed widths/heights/setbacks; a couple of distinctive towers). Bridge reads as a real span (correct cable fan/catenary, proportional towers). Yacht reads as a sleek multi-deck motor yacht. Layers cleanly separable with clean alpha; structures read as dark grimy silhouettes that let the sky show between/above them; nothing dynamic baked in. PNG-24 with alpha. Register `assets/scenery/` under `flutter: assets:` in `pubspec.yaml`. `fvm flutter analyze` clean; `fvm dart format .` applied. Follow `AGENTS.md` + `test/README.md` for any tests (one test file per source file, meaningful assertions, no real timers/delays): at minimum unit-test the manifest (anchors within 0..1, sane counts/positions). **Do not** modify `lib/features/character/` or the old waterfront plate — keep this to the new module under `lib/features/scenery/` + `tools/scenery_art/`. Deliver the generator, the PNGs, the manifest values, the preview, and a short note mapping the manifest anchors to the art.
