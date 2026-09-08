# Cinematic city measurement record

Measured 2026-09-08 against merged main `6f088eabfd032145af10435732efc21234c0b373`.
The comparison is the architecture and light-falloff pass on
`feat/plaza-cinematic-city`, using the same Project Waddle penguin fixture.
The runtime implementation is described in the
[Plaza concept](../../knowledge/features/plaza.md#architectural-recipes).

## Environment and method

- ARM64 Linux VM, Flutter 3.47.2, debug build, isolated Xvfb display.
- 1600 × 1000 viewport, `GDK_SCALE=1`, automatic frame pacing, penguins enabled.
- Existing `PLAZA_BENCH=1` walking sequence, first two phases only. Each phase
  runs for 14 seconds and discards its first four seconds. One run per revision.
- Default phase caps live/sign facades at 4/80. Both runs ended with 28 signs
  and zero activated live facades. This does not measure live checklist editing.
- Builds, captures and tests ran separately from the walking measurements.

| Metric | Merged main | Final architecture pass |
| --- | ---: | ---: |
| Static meshes consolidated | 2,429 | 4,128 |
| Resulting static batches | 216 | 215 |
| Default phase mean frame time | 289.0 ms | 280.6 ms |
| Default phase average FPS | 3.5 | 3.6 |
| Default phase p99 / worst | 466.7 ms | 483.3 ms |
| Far-only phase mean frame time | 2,619.4 ms | 2,166.7 ms |
| Far-only phase p99 / worst | 6,650.0 ms | 4,916.7 ms |

The default phase is approximately level with the baseline; one short VM run
cannot establish a speedup. The far-only phase still contains multi-second
startup stalls despite its warm-up exclusion, so it is not useful evidence of
steady rendering throughput. These numbers **do not verify the user's reported
~120 FPS on macOS**. A profile/release measurement on the target Mac remains
necessary, including flying, activated facades and larger project worlds.

An earlier candidate used full column grids on supporting buildings and
separate cornice pieces across the skyline. Its default phase averaged 408 ms.
That measurement prompted the simplified background recipe retained in the final
change. Static batch count alone had concealed the additional geometry cost.

## Visual and regression checks

Headless native captures cover Home, the jumbotron, Overview, a timeline block
and a shopfront, before any edits and after the final geometry changes. They use
only the penguin fixture and remain outside the repository under
`/tmp/lotti-pr-screenshots/plaza-cinematic-city/{before,after-final}/`.
Follow the [operator notes](HANDOVER.md#review-captures) for capture and publication.

Targeted tests cover bounded architecture, priority-scaled sign geometry,
window texture dimensions and dressing, mesh/material reuse, and reduced
background detail. The new crown and glass tests fail against merged main;
the new renderer tests fail when recessed cores and detail selection are removed.
Native captures additionally check the GPU-only window-depth and halo bindings.

## Density and travel follow-up — 2026-09-09

The next pass tightens and raises the surrounding city, adds swept walking
collision and increases the held-Shift speed to eight times walking speed.
Penguins now start hidden. The architecture-pass captures above were retained
as this pass's before evidence before changing the code.

The same VM, debug build, viewport and walking benchmark produced:

| Metric | Previous architecture pass | Denser city, penguins enabled | Denser city, new default (hidden) |
| --- | ---: | ---: | ---: |
| Static meshes consolidated | 4,128 | 4,128 | 4,128 |
| Resulting static batches | 215 | 198 | 198 |
| Default phase mean frame time | 280.6 ms | 146.4 ms | 131.6 ms |
| Default phase average FPS | 3.6 | 6.8 | 7.6 |
| Default phase p99 / worst | 483.3 ms | 316.7 ms | 266.7 ms |

For the enabled run, the native Penguins checkbox was clicked at the start of
the default phase's four-second warm-up. A capture confirms it was checked.
Both new runs ended with 28 sign facades and zero live facades. No other build,
test, capture or analyzer ran concurrently with either benchmark.

These short runs found no increased frame cost in this VM; they do not establish
a speedup or macOS throughput. The denser collision geometry can alter the
walking path and what remains visible, and VM timing varies between runs.
The benchmark uses normal walking speed, so it does not measure Shift travel.
Tests independently exercise fast steps across thin and rotated walls, wall
sliding and corners, modifier release, and recessed-task clearance.

Five before/after views and an additional native Penguins off/on capture are
staged outside the repository at
`/tmp/lotti-pr-screenshots/plaza-density-speed/`. The checked/unchecked HUD and
character visibility were inspected in the native captures. All 81 targeted
tests passed; replacing the sweep with the former endpoint behavior and restoring
the former speed/layout/legend makes the corresponding regression tests fail.

## Flight follow-up — 2026-09-09

The subsequent flight change rounds street-guide joins with collision-checked
Bezier bends and precomputes a continuous timing spline. Slowdowns spread ahead
of tight turns and steep lifts; holding Shift eases the flight clock up to 8×
and releasing it eases back. The walking measurements above predate this flight
change and are not measurements of flight throughput or planning latency.

All 64 targeted flight/camera tests pass, including continuous corner velocity,
gradual turning, bounded steep-climb speed, exact arrivals, both Shift keys,
release after lost key-up, and frame-cadence invariance. Collision checks include
60 randomized translations/rotations of a thin obstacle at the inside of a bend.
Restoring the old planner/controller makes the new regression checks fail.

An interactive native run on the isolated Xvfb display clicked Morning walk,
pressed and released Shift during flight, and completed three landings. Every
reported camera position was outside the generated world's solids (`inside=0`).
The fixture captures are outside the repository at
`/tmp/lotti-pr-screenshots/plaza-flight/native/`. This verifies native input and
navigation; the VM cannot establish motion quality at the target Mac frame rate.
