# Connection cable measurement record

Measured 2026-09-09 on `feat/plaza-connection-cables`, rebased onto main
`459a5e642`. Both measurements use the final cable implementation and the
same Project Waddle fixture: 28 tasks and 51 real task associations. The
[Plaza concept](../../knowledge/features/plaza.md) describes the implementation.

## Environment and method

- ARM64 Linux VM, Flutter 3.47.2, debug build, isolated Xvfb display.
- 1600 × 1000 viewport, automatic frame pacing, penguins and meerkats hidden.
- Existing `PLAZA_BENCH=1` walking sequence. Each phase lasts 14 seconds and
  excludes its first four seconds. One run per configuration.
- The comparison uses the second, default phase (4 live / 80 sign facade
  budget). Both runs ended with 28 signs and zero live facades. The first
  phase retained startup stalls and is excluded from the comparison.
- The disabled run uses `PLAZA_HIDE=cables`, bypassing cable construction.
- No QA build, test, capture or analyzer ran concurrently with these runs.
  Other host activity was not controlled.

| Metric | Cables disabled | Cables enabled |
| --- | ---: | ---: |
| Ordinary static meshes / batches | 4,128 / 198 | 4,128 / 198 |
| Additional cable meshes / batches | 0 / 0 | 559 / 4 |
| Moving light instances | 0 | 102 |
| Mean frame time | 151.5 ms | 154.3 ms |
| Average FPS | 6.6 | 6.5 |
| p99 / worst frame time | 266.7 ms | 333.3 ms |

Moving lights share one instanced draw, with a maximum of 192 instances. The
2.8 ms mean difference in this single noisy VM comparison does not establish
a reliable cable cost or target-device throughput. These results **do not
verify 120 FPS on macOS**. Profile/release measurements on the target Mac,
including larger relationship graphs and active billboards, remain necessary.

## Native and regression checks

The final Linux native build succeeds. Headless fixture captures verify Home,
Overview, hiding the cable network, selecting a task from search, boosted
flight to that task, retaining its highlighted connections in Overview, and
clearing the selection with Escape. Reported flight positions stayed outside
the generated collision solids.

All 243 targeted tests pass, with one existing opt-in performance test skipped;
the full analyzer reports no errors. Tests exercise scoped typed relationships,
rotated/thin obstacle clearance, sag sampling, shared roof supports, light
direction and budgets, reduced motion, snapshot refresh and HUD controls.
The two navigation regressions and the lock-during-read regression fail when
their production fixes are removed. The navigation checks reproduce duplicate
Heroes in inactive tabs; they do not independently reproduce the reported
native engine disconnect.

Review captures use fixture data only and are published separately from the
repository. Follow the [operator notes](HANDOVER.md#review-captures) for capture
and publication.
