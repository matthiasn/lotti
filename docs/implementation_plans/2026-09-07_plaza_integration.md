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
- The user authorized a local commit on September 8. No push or PR was requested.

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
  captures remain outstanding because the virtual display corrupts textures.
- `make knowledge_check`: 101 concepts, 540 Mermaid blocks, no errors; the
  validator's 25 tests passed. `make changelog_check` passed.
- Capture-script window selection was checked with synthetic window trees:
  only the launched process's full-size window is selected. No app was opened.

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
