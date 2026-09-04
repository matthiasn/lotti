# Project plaza (prototype)

A walkable 3D "project plaza": one project rendered as a night-time district
of task buildings whose street-facing walls are live Flutter widgets. What
needs attention is lit where it stands and repeated on a Times-Square-like
frontier plaza of billboards, tickers and a jumbotron; roof lanterns show
project health from the sky; beacons fly the camera to curated poses; a
morning walk visits the anomalies; search and a side panel get you to any
task. Built on `flutter_scene` (Flutter GPU / Impeller). It is the
exploration meant to replace the knowledge-graph hairball with a spatial,
memorable map of a project.

This is a **developer harness only**. It is not wired into app routes,
dependency injection or the database, and it never shows user data: it
projects the penguin demo world (`Project Waddle`) and nothing else.

## Run it

```sh
fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart -d macos
```

`-d linux` works too. Flutter GPU must be enabled; `--enable-flutter-gpu`
is a `flutter run` flag only, and a built binary takes the engine switch
from its environment instead (see the handover).

## Environment switches

All read at start-up; none is needed for an interactive session.

| Variable | Read by | Effect |
|---|---|---|
| `PLAZA_TOUR=1` | `dev_main.dart` | Screenshot tour: steps through the fixed poses in `ui/plaza_tour.dart`, printing `PLAZA_TOUR ready <i> <name>` lines; input is ignored |
| `PLAZA_TOUR_ONLY=home,block` | `dev_main.dart` | Restricts the tour to the named stops |
| `PLAZA_BENCH=1` | `dev_main.dart` | Auto-walk benchmark through six LOD budgets, printing `PLAZA_BENCH result` lines; wins over `PLAZA_TOUR` |
| `PLAZA_HIDE=gantry,jumbotron,fillers,skyline,pylons,walls` | `dev_main.dart` | Leaves those pieces out of the scene (`PlazaSceneController(hidden:)`), to isolate what a screenshot shows |
| `PLAZA_TRACE=1` | `dev_main.dart` | Prints one line per painted frame: frame time, engine frames since the last line, flight state, pose and how many solids contain the eye |
| `PLAZA_FPS=auto,60,30` | `dev_main.dart` | The frame-rate cap at start (the HUD control changes it); 60 by default |
| `PLAZA_CLICK=<stop>:<x>,<y>` | `tool/plaza/capture_tour.py` | After capturing that tour stop, clicks the window-relative point and grabs a second `-ticked` frame |
| `LOTTI_WINDOW_SIZE=WxH` | `linux/runner/my_application.cc` | Linux runner window size (a generic Lotti runner feature the capture script uses) |

## What it owns and what it delegates

Owns: the task projection model, the merge-stable street layout and its
fold, the frontier plaza and street furniture, the seeded scenery, the
attention score, beacons, flights, the morning walk, the walker collider
over every solid, the scene graph, the facade
LOD, the widget surfaces, the sprites, the picker, the camera, the HUD, the
search sheet, the side panel, the debug overlay, the tour and the bench.

Delegates: the fixture data to `lib/features/demo` (the penguin world and
its media catalogue), rendering to `flutter_scene`, the window size on Linux
to the runner. Nothing in here is reachable from the shipping app.

## Where the code sits

```
lib/features/plaza/
  dev_main.dart          the harness: boot, input, flights, walk, tour, bench
  data/
    demo_world_projection.dart   penguin demo world to plaza tasks
  domain/                pure Dart, tested without a GPU
    plaza_task.dart      PlazaTask and PlazaTaskState
    street_layout.dart   the merge-stable street with the fold
    plaza_layout.dart    plaza, billboards, furniture, beacons, task poses
    attention.dart       the attention score and lantern state
    flight.dart          camera flights: an S-curve speed profile, the
                         street route between stops, a lift over every
                         solid on the line
    street_network.dart  the street polyline a routed flight follows
    morning_walk.dart    the walk playlist
    solid.dart           a footprint with its height band
    walk_collider.dart   keeps the walker out of every solid at walk height
    scenery.dart         the seeded fillers, towers and skyline, and the
                         solids of the pylons, the gantry, the lamps, the
                         roof panels and the spires
  scene/                 flutter_scene, needs a GPU context
    plaza_world.dart     everything derived from tasks and the clock (pure)
    plaza_scene.dart     the scene graph: sky, road, buildings, fillers, skyline
    facade_lod_manager.dart      far, sign and live facade tiers
    plaza_surfaces.dart  billboards, tickers, markers, signs, banners, jumbotron
    surface_captures.dart        the shared capture bookkeeping and cadences
    plaza_sprites.dart   lanterns, beacons, lamps, spire and chase lights
    wall_textures.dart   window-grid, light-pool and grain textures
    plaza_picker.dart    tap resolution
    plaza_bench.dart     the benchmark phases
  ui/
    facade_widget.dart, billboard_widget.dart, jumbotron_widget.dart,
    ticker_widget.dart, banner_widget.dart, block_marker_widget.dart
    fly_camera_controller.dart   walk camera and flights
    plaza_hud.dart, plaza_search_sheet.dart, task_side_panel.dart,
    debug_overlay.dart, checklist_ticks.dart, plaza_style.dart,
    plaza_chip.dart
    plaza_tour.dart      the tour stops
tool/plaza/capture_tour.py       X11 screenshot capture for the tour
test/features/plaza/             one test file per pure source file
```

## Read next

- [docs/plaza/HANDOVER.md](../../../docs/plaza/HANDOVER.md): what is
  implemented, how to drive it, the tour stops, capturing screenshots, what
  is missing and the known limits.
- [docs/plaza/DESIGN.md](../../../docs/plaza/DESIGN.md): the design this
  implements, with the places where the code departs from it.
- [knowledge/features/plaza.md](../../../knowledge/features/plaza.md): how
  it runs, with the layout invariants, the geometry, the attention score,
  the flight model, the facade tiers and the gotchas.
