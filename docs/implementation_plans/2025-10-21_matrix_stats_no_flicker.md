# Matrix Stats — No Flicker, Isolated Updates

## Summary

- Eliminate page-level flicker on the Matrix Stats view during concurrent send/receive.
- Only the “Sent messages” tiles update; V2/incoming metrics never trigger parent rebuilds.
- Preserve scroll position; keep analyzer clean; tests pass.

## Goals

- Zero visible flicker or layout thrash under heavy traffic.
- Strict isolation: parent page never rebuilds due to stats emissions.
- Stable V2 metrics panel that updates on its own cadence without swapping to a “no data” state.
- Maintain user scroll position while stats update.

## Non‑Goals

- No changes to metrics semantics or data aggregation.
- No switch away from Riverpod; keep existing providers.
- No redesign of the Matrix Stats UI beyond stability/polish.

## Findings

- Top‑level rebuild trigger
  - `SyncStatsPage` currently watches `matrixStatsControllerProvider` in `build()`, causing the entire page subtree to rebuild on every emission (~1–2/s during send).
  - File: `lib/features/sync/ui/sync_stats_page.dart:18`.
- Modal entry is fine
  - `matrix_stats_page.dart` renders `const IncomingStats()` without provider watches at the modal level.
  - File: `lib/features/sync/ui/matrix_stats_page.dart:54`.
- Subpanels are largely decoupled already
  - “Sent” panel uses `ref.listenManual` with a local snapshot and cleanup (no parent dependency).
    - File: `lib/features/sync/ui/matrix_stats/incoming_stats.dart:176`.
  - V2 panel polls the service every 2s with signature gating and no “no data” swap.
    - File: `lib/features/sync/ui/matrix_stats/incoming_stats.dart:159`.
- Log noise
  - Repeated `M_UNKNOWN: Could not find event ... setReadMarker` exceptions during traffic likely do not trigger UI rebuilds but should be hardened to reduce noise.
  - File: `lib/features/sync/matrix/read_marker_service.dart:131`.

## Design Overview

- Parent never watches high‑frequency providers; subtrees own their updates.
- “Sent” updates are debounced and applied from a local snapshot with equality guard.
- V2 panel uses polling + signature changes to update; always present to avoid layout swaps.
- Scroll position preserved via `PageStorageKey`; optional `RepaintBoundary` around subpanels.

## Phases and Changes

### Phase 1 — Remove Page‑Level Watch (P0)

- Status: Completed
- Replace `ref.watch(matrixStatsControllerProvider)` in `SyncStatsPage` with a non‑watching wrapper that always renders `IncomingStats()` inside the card.
- Rationale: stop whole‑page rebuilds driven by sent stats.
- Changes:
  - `lib/features/sync/ui/sync_stats_page.dart`
    - Removed `ref.watch(...)` and `AsyncValue.when(...)` switch.
    - Always renders `Scaffold` → `SingleChildScrollView` → `ModernBaseCard` → `IncomingStats()`.
  - Page shows a stable shell; subpanels manage their own updates.

### Phase 2 — Stabilize Subpanels (P0)

- Sent panel (`_MessageCountsView`):
  - Keep `ref.listenManual` + local snapshot with cleanup.
  - Add equality guard (signature of keys + counts) to avoid redundant `setState`.
  - Optional: wrap in `RepaintBoundary` to isolate paint work.
  - File: `lib/features/sync/ui/matrix_stats/incoming_stats.dart:176`.
- V2 panel (`_V2MetricsPanel`):
  - Retain 2s polling and signature gating; never swap to “no data”.
  - Optional: `RepaintBoundary`.
  - File: `lib/features/sync/ui/matrix_stats/incoming_stats.dart:159`.

Status: Completed
- `_MessageCountsView` uses `ref.listenManual` with signature guard and local snapshot; wrapped in `RepaintBoundary`.
- `_V2MetricsPanel` polls every 2s, updates only on signature change, maintains `lastUpdated`; wrapped in `RepaintBoundary`.

### Phase 3 — Emission Cadence & Guarding (P0/P1)

- Status: Completed
- 500 ms debounce retained for sent counts with test‑mode bypass.
- Added last‑emitted signature in the service; only emits to `messageCountsController` when payload changes.
- File: `lib/features/sync/matrix/matrix_service.dart` (debounce + `_statsSignature` guard in `_emitStatsNow()`).

### Phase 4 — Read‑Marker Error Hardening (P2)

- In `SyncReadMarkerService.updateReadMarker`, catch `M_UNKNOWN … Could not find event` and:
  - downgrade to warn‑level log,
  - do not notify UI providers or invalidate stats,
  - schedule retry after next successful sync or skip silently.
- File: `lib/features/sync/matrix/read_marker_service.dart:131`.

### Phase 5 — Instrumentation (Dev Only) (P1)

- Toggle `debugPrintRebuildDirtyWidgets = true` in dev builds to verify only subpanels rebuild.
- Add debug prints in `build()` of the two panels (guarded by `kDebugMode`) to sample rebuild frequency.

### Phase 6 — UX Polish (P1)

- Optional, non‑blocking:
  - Subtle “Updating…” badge in V2 header during poll cycles (no layout shifts).
  - Skeleton/placeholder inside the Sent tiles until first snapshot loads.

