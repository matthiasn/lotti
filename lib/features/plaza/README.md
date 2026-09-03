# Project plaza (prototype, M0)

A walkable 3D "project plaza": one project rendered as a street of task
buildings whose street-facing walls are live Flutter widgets, built on
`flutter_scene` (Flutter GPU / Impeller). It is the exploration meant to
replace the knowledge-graph hairball with a spatial, memorable map of a
project.

This is a **developer harness only**. It is not wired into app routes,
dependency injection or the database; it runs on seeded synthetic presets
and a projection of the penguin demo world.

```sh
fvm flutter run --enable-flutter-gpu -t lib/features/plaza/dev_main.dart -d macos
```

What lives here:

- `domain/` — pure Dart: the task projection model, the seeded generator
  and the merge-stable street layout (placement is a pure function of
  `(createdAt, id)` bucketed by week, so it survives local-first sync).
- `data/` — the penguin demo world projected into plaza tasks.
- `scene/` — the `flutter_scene` graph and the facade LOD manager (near =
  live widget, mid = captured widget, far = colour plate; hard caps).
- `ui/` — the facade widget, the walk camera, the debug overlay and the
  fixed screenshot tour (`PLAZA_TOUR=1`).

The vision, the screenshots of the current state, the benchmark and its
interpretation, and the full list of why it is not usable yet are in
[docs/plaza/HANDOVER.md](../../../docs/plaza/HANDOVER.md). The proposal for
making it usable (navigation, districts, information design at distance,
performance budget, milestones M1–M6) is in
[docs/plaza/DESIGN.md](../../../docs/plaza/DESIGN.md).

How it runs — the layout invariants, the facade tiers, the harness modes and
the gotchas — is the concept
[knowledge/features/plaza.md](../../../knowledge/features/plaza.md).
