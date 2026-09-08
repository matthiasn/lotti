# Plaza operator notes

The desktop feature now uses app data. Its entry points and behavior are in the
[feature README](../../lib/features/plaza/README.md); data boundaries, scene
lifecycle and rendering budgets are in the
[Plaza concept](../../knowledge/features/plaza.md). [DESIGN.md](DESIGN.md)
records the original prototype direction, including unimplemented future ideas.

## Fixture launcher

Visual reviews and measurements must use the penguin fixture, never a user's
own tasks, projects, screenshots or journal. The fixture launcher exercises the
same renderer and generator configuration as the app:

```sh
fvm flutter run -d macos -t lib/features/plaza/dev_main.dart
```

The macOS, Linux and Windows runners enable Flutter GPU at engine startup.
The fixture can also be built without opening a window:

```sh
fvm flutter build linux --debug -t lib/features/plaza/dev_main.dart
```

A built Linux fixture lives at `build/linux/arm64/debug/bundle/lotti` (use
`x64` on an Intel host). Running that binary opens a window. On unsupported
backends the explorer shows an unavailable message; unit/widget tests don't
provide the GPU context needed to render the scene.

## Controls

| Input | Effect |
|---|---|
| WASD or arrows | Walk; hold Shift for 8× speed (27.2 m/s). Movement from altitude first lands safely. |
| Primary-button drag | Look. |
| Tap a beacon or distant building/sign | Fly to its curated pose. |
| Tap a nearby facade | Activate its controls. |
| Tab / Shift-Tab | Next / previous navigation beacon. |
| H | Home. |
| M | Aerial overview. |
| Backspace / Command-[ | Previous camera pose, then exit the world. |
| / | Search this world's titles; arrows select, Enter flies, Escape closes. |
| Space | Pause or resume the Morning walk. |
| Escape | Close the demo panel and end the walk. |
| Backtick | Toggle rendering diagnostics. |
| Penguins / Meerkats checkboxes | Hide or show each species without moving the camera. |

Any manual movement exits the Morning walk. App task facades persist checklist
edits and open the normal task details page; category facades enter their
project. The fixture's edits remain in memory and its details open a demo panel.
The HUD also offers Back, Morning walk, Overview, Home and frame-rate controls.
Both species start hidden; use their Penguins or Meerkats checkbox to enable them.
Hold Shift during a flight to accelerate up to 8× speed; releasing it eases back
to normal speed. Shift alone does not abandon Morning walk.

## Headless workflow

Use the Dart MCP server's targeted unit/widget tests for normal development.
They do not open an app window. Register the repository root first and follow
[test/README.md](../../test/README.md) for GPU-free seams and fake time.
A build alone also opens no window.

A Linux scene smoke check can run on an isolated virtual display:

```sh
xvfb-run -a -s '-screen 0 1600x1000x24' env GDK_SCALE=1 \
  PLAZA_TOUR_ONLY=home \
  python3 tool/plaza/capture_tour.py /tmp/lotti-pr-screenshots/plaza/after
```

Settled Xvfb captures show widget text and cover art on this VM. Earlier blank
Home signs were an early screenshot: the tour now waits for acknowledged still
captures and raster completion before announcing a settled stop. These images
are useful for Linux geometry and UI review; frame times from a VM do not
establish macOS GPU performance. Target-device runs still need a real display
and should only be launched when a visible window is welcome.

## Review captures

`tool/plaza/capture_tour.py` needs Python Xlib and Pillow. It selects the window
owned by the process it launched, rather than matching a title that could belong
to a terminal or another app. It prints and captures the fixture's settled tour
stops, then terminates its own process.

```sh
PLAZA_TOUR_ONLY=home,overview,attention-closeup \
  python3 tool/plaza/capture_tour.py /tmp/lotti-pr-screenshots/plaza/after
```

Available stops are home, jumbotron, overview, block, shopfront, billboard and
attention-closeup. Impossible stops are skipped. `PLAZA_HIDE` accepts scene pieces
such as `fire`, `life`, `fillers`, `skyline`, `gantry`, `jumbotron`, `pylons` and
`walls`. `PLAZA_CLICK="attention-closeup:<x>,<y>"` adds a checkbox capture.
The default window size is 1600×1000; `LOTTI_WINDOW_SIZE` overrides it.

Project entry surfaces also have a headless fixture harness in
`test/features/projects/ui/pages/projects_manual_screenshots_test.dart`.
Use `LOTTI_SCREENSHOT_DIR` to stage every capture outside the repository. Follow
[the screenshot convention](../../knowledge/conventions/screenshots.md) for
before/after pairs and publication after a commit exists. Never commit images.

## Measurements

`PLAZA_BENCH=1` runs the existing walking benchmark and prints a result per LOD
budget. `PLAZA_TRACE=1` adds rendering traces; `PLAZA_FPS` selects the
pacer. Compare the same build mode, fixture, display scale, viewport and frame
cap, including the Penguins checkbox state. Penguins start hidden; enable them
when comparing against older runs with companions on. Normal idle caps deliberately reduce FPS, so idle FPS is not a throughput
measurement. `PLAZA_HIDE=fire,life` isolates the new animation layers.

The integration's measurement record and hardware limitations are kept in
[the implementation notes](../implementation_plans/2026-09-07_plaza_integration.md).
The subsequent [cinematic city measurements](CINEMATIC_CITY_MEASUREMENTS.md)
compare the architecture pass with its merged baseline and record the subsequent
density and faster-travel pass. A Linux VM measurement
cannot establish the reported macOS ~120 FPS baseline.

## Remaining boundaries

- No agent-driven alternative-world regeneration UI; generation is configurable.
- No mobile joystick/pinch controls or mobile GPU measurements.
- No persistent vacant-plot reservation: density and new-week changes can move
  downstream geometry. Project dates anchor the timeline, not reserved parcels.
- Category avenues show aggregate project portals; full project worlds load on
  entry, so there is no simultaneous rendering of every category task.
- The original benchmark walks; it does not measure a dedicated flying phase.
- Status edits happen in the regular task page. Link lines, hover labels and
  automatic alignment near a facade remain future work.
