# Project plaza — handover

Written 2026-09-03 for whoever picks this up next (human or Claude Code) with
no other context. Everything you need to run, understand and extend the
prototype is in this file; the proposal for making it usable is in
[DESIGN.md](DESIGN.md).

State of play in one line: **the M0 prototype proves the concept and the
performance model, and is not usable yet.** It renders one project as one
long street of task buildings with live Flutter widget facades, at geometry-
baseline frame rates, but there is no way to find anything, nothing is
readable from a distance, and nothing you touch persists.

---

## 1. The vision

Lotti's task/project relationships were shown as a graph database
visualisation, the "useless hairball" every node-link tool ends up as. The
plaza replaces it with a **spatially meaningful 3D world**:

- **Times Square metaphor.** A project is a street or plaza. Each task is a
  building whose street-facing wall is a live billboard: title, status,
  cover art, checklist. Bigger project, bigger scene.
- **Stable spatial memory.** The map of a project must stay mostly the same
  over months so the user builds a memory of a place ("the blocked one is
  round the corner from the launch review"). Nothing ever moves.
- **Health at a glance.** From a distance, colour tells the story: an
  all-green street is a healthy project, a red lantern in a green block is
  the thing that needs you. Anomalies pull you in to walk or teleport over.
- **Teleport points and curated flights.** Freely walkable, but with guided
  teleport points, visible as dots from any angle, that fly the camera along
  an animated, visually pleasing path to a curated vantage point over part of
  the scene.
- **Beyond projects.** The same machinery should generalise to a personal
  **goals map** you walk through every morning to check the overall picture.

## 2. What exists today (merged in PR #4099, commit `075dfc372`)

A standalone developer harness. It is **not** wired into app routes,
dependency injection or the database: it runs on synthetic data plus a
projection of the penguin demo world.

### 2.1 Run it

```sh
# macOS (the platform the prototype was mainly developed on, ~120 fps)
fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart -d macos

# Linux (works in the ARM64 Parallels VM used for this handover, ~35–40 fps)
fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart -d linux
```

`--enable-flutter-gpu` is a `flutter run` flag only. To run a **built**
binary (what the screenshot and benchmark scripts do), pass the engine switch
through the environment instead:

```sh
fvm flutter build linux --debug -t lib/features/plaza/dev_main.dart
FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-flutter-gpu \
  build/linux/arm64/debug/bundle/lotti
```

Environment variables the harness reads:

| Variable | Effect |
|---|---|
| `PLAZA_PRESET=demo\|small\|medium\|large` | Dataset at boot (default `large`, 300 tasks). `demo` is the penguin world, labelled **waddle** in the overlay. |
| `PLAZA_BENCH=1` | Auto-walk benchmark: six LOD configurations, 14 s each, prints `PLAZA_BENCH result` lines to stdout. Forces the `large` preset. |
| `PLAZA_TOUR=1` | Screenshot tour: steps through the fixed poses in `ui/plaza_tour.dart`, prints `PLAZA_TOUR ready <i> <name>` once each has settled (5 s), moves on after 9 s. Added in this handover. |
| `LOTTI_WINDOW_SIZE=WxH` | Linux runner window size (generic Lotti runner feature). |

Controls: **WASD / arrows** walk, **shift** sprint, **drag** look, **space**
toggles auto-walk, the **overhead** button blends to a top-down search view,
**preset** cycles waddle → 20 → 80 → 300.

### 2.2 File map

```
lib/features/plaza/
  dev_main.dart                     harness: presets, camera loop, LOD driving,
                                    stats, PLAZA_BENCH and PLAZA_TOUR modes
  domain/
    plaza_task.dart                 PlazaTask + PlazaTaskState (pure Dart)
    plaza_generator.dart            seeded synthetic presets 20 / 80 / 300
    street_layout.dart              merge-stable street layout (pure Dart)
  data/
    demo_world_projection.dart      penguin demo world → PlazaTask list
  scene/
    plaza_scene.dart                builds the flutter_scene graph: ground,
                                    road slabs, building boxes, far-tier
                                    colour plates, facade anchors, spawn
    facade_lod_manager.dart         near / mid / far surface tiers with caps
  ui/
    facade_widget.dart              the billboard widget (title, meta, cover,
                                    checklist, state chip, progress fill)
    fly_camera_controller.dart      WASD walk camera + overhead blend
    debug_overlay.dart              fps / tier / capture stats + knobs
    plaza_tour.dart                 fixed screenshot poses (this handover)

test/features/plaza/                one test file per source file above
  domain/street_layout_test.dart    the layout invariants (property tests)
  ui/plaza_tour_test.dart           tour poses are pure, stable, geometric

tool/plaza/capture_tour.py          Linux/X11 script: runs PLAZA_TOUR and
                                    grabs one PNG per stop (this handover)
docs/plaza/                         this file, DESIGN.md, screenshots/
knowledge/features/plaza.md         the runtime map (architecture, invariants,
                                    tiers, gotchas) — the authoritative home
```

### 2.3 Architecture

The runtime map — the data → layout → scene → LOD → harness flow, the
week-bucket layout and its invariants, the facade tier state machine, the
harness modes and the gotchas — is the knowledge concept
[knowledge/features/plaza.md](../../knowledge/features/plaza.md). Read it
before changing anything under `lib/features/plaza`; it is the one home for
those facts, and `make knowledge_check` validates it.

The two facts from it that shape everything in [DESIGN.md](DESIGN.md):

- **Placement is a pure function of `(createdAt, id)` bucketed by UTC week**,
  so the street merges identically on every device. Appending never moves an
  existing building; a late-syncing task jostles only its own week.
- **Facades come in three tiers**: near = live interactive widget captured
  every frame (hard cap 12), mid = hosted widget captured on a slow interval
  (cap 60), far = a state-coloured plate and no widget.

Street sizes the layout produces for the presets, with default knobs (these
are measurements of the current generator, not design values):

| Preset | Tasks | Weeks (built + gaps) | Street length | Busiest week |
|---|---|---|---|---|
| waddle (demo) | 28 | 6 (6 + 0) | 276 m | 9 |
| small | 20 | 3 (3 + 0) | 138 m | 8 |
| medium | 80 | 30 (28 + 2) | 1.3 km | 9 |
| large | 300 | 93 (86 + 7) | **4.0 km** | 12 |

At the 12 m/s walk speed the large street takes five and a half minutes to
walk end to end. That number alone explains most of section 6.

**Facade widget (`ui/facade_widget.dart`).** Shopfront order: category bar,
title (44 px, up to six lines), due / links row, full-bleed 16:9 cover art,
up to eight open checklist items with checkboxes, state chip, progress count.
Progress also fills the facade from the bottom in the state colour. The
checkbox state is **local widget state**; nothing is written anywhere.

**Camera (`ui/fly_camera_controller.dart`).** First person at a fixed 5 m
eye height (taller than a person so 12 m facades read), 12 m/s walk, 3×
sprint, drag-look with clamped pitch, and an animated overhead blend that
lifts the eye 90 m up and 40 m back and looks at the walker's spot. Spawn is
the **frontier**: the end of the newest week, looking back down the street.

### 2.4 Tests

One test file per source file, mirroring the path. Run only the files for
the sources you touched (repository rule; never a whole feature suite), e.g.:

```sh
fvm flutter test test/features/plaza/domain/street_layout_test.dart
fvm flutter test test/features/plaza/ui/plaza_tour_test.dart
```

All pure-Dart layers (task model, generator, layout, demo projection, tour
poses) are covered without a GPU. `PlazaSceneController` builds
`flutter_scene` meshes on construction and `FacadeLodManager` creates
GPU-backed `WidgetComponent`s when `update()` promotes a surface; both are
exercised only by running the harness and `codecov.yml` excludes `scene/**`
together with `dev_main.dart`. The tour data class `TourScene` exists
precisely so the pose maths can be tested without them.

## 3. Screenshots (current state, Linux VM, 1600×1000 window)

Captured with `PLAZA_TOUR=1` via `tool/plaza/capture_tour.py` at commit
`c49c1ea9`. The repository policy is that no image is ever committed (see
`knowledge/conventions/screenshots.md`), so the PNGs live in the gitignored
`docs/plaza/screenshots/` locally and on the public R2 bucket below. The tour
is deterministic; re-running the script reproduces the same poses.

| Stop | What it shows |
|---|---|
| `street-frontier` | Spawn pose. Near tier (crisp live facades, front left/right), mid tier (captured, slightly soft), far tier (colour plates on boxes) in one frame. |
| `street-midway` | Standing on the road 40 % down the street, looking along it. Titles are the only thing readable beyond ~30 m. |
| `street-diagonal` | Looking across a row at 55 % down the street. Far boxes are category-tinted walls; the state colour plate is invisible from this angle. |
| `facade-closeup` | 16 m in front of the facade with the most open items. Live widget: title, checklist, state chip, progress count. |
| `facade-closeup-ticked` | Same, after clicking the first checkbox on the wall. It ticks and strikes through, proving interactive widgets on meshes work. |
| `overhead` | The overhead blend, 90 m above the walker. Reads road bends and lots, but not state. |
| `waddle-street` | Penguin demo world: real titles, cover art from the demo media catalogue, real checklists. |
| `waddle-closeup` | A demo task facade up close, with cover art, due date, links count. |

Base URL for all images:
`https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/`

![street-frontier](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-frontier.png)

![street-midway](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-midway.png)

![street-diagonal](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-diagonal.png)

![facade-closeup](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/facade-closeup.png)

![facade-closeup-ticked](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/facade-closeup-ticked.png)

![overhead](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/overhead.png)

![waddle-street](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/waddle-street.png)

![waddle-closeup](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/waddle-closeup.png)

The debug overlay (top right in every shot) is the whole UI: fps and frame
times, building count and preset, live/static/far counts, capture count and
last capture duration, promotion count, the live and static caps, three
layout knobs (px/m, road width, max height; each rebuilds the scene), the
ALL LIVE stress switch, and the preset / overhead buttons.

To regenerate: build the Linux debug bundle, then
`python3 tool/plaza/capture_tour.py docs/plaza/screenshots`. For the ticked
frame add `PLAZA_CLICK="facade-closeup:448,479"` (window-relative pixel of
the first checkbox at 1600×1000). The script needs `python3-xlib` and
Pillow, and an X11 (or XWayland) display.

## 4. Benchmark

### 4.1 M0 result (PR #4099, 300-task preset, Linux ARM64 VM)

| Config | fps avg | ms avg |
|---|---|---|
| far-only (no widgets) | 37.4 | 26.7 |
| default (12 live / 60 static) | 30.4 | 32.8 |
| 30 live, saturated | 21.3 | 47.0 |
| 60 live, saturated | 14.2 | 70.6 |
| **all-static (292 hosted, no per-frame capture)** | **35.0** | **28.6** |
| all-live (292 captured every frame) | 2.5 | 395.5 |

### 4.2 Reference hardware

Natively on macOS (Apple silicon) the same scene runs at **120 fps without
glitches** while walking the waddle preset. The VM numbers above are only
useful relative to each other; do not re-run the benchmark in the VM to judge
absolute performance. The tour mode added in this handover is inert unless
`PLAZA_TOUR=1` is set and does not touch the benchmark path.

### 4.3 Interpretation

- **Hosting** hundreds of widget subtrees is nearly free: all-static (292
  hosted) runs within 2 fps of the no-widget baseline.
- **Per-frame capture** is the entire cost: roughly 0.6 ms per live widget
  per frame on this VM. Sixty live facades halve the frame rate; every facade
  live is a slideshow.
- The **capped LOD runs at geometry baseline**. The geometry baseline itself
  is only ~38 fps here because the VM has no real GPU; on macOS the same
  scene renders at ~120 fps while walking the waddle preset.
- **Promotions are the spikes on weak hardware.** In the VM the overlay
  reports worst frames of 66–100 ms when several facades promote at once
  (walking fast into a busy block); on macOS this is not noticeable. Mobile
  will sit between the two, so the design schedules promotions rather than
  only capping them.

## 5. Dependency caveats

- `flutter_scene: ^0.23.0` (Flutter GPU / Impeller). It pins
  `code_assets ^1.2.1`, which would downgrade the native-assets toolchain for
  the whole repo, so `code_assets` and `native_toolchain_c` are pinned
  current under `dependency_overrides` in `pubspec.yaml` (comment there).
  The `flutter_scene` build hook compiles fine against 2.x; a full Linux
  build including the onnxruntime and vodozemac hooks verified it.
  **Re-check on every `flutter_scene` bump.**
- `flutter_scene` 0.23 flipped front faces to counter-clockwise but its
  `WidgetComponent` quad still winds clockwise, so `facade_lod_manager.dart`
  builds its own CCW quad (`_facadeQuad`). Drop it when upstream fixes the
  quad.
- `analyzer_plugin` is also overridden for unrelated reasons (json_serializable
  vs objectbox_generator); leave it alone.
- Flutter 3.47.2 via FVM. `--enable-flutter-gpu` does not appear in
  `flutter run --help` but is accepted; `flutter build` rejects it (use the
  engine-switch environment variables above).

## 6. Current limitations: why it is not usable

Grouped by what a user would hit first. Every item is visible in the
screenshots above or reproducible in the harness within a minute.

**You cannot find anything.**
1. No search, no locator, no list, no minimap. The only way to reach a task
   is to walk a 4 km street past 300 buildings.
2. Titles are legible for about 30 m. Beyond that a building is a dark box
   with a barely visible colour plate; from an angle (see `street-diagonal`)
   the plate is not visible at all, only the category-tinted wall.
3. The overhead view is 90 m over the walker's head, tracks the walker, and
   shows roofs only (no state, no titles). It is a local "where am I", not a
   map.
4. Road bends hide what is around the corner, and there is no cue which way
   is "newer".

**Nothing reads from a distance.**
5. State colour lives on a thin front plate under the facade; walls are
   category-tinted, roofs are unlit grey. From the street or from above,
   nothing says green/red. "Health at a glance" does not exist yet.
6. No sky, no fog, no lighting: far boxes float on a black background
   without depth cues, and the scene looks like a placeholder.
7. Height encodes content length (long title, many items), which is the
   wrong thing to make tall: the biggest buildings are the wordiest tasks,
   not the important ones.

**Nothing is curated.**
8. No teleport points, no camera flights, no home. Walking and the overhead
   blend are the only transitions.
9. Every facade shows everything (title, meta, cover, eight items, chip,
   count) at every tier; there is no "sign" variant with three words and a
   colour for mid range.

**Nothing persists or connects.**
10. Ticking a checkbox on the wall updates local widget state only. There is
    no path from the harness to `JournalDb` or the checklist services.
11. Nothing opens a task. Links are a count on the facade; they draw nothing.
12. Only synthetic data and the demo world exist; no projection from real
    tasks and no notion of a project beyond "one list of tasks".

**Interaction is rough.**
13. Drag-look and clicking a facade share the primary mouse button; there is
    no tap-versus-drag threshold, no hover highlight, no focus ring.
14. Only the near tier (≤ 12 facades within 35 m) is interactive, invisibly:
    a mid-tier facade looks the same and ignores clicks.
15. No touch controls whatsoever; the harness is keyboard-only.
16. On weak hardware (the Linux VM) promotions hitch when walking into a
    busy block; fine on macOS, unknown on phones.
17. The only UI is the debug overlay, whose sliders are perf knobs, not user
    controls, and which covers part of the scene.

**Layout limits.**
18. One street, time as the only axis. A 300-task project is a 4 km line;
    there is no folding into a district, no plaza, no way to place two
    projects side by side.
19. The accepted edge case: a task syncing into a previously empty week
    shifts everything downstream of it (rare, but it violates "nothing ever
    moves" once).
20. Week buckets with 12 tasks squeeze buildings to 2.5 m width, so busy
    weeks are unreadable rows of slivers while quiet weeks have three wide
    buildings and a lot of nothing.

## 7. Glossary

- **Bucket / plot group**: one UTC week of the project's life; one 46 m
  run of road with buildings on both sides.
- **Frontier**: the end of the newest bucket; the spawn point.
- **Facade**: the street-facing wall of a building, where the widget is.
- **Tier**: near (live widget), mid (captured widget), far (colour plate).
- **Capture**: rendering a hosted widget subtree into a GPU texture; the
  expensive part.
- **Promotion**: a facade moving up a tier (far → mid → near).
- **Waddle**: the penguin demo world preset (Project Waddle), the only
  fixture with real-looking content and cover art.

## 8. Where to go next

Read [DESIGN.md](DESIGN.md). It turns the list in section 6 into a
navigation model, a district layout that keeps the merge-stable buckets, a
three-range information design, a performance budget derived from section 4,
and milestones M1–M6, each demonstrable in this harness.
