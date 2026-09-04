# Project plaza: handover

Written 2026-09-03 for the M0 prototype and rewritten 2026-09-04 after the
design's first three milestones landed, for whoever picks this up next
(human or Claude Code) with no other context. This file is the operator's
view: what is implemented, how to run and drive it, how to capture
screenshots, what is missing and what the known limits are. The design it
follows is [DESIGN.md](DESIGN.md); how it runs, with every number, is the
concept [knowledge/features/plaza.md](../../knowledge/features/plaza.md);
what it is and where the code sits is the
[README](../../lib/features/plaza/README.md).

State of play in one line: **the plaza is a navigable, legible district of
the penguin demo world, and still a developer harness.** You land on a lit
frontier plaza, the billboards tell you what needs attention, beacons and
search fly you anywhere, the morning walk visits the anomalies, and a live
facade takes a tick. Nothing reads the app's data and nothing you touch
persists.

---

## 1. The vision

Lotti's task/project relationships were shown as a graph database
visualisation, the "useless hairball" every node-link tool ends up as. The
plaza replaces it with a **spatially meaningful 3D world**:

- **Times Square metaphor.** A project is a street with a plaza at its
  newest end. Each task is a building whose street-facing wall is a live
  billboard: title, status, cover art, checklist. Bigger project, bigger
  scene.