## Data Flow

- Service → Sent stats stream (debounced, emit‑on‑change) → `_MessageCountsView` via `ref.listenManual` → local snapshot → tiles.
- Service → V2 metrics snapshot (pull every 2s) → `_V2MetricsPanel` with signature gating → stable shell.
- No provider watches in the page parent; no cross‑panel dependencies.

## Files to Modify / Add

- Modify
  - `lib/features/sync/ui/sync_stats_page.dart` (remove page‑level provider watch; always render `IncomingStats`).
  - `lib/features/sync/ui/matrix_stats/incoming_stats.dart` (add equality guard to Sent panel; optional `RepaintBoundary`).
  - `lib/features/sync/matrix/matrix_service.dart` (emit guard to avoid duplicate emissions).
  - `lib/features/sync/matrix/read_marker_service.dart` (harden read‑marker errors).

## Tests

Status: Updated and extended; targeted suites passing.

- SyncStatsPage
  - Gates page when feature disabled; page renders without page‑level loader/spinner.
  - File: `test/features/sync/ui/sync_stats_page_test.dart`

- IncomingStats UI
  - Displays sent stats with “Sent (type)” labels; no page‑level loader or error.
  - Stable shell while loading or when controller throws; DB‑apply metrics and legend tooltip rendered.
  - Copy Diagnostics triggers service and shows snackbar; tooltips verified.
  - File: `test/features/sync/ui/matrix_stats_page_test.dart`

- V2 metrics signature gating
  - Identical map does not change `lastUpdated`; changed map updates it.
  - Stabilized time‑based assertion via `tester.runAsync` + 1s delay.
  - File: `test/features/sync/ui/matrix_stats_page_test.dart`

- Actions
  - Refresh invalidates provider and updates metrics (`Key('matrixStats.refresh.metrics')`).
  - Force Rescan calls service and refreshes; Retry Now calls `retryV2Now`.
  - Files: `test/features/sync/ui/matrix_stats_page_test.dart`, `test/features/sync/ui/matrix_stats/metrics_actions_test.dart`, `test/features/sync/ui/matrix_stats/v2_metrics_section_test.dart`

- Scroll preservation
  - `PageStorageKey('matrixStatsScroll')` preserves offset across rebuilds.
  - File: `test/features/sync/ui/matrix_stats_page_test.dart`

- Service: emit‑on‑change with debounce
  - Toggles `isTestEnv = false` to exercise debounce path; two increments within window emit once; subsequent change emits again.
  - File: `test/features/sync/matrix/matrix_service_unit_test.dart`

Analyzer
- Zero warnings; formatted.

Test runs
- Targeted files executed: all passing.

## Performance

- Fewer rebuilds; isolated paints; stable scroll. No regressions expected.

## Edge Cases & Handling

- First render before any stats: show inline placeholder in Sent panel; no page‑level loader.
- V2 metrics disabled: panel renders stable shell; controls still available.

## Rollout Plan

1) Implement Phase 1 (remove parent watch) and Phase 2 (panel equality guard).
2) Add Phase 3 emit guard in service.
3) Verify manually under heavy send/receive; enable rebuild logging in dev.
4) Land P2 hardening for read‑marker errors.
5) Add optional UX polish.
6) Analyzer: zero warnings; format; run tests.

## Open Questions

- Target debounce for sent stats under extreme throughput: keep 500 ms or move to 700 ms?
- Do we want a tiny per‑tile debounce if a specific type oscillates frequently?

## Implementation Checklist

- [x] Remove `ref.watch(matrixStatsControllerProvider)` from `SyncStatsPage`; always render `IncomingStats`.
- [x] Add equality guard to `_MessageCountsView` before `setState`.
- [x] Optional `RepaintBoundary` around both subpanels.
- [x] Add last‑emitted signature guard in `MatrixService` before emitting stats.
- [ ] Harden `SyncReadMarkerService.updateReadMarker` (`M_UNKNOWN` handling).  (P2)
- [x] Analyzer: zero warnings; format code; run unit/widget tests.

## What Changed (Recap)

- Stopped page‑level rebuilds: `SyncStatsPage` renders a stable shell and embeds `IncomingStats` without watching providers.
- Subtrees isolated and repaint‑bounded: `_MessageCountsView` and `_V2MetricsPanel` wrapped in `RepaintBoundary`.
- Stable “Sent” updates: `ref.listenManual` + local snapshot + signature guard to avoid redundant `setState`.
- V2 metrics stability: polling with signature gating and `lastUpdated` timestamp; refresh/force‑rescan/retry now/copy diagnostics wired.
- Service emit‑on‑change: 500 ms debounce + last‑emitted signature equality; test‑mode bypass for determinism.

## Next

- Read‑marker error hardening (P2): suppress expected `M_UNKNOWN` in `SyncReadMarkerService.updateReadMarker` and avoid noisy logs.
- Optional: add rebuild‑count instrumentation in tests to assert no redundant `setState` in the Sent panel.


## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
- Every widget we touch should get as close to full test coverage as is reasonable, with meaningful
  tests.
- Add CHANGELOG entry.
- Update the feature README files we touch such that they match reality in the codebase, not only
  for what we touch but in their entirety.
- In most cases we prefer one test file for one implementation file.
