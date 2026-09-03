# Project plaza (prototype)

A walkable 3D "project plaza": a project rendered as a district of task
buildings whose street-facing walls are live Flutter widgets, with a
Times-Square-like frontier plaza of billboards for what needs attention,
roof lanterns that show project health from the sky, beacons that fly you
to curated poses, and a morning walk over the anomalies. Built on
`flutter_scene` (Flutter GPU / Impeller). It is the exploration meant to
replace the knowledge-graph hairball with a spatial, memorable map of a
project.

This is a **developer harness only**. It is not wired into app routes,
dependency injection or the database; it runs on the penguin demo world
(and a synthetic district for the benchmark and the tests).

```sh
fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart -d macos
```

What lives here:

- `domain/` — pure Dart: the task projection model, the attention score,
  the merge-stable street layout with its fold, the frontier plaza and the
  beacon network, camera flights, the morning walk, the walker collider,
  and the seeded generator.
- `data/` — the penguin demo world projected into plaza tasks.
- `scene/` — `PlazaWorld` (everything derived from tasks and the clock),
  the `flutter_scene` graph, the facade LOD manager, the plaza surfaces
  (billboards, tickers, week markers), the sprites (lanterns, beacons), the
  tap picker and the benchmark.
- `ui/` — the facade in its sign and live variants, the billboard, ticker
  and week-marker widgets, the walk camera, the HUD, the search sheet, the
  side panel, the debug overlay and the screenshot tour.

The vision, the screenshots, and what is still missing are in
[docs/plaza/HANDOVER.md](../../../docs/plaza/HANDOVER.md); the design this
implements is [docs/plaza/DESIGN.md](../../../docs/plaza/DESIGN.md).

How it runs — the layout invariants, the attention score, the flight model,
the facade tiers and the gotchas — is the concept
[knowledge/features/plaza.md](../../../knowledge/features/plaza.md).
