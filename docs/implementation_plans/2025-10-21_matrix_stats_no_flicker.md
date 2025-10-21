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

- Replace `ref.watch(matrixStatsControllerProvider)` in `SyncStatsPage` with a non‑watching wrapper that always renders `IncomingStats()` inside the card.
- Rationale: stop whole‑page rebuilds driven by sent stats.
- Changes:
  - `lib/features/sync/ui/sync_stats_page.dart:18–31`
    - Remove `ref.watch(...)` and `AsyncValue.when(...)` switch.
    - Always render `Scaffold` → `SingleChildScrollView` → `ModernBaseCard` → `IncomingStats()`.
  - Provide a small inline placeholder/skeleton in the Sent panel for first paint if needed (not page‑level).

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

### Phase 3 — Emission Cadence & Guarding (P0/P1)

- Keep 500 ms debounce for sent counts (already implemented); consider 700 ms if minor jank persists.
- Add last‑emitted signature in the service and only emit to `messageCountsController` when payload changes.
- File: `lib/features/sync/matrix/matrix_service.dart:330` (debounce) + emit guard near `_emitStatsNow()`.

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

1) Widget rebuild instrumentation (dev only)
   - Verify only `_MessageCountsView` rebuilds during heavy send; parent and V2 panel remain steady.

2) Matrix service emissions
   - Unit tests to assert debounce + emit‑on‑change behavior for sent stats (no duplicate consecutive emits).

3) Smoke test for Sync Stats
   - Pump `/settings/sync/stats` and assert both sections render; scroll survives continuous send.

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

- [ ] Remove `ref.watch(matrixStatsControllerProvider)` from `SyncStatsPage`; always render `IncomingStats`.
- [ ] Add equality guard to `_MessageCountsView` before `setState`.
- [ ] Optional `RepaintBoundary` around both subpanels.
- [ ] Add last‑emitted signature guard in `MatrixService` before emitting stats.
- [ ] Harden `SyncReadMarkerService.updateReadMarker` (`M_UNKNOWN` handling).
- [ ] Add dev rebuild logging for verification; remove before release if noisy.
- [ ] Analyzer: zero warnings; format code; run unit/widget tests.


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