- **Stable spatial memory.** The map of a project must stay mostly the same
  over months so the user builds a memory of a place ("the blocked one is
  round the corner from the launch review"). Nothing ever moves.
- **Health at a glance.** From a distance, light tells the story: an
  all-dark street is a finished project, a red lantern in a quiet block is
  the thing that needs you. Anomalies pull you in to walk or fly over.
- **Teleport points and curated flights.** Freely walkable, but with guided
  beacons, visible as dots from any angle, that fly the camera along a
  pleasing path to a curated vantage point.
- **Beyond projects.** The same machinery should generalise to a personal
  **goals map** you walk through every morning to check the overall picture.

## 2. What exists today

Branch `feat/plaza-handover`, PR #4122, on top of the M0 prototype merged in
PR #4099 (commit `075dfc372`). The synthetic 20/80/300-task presets of M0
are gone from the harness; it shows the penguin demo world only, and the
tests use a synthetic fixture of their own.

Implemented, by area (the mechanism behind each is in the concept):

- **District layout.** The merge-stable street from M0, now folded into a
  serpentine of rows with connector segments, buildings sized by weight
  (priority and how connected and open the task is) with one landmark per
  week, deleted tasks as fenced lots.
- **Frontier plaza.** A square at the newest end with a home pose, four
  billboard pylons, two screens mounted on the newest buildings' end walls,
  a ticker gantry over the street mouth and a jumbotron on a tower behind
  the plaza. On a folded street the plaza shifts sideways to clear the
  previous row.
- **Attention.** A day-granular attention score per task; anomalies get an
  attention beacon, a pulsing lantern and a roof billboard above their own
  building; the six highest fill the plaza's billboards; the headlines run
  on the tickers, the jumbotron and screens on the skyline towers.
- **Skyline range.** Night sky and a haze that thins as the camera climbs,
  roof lanterns in state colours, window-grid walls lit by state over a
  parade of shopfronts dressed by state (trading, trading late in amber,
  papered and fitting out, shuttered behind alarm tape, shuttered for the
  night), neon edges (category colour, state colour on an alarm),
  light pools that fade
  with altitude, week markers on the road (shown from the air only) and week signs hung from the
  left-kerb block-head lamp posts, vertical banners on tall buildings, spires with
  warning lights, a paved plaza, a second row of filler blocks, a ring of
  skyline towers and a hero tower with a screen at the far end of every
  folded row.
- **Facade tiers.** Far (geometry and lantern), sign (captured once) and
  live (captured every frame, interactive) with caps, hysteresis, one
  promotion per frame, suspension during flights and pre-capture of a
  flight's destination. The faced building gets a focus ring; its
  checkboxes tick and its details button opens a side panel.
- **Navigation.** Beacons (home, block per week, corner per fold, attention
  per anomaly), flights on an S-curve speed profile (a smooth ramp up to a
  cruise and down again): between two stops on the ground they follow the
  street network at 5 m over the road, looking down the way and round the
  corners, at 10 m/s so the facades and billboards pass by; a climb to the
  overview or a dive back takes the direct line with a district arc; every
  leg is swept against every solid and lifts over whatever stands on it; a
  back stack, a landing flight when you step off the overview that comes
  down beside a building rather than into it, Tab cycling, home and
  overview keys, tap-to-fly on beacons, facades and billboards with a
  tap-versus-drag threshold, a walker collider that knows every solid at
  walk height (plots, fillers, towers, plaza benches, planters and kiosk,
  pylon posts, gantry legs, lamp posts; the signs and the beam are in the
  air, for the flights), and title search. The harness paces its own
  frames: a frame-rate control in the HUD offers auto, 60 and 30, default
  60, and a Debug box there shows the overlay with painted and engine
  frame rates.
- **Morning walk.** Overview, up to three anomalies, home; pausable, and
  abandoned by any movement.
- **Harness modes.** The interactive session, a screenshot tour
  (`PLAZA_TOUR`) and an auto-walk benchmark (`PLAZA_BENCH`), plus
  `PLAZA_HIDE` to strip scene pieces for a capture.

Of the design's milestones, M1 (legible skyline), M2 (beacons and flights)
and M3 (attention, billboards, search) are in, with the deviations listed
at the end of [DESIGN.md](DESIGN.md). M4 (districts and the world), M5
(real data) and M6 (touch and the mobile budget) are not started.

## 3. Running and driving it

The run command and the environment switches are in the
[README](../../lib/features/plaza/README.md). Everything below assumes a
running harness.

### 3.1 A built binary

`--enable-flutter-gpu` is a `flutter run` flag only; `flutter build` rejects
it. A built binary (what the capture script drives) takes the engine switch
from its environment:

```sh
fvm flutter build linux --debug -t lib/features/plaza/dev_main.dart
FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-flutter-gpu \
  build/linux/arm64/debug/bundle/lotti
```

(`x64` instead of `arm64` on an Intel host.)

### 3.2 Controls

| Input | Effect |
|---|---|
| `W A S D` or arrows | walk (shift sprints); stepping off a high pose lands you first |
| drag with the primary button | look |
| tap (no drag, under a quarter second) | fly: a beacon to its pose, a facade to the pose in front of it, a billboard to the task it shows |
| `Tab` / `Shift-Tab` | next / previous navigation beacon (home, blocks, corners) |
| `H` | fly home |
| `M` | fly to the overview |
| `Backspace` | fly back along the breadcrumb stack |
| `/` | search: type, arrows to choose, `Enter` to fly, `Esc` to close |
| `Space` | pause or resume the morning walk |
| `Esc` | close the side panel and end the morning walk |
| backtick | toggle the debug overlay |

Any movement key or drag cancels a flight in place and ends the morning
walk. Input is ignored entirely in tour and bench modes.

**HUD.** Top left: the project label and its counts (the "Tasks" crumb is a
label, it does nothing). Top right: **Morning walk**, **Overview**,
**Home**. A toast names every flight target; a chip at the bottom reports
the walk's progress; the key legend and the lantern legend sit along the
bottom edge.

**On a live facade** (the one with the teal ring): the checkboxes tick and
strike through, and **DETAILS** opens the side panel with the category,
title, chip, due and links line and the same checklist. Ticks are shared
between wall and panel and forgotten when the harness exits.

**Debug overlay** (backtick): fps with average and worst frame time, the
building count, the live/sign/far counts, facade and surface capture counts
with the last capture's duration, the promotion count; sliders for the live
and sign caps and distances (applied at once) and for pixels per metre, road
width and maximum height (each rebuilds the scene on release); and the ALL
LIVE stress switch.

## 4. Tour stops and screenshots

`PLAZA_TOUR=1` steps through these poses, printing `PLAZA_TOUR ready <i>
<name>` once each has settled. Names double as file names.

| Stop | Pose | What it shows |
|---|---|---|
| `home` | the plaza's home pose | the morning landing: pylons, mounted screens, gantry and the street behind them |
| `jumbotron` | beside the plaza on the tower's side, 8 m outside its edge and 12 m short of its back, pitched up to 22°, the project card pinned | the giant screen beside the plaza mouth with no pylon in the way, its tower and the plaza's edge |
| `overview` | the map pose behind the oldest edge | the whole district as lanterns, light pools and markers, the jumbotron as the far landmark |
| `block` | the block beacon a quarter of the way from oldest to newest | a week of buildings at street range: sign facades, lanterns, lamps |
| `shopfront` | eye level on the road at a row head, 18 m before the block-head building's near corner and 6 m out from its facade, pitched no more than 6° at the wall's lower third (alarmed first, then trading; never a plaza mount nor a task another stop shows) | the shopfront parade up the end wall, dressed and worded for the task's state, with the named facade beside it, near square |
| `billboard` | before the first pylon at 1.25 × its width, pitch capped at 12° | the top-ranked billboard, its frame, chase lights, posts and pool |
| `attention-closeup` | the second attention beacon (the first when there is only one) | a live facade of an anomaly with its roof billboard; the tour's last word |

A stop the world cannot provide (no anomalies, no plaza) is skipped;
`PLAZA_TOUR_ONLY` narrows the run.

### 4.1 Capturing

`tool/plaza/capture_tour.py` runs the built Linux bundle in tour mode and
grabs one PNG per stop with `XGetImage`. It needs `python3-xlib`, Pillow
and a real X11 or XWayland display (it sets `GDK_BACKEND=x11`; under a
Wayland session that makes the harness an X client). From the repo root:

```sh
python3 tool/plaza/capture_tour.py docs/plaza/screenshots_v2
PLAZA_TOUR_ONLY=home,billboard python3 tool/plaza/capture_tour.py docs/plaza/screenshots_v2
PLAZA_HIDE=fillers,skyline python3 tool/plaza/capture_tour.py docs/plaza/screenshots_v2
PLAZA_CLICK="attention-closeup:<x>,<y>" python3 tool/plaza/capture_tour.py docs/plaza/screenshots_v2
```

The window is 1600x1000 unless `LOTTI_WINDOW_SIZE` says otherwise; any other
`PLAZA_*` variable is passed through. **Xvfb does not work**: the widget
textures come out as flat slabs on a virtual framebuffer, so capture on the
real display.

Current captures live in `docs/plaza/screenshots_v2/` locally, which
`.gitignore` covers. **Never commit them**: the repository policy is that
no image is ever committed
(see [knowledge/conventions/screenshots.md](../../knowledge/conventions/screenshots.md)).
Durable copies go to the public R2 bucket with the usual PR-screenshot
upload.

### 4.2 M0 captures (historical)

The M0 prototype (PR #4099, captured at commit `c49c1ea9`, 1600x1000, Linux
VM) is documented by these images. They show the pre-design scene: one
straight street, content-sized buildings, the overhead blend and the
old full-content facade at every tier. None of that exists any more; they
stay here as the before state.

Base URL:
`https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/`

| M0 stop | What it showed |
|---|---|
| `street-frontier` | the M0 spawn at the end of the newest week, all three M0 tiers in one frame |
| `street-midway`, `street-diagonal` | the unreadable street range that motivated the sign tier and the lanterns |
| `facade-closeup`, `facade-closeup-ticked` | the M0 live facade before and after a tick |
| `overhead` | the removed overhead blend, 90 m over the walker |
| `waddle-street`, `waddle-closeup` | the penguin world with the M0 facade |

![M0 street-frontier](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-frontier.png)

![M0 street-midway](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-midway.png)

![M0 street-diagonal](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/street-diagonal.png)

![M0 facade-closeup](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/facade-closeup.png)

![M0 facade-closeup-ticked](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/facade-closeup-ticked.png)

![M0 overhead](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/overhead.png)

![M0 waddle-street](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/waddle-street.png)

![M0 waddle-closeup](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/plaza-m0-handover/c49c1ea91971c91c118a0aa7c9227d8e0b340c26/waddle-closeup.png)

## 5. Benchmark

`PLAZA_BENCH=1` auto-walks the penguin street through six LOD budgets and
prints one `PLAZA_BENCH result` line per phase. **No numbers are recorded
here on purpose.** The M0 figures were measured on a different scene (the
300-task synthetic street, in a VM without a real GPU) and do not describe
this one, and the current scene has not been benchmarked since the dressing
pass. Run it natively on macOS when a number is needed; VM figures are only
useful relative to each other.

## 6. Tests

One test file per pure source file, mirroring the path under
`test/features/plaza/`: the domain (task model, street layout, plaza
layout, attention, flight, morning walk, collider, scenery), the demo
projection, `PlazaWorld`, and every widget under `ui/` including the tour
poses. They run without a GPU on the synthetic fixture in
`test/features/plaza/plaza_fixtures.dart`. Run only the files for the
sources you touched (repository rule), for example:

```sh
fvm flutter test test/features/plaza/domain/plaza_layout_test.dart
```

`PlazaSceneController`, `FacadeLodManager`, `PlazaSurfaces`, `PlazaSprites`,
`PlazaPicker`, `WallTextures` and `PlazaBench` need a GPU context and are
exercised only by running the harness; `codecov.yml` excludes `scene/**` and
`dev_main.dart`.

## 7. What is still missing

Grouped by the design milestone that owns it.

**Real data and persistence (M5).**
1. No projection from the app's task, checklist, link and category models;
   the only fixture is the penguin world.
2. A tick on a wall or in the panel is session state; nothing reaches the
   checklist services.
3. The side panel is a summary of the plaza task, not the task page.
4. No status change from a facade.
5. Links are a count; no ground lines, no lantern brightening.
6. No persisted project epoch and no vacant-lot reservation, so the
   empty-week edge case of the layout remains.

**Districts and the world (M4).**
7. One project, one district. No world grid, no goals projection, no world
   overview, no multi-district morning walk.

**Touch and mobile (M6).**
8. Keyboard and mouse only. No joystick, no pinch, nothing measured on a
   phone.
9. The benchmark has no flight or plaza phase and has not been run on the
   current scene.

**Smaller gaps against the design.**
10. Beacons carry no hover label and are not visible through buildings.
11. No auto-align when standing still near a facade.
12. No overview beacon dot; the pose is reached by key, button or the walk.

The design's open questions (section 9 of [DESIGN.md](DESIGN.md)) are all
still open.

## 8. Known limits

- The harness needs a GPU context; of the `scene/` classes only `PlazaWorld`
  and the shopfront strip painter have unit tests.
- Cover art is loaded over HTTP from the public demo media catalogue, so an
  offline run shows facades and billboards without pictures.
- Capturing under Xvfb yields blank widget surfaces (section 4.1).
- Changing a layout slider in the overlay rebuilds the whole scene; the
  camera returns to home.
- Tour and bench modes swallow all input by design; there is no way to
  intervene in a run other than killing it.
- Dependency caveats (`flutter_scene` and the `code_assets` override, the
  CW widget quad, the engine switch for built binaries) are in the concept's
  gotchas; re-read them on every `flutter_scene` bump.

## 9. Glossary

- **Bucket / block**: one UTC week of the project's life, one run of road
  with buildings on both sides.
- **Fold / connector**: the 90° turns and the building-free road between
  two rows.
- **Frontier / plaza**: the newest end of the street and the square that
  opens there; **home** is the pose you land on.
- **Facade**: the street-facing wall of a building, where the widget is.
- **Tier**: far (geometry and lantern), sign (captured once), live (captured
  every frame, interactive). **Capture**: rendering a widget subtree into a
  GPU texture. **Promotion**: a facade moving up a tier.
- **Lantern**: the roof light whose colour is the task's state.
- **Anomaly**: a task whose attention score crosses the threshold.
- **Beacon**: a dot plus the curated pose it flies you to.
- **Landmark**: the week's heaviest building, made taller. **Hero**: a tall
  building that carries a roofline ticker.
- **Waddle**: the penguin demo world (Project Waddle), the only fixture.
