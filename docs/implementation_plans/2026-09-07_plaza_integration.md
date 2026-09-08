# Plaza integration

Requested scope: project integration, generative timeline streets, priority-sized
billboards, readable green completion signals and overdue fire, followed by
category avenues and completed-work distance, then optional ambient creatures.

## Implemented scope

1. Extract and test the shared journal-to-plaza projection, preserving checklist
   identity. Capture the base project entry and GPU scene outside the repository.
2. Read project membership through the existing privacy-filtered repository;
   bulk-resolve checklists, links and covers. Preserve rendered data and camera
   state across background notifications. Keep the demo launcher a fixture client.
3. Extract a reusable scene host and open it from project details. Reuse existing
   task navigation and checklist persistence; localize app-facing labels and use
   existing design-system tokens for app chrome.
4. Parameterize generation, retain week markers, scale priority billboards, expose
   green completion from the overview and add bounded, instanced overdue flames.
5. Add a category-scoped avenue view leading into individual project worlds;
   keep completed work green, quieter and farther from the active foreground.
6. Add ambient life only after the required integration paths are working.
7. Validate changed files headlessly, capture entry surfaces, and record CPU
   generation costs. Native GPU comparison remains outstanding.

## Validation boundaries

- This workspace is a Linux VM. GPU captures and before/after performance here
  do not establish the user's reported macOS 120 FPS baseline.
- Screenshot fixtures are the penguin demo world, never user data. Assets and
  measurements stay outside the repository; review URLs can be published once
  a commit exists.
- The standalone prototype requires Flutter GPU at engine startup. Integration
  must handle unsupported rendering gracefully and configure the macOS runner.
- Draft PR [#4200](https://github.com/matthiasn/lotti/pull/4200) targets `main`
  from `feat/project-plaza-integration`; the user requested it on September 8.

## Verification record — September 8, 2026

- Full Dart MCP analyzer: no diagnostics.
- Full application compilation: `fvm flutter build linux --debug -t lib/main.dart`
  succeeded. This validates the Linux ARM64 runner and app; macOS and Windows
  runner builds were not available in this environment.
- Changed-source test set: 411 passed across 36 files; the opt-in CPU benchmark
  was skipped in that run and passed separately with profiling enabled.
- Six regression tests failed with their relevant fixes removed and passed
  after restoration: category search refresh, category drilldown scope, immediate
  private-data invalidation, moved-task checklist writes, complete checklist
  counts despite capped previews, and unbounded overview framing.
- Headless project list/detail screenshot harness: four passed, covering light
  and dark themes. Before/after pairs are staged outside the repository at
  `/tmp/lotti-pr-screenshots/plaza-integration/`. They use the penguin fixture.
  Native scene before captures are also staged there; matching native after
  macOS captures remain outstanding. The later night-city pass found and fixed
  an early-capture race; settled Xvfb views display widget text and cover art.
- `make knowledge_check`: 101 concepts, 540 Mermaid blocks, no errors; the
  validator's 25 tests passed. `make changelog_check` passed.
- Capture-script window selection was checked with synthetic window trees:
  only the launched process's full-size window is selected. No app was opened.

## Draft PR follow-up

- The first CI run passed all ten unit/widget shards, Glados property tests,
  analysis, Android compilation and macOS compilation. Native rendering and
  sustained FPS still need target-device verification.
- Codecov identified the extracted GPU host plus uncovered integration paths.
  The host follows the existing native-GPU exclusion; pages, providers and
  independent input/frame controllers remain subject to the 99% patch target.
  Added tests cover category refresh, resume-time attention, scope changes,
  task-detail routing, failed checklist writes, cover paths and portal copy.
- A reported Back-navigation crash was reproduced headlessly: reattaching a
  retained scroll region beneath a new route translation asserted `hasSize`.
  Viewport-relative measurement fixes that path; the regression fails with
  global measurement and all 27 scroll-stability tests pass with the fix.
- Follow-up validation: 107 targeted tests passed across the nine touched test
  files; the full analyzer has no diagnostics. The crash regression was rerun
  with the fix reverted and reproduced the same `RenderFractionalTranslation`
  assertion before restoration.

## CPU generation measurements

Same four-vCPU ARM64 Linux VM, Flutter 3.47.2 headless debug test runner,
`syntheticPlazaTasks` at 28, 100 and 500 tasks. Each run discards ten warm-up
samples and reports thirty timed samples. Construction excludes database reads,
GPU meshes/textures, frame rendering and widget mounting. Before is the original
`PlazaWorld` with `StreetLayout(projectSeed: 1337)` at base `bf29bd319`; after is
`generateProjectWorld` with its integration defaults. Those defaults deliberately
add plot spacing, completed-work setbacks and priority sizing, so these measure
the shipped configurations rather than identical geometry.

| Tasks | Before median / p95 | After median / p95 |
|---|---|---|
| 28 | 0.695 / 1.974 ms | 0.887 / 2.576 ms |
| 100 | 3.394 / 5.423 ms | 3.689 / 4.285 ms |
| 500 | 91.576 / 97.880 ms | 110.929 / 127.208 ms |

The 500-task construction cost can stall a synchronous refresh; it is a known
scaling limit, not a per-frame cost. LOD, instancing, fixed fire/creature budgets
and retained camera state are implemented, but they do not prove sustained FPS.
No trustworthy before/after native frame-time comparison was obtained. The
reported macOS ~120 FPS remains user-provided baseline information, not a result
verified in this VM. Follow the fixture measurement instructions in
[the operator notes](../plaza/HANDOVER.md) on the target Mac.


## Night-city and optional penguins follow-up (2026-09-08)

Rebased onto `2fac43d50488949c0627314e3e1fc74b154ed424`, including the animated
penguin model from main. The shared renderer uses it with a whole-group budget
and a localized visibility control. The architectural pass adds the bounded
building recipes, project crown, status roofs and map context separation.

A second CPU comparison uses the same `generateProjectWorld` defaults before
and after the architectural recipes, on the same VM and the same test fixture:

| Tasks | Rebased baseline median / p95 | Night-city median / p95 |
|---|---|---|
| 28 | 1.886 / 3.693 ms | 1.156 / 4.560 ms |
| 100 | 3.559 / 7.750 ms | 4.265 / 12.302 ms |
| 500 | 134.780 / 191.512 ms | 127.588 / 179.515 ms |

These short VM runs are noisy; they do not establish a speedup or a sustained
frame-rate result. They exclude character route construction, GPU work, database
reads and widget mounting. The 500-task synchronous construction limit remains.
The default character budget now bounds actual spawned rigs to 24 (the fixture
previously spawned 78 despite that configured budget).

The old Home screenshot raced texture capture and frame presentation. A settled
return to Home displayed both text and cover art correctly; the tour now gates
its ready marker on capture acknowledgement and completed raster timing. Linux
fixture captures are usable for visual review. The reported macOS 120 FPS still
requires a target-device profile; these captures cannot verify it.
