# Matrix Live Events → Signal-Only Rescan/Catch‑Up

## Summary

- Devices can miss updates when a live event advances the read marker beyond unseen backlog during offline windows. The next catch‑up then skips older events.
- The former pipeline processed client stream events directly and could advance markers before a catch‑up ran.
- Change: Treat all live events as lightweight signals to rescan/catch‑up, never as units to process directly. This keeps marker advancement coupled to ordered slices from timeline scans/catch‑up only.

## Current Behavior (grounded)

- Client stream previously enqueued per‑event work; now it only signals scans:
  - `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart` subscribes to `timelineEvents` and calls `_scheduleLiveScan()` (no `_enqueue`).
- Live timeline callbacks already behave as a signal:
  - `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart` attaches `onNewEvent`/`onUpdate` etc → `_scheduleLiveScan()`.
  - `_scheduleLiveScan()` debounces and calls `_scanLiveTimeline()`.
- Connectivity regain nudges the pipeline:
  - `lib/features/sync/matrix/matrix_service.dart:292-315` calls `pipeline.forceRescan()` on online.
- Marker advancement happens only during ordered batch processing:
  - `_processOrdered()` computes `latestEventId` over sync payloads and persists local + schedules remote marker (`lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`).

## Problem

- When the device is offline and later receives a newer live event first via the client stream listener, `_enqueue → _flush → _processOrdered` can advance the marker to that newer event. The subsequent catch‑up backfills “after” that marker, skipping older backlog. This matches the observed “audio normalization” task missed on mobile.

## Goals

- Eliminate direct per‑event processing from the client stream.
- Use live events and connectivity as coalesced signals to run a rescan/catch‑up.
- Keep read marker advancement strictly tied to ordered slices from scans/catch‑up.
- Preserve performance via debouncing, look‑behind tails, and existing drop‑old logic.

## Non‑Goals

- No changes to attachment ingestion, descriptor catch‑up manager, or vector‑clock semantics.
- No changes to UI/metrics beyond adding optional signal counters if helpful.

## Design Overview

- Replace the client stream’s `_enqueue(event)` with a nudge:
  - On the first stream event after starting, call `forceRescan(includeCatchUp: true)` to ensure a
    catch‑up precedes any tail scans.
  - On subsequent events, debounce `_scheduleLiveScan()` only (avoid per‑event processing).
- Keep live timeline callbacks as is (they already schedule scans only).
- Maintain existing connectivity regain nudge (`MatrixService`), which already triggers
  `forceRescan()`.
- Marker advancement remains exclusively inside `_processOrdered()` run by scans/catch‑up.

## Changes by Component

- MatrixStreamConsumer
  - Start listener:
    - Change `timelineEvents.listen` handler (
      `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:498-512`):
      - Keep the first‑event `forceRescan()` branch.
      - Replace `_enqueue(event)` with `_scheduleLiveScan()`.
      - Add a debug log for signal nudge.
- Remove `_enqueue/_flush`, `_pending`, `flushInterval`, and `maxBatch`. Catch‑up and live scans
    are the only sources that call `_processOrdered()`.
  - No changes to `_attachCatchUp()` and `_scanLiveTimeline()`; they already sort, dedupe, and apply
    monotonic rules.

- MatrixService
  - No structural change required. Connectivity handler already invokes `pipeline.forceRescan()` on
    online.

- SyncReadMarkerService
  - No change. It already guards remote regression and persists locally first (
    `lib/features/sync/matrix/read_marker_service.dart`).

## Data Flow After Change

- Stream event arrives → debounce `_scheduleLiveScan()` (first event also triggers `forceRescan()`
  once) → `_scanLiveTimeline()` and/or `_attachCatchUp()` build ordered slices → `_processOrdered()`
  applies updates and advances marker.
- Offline windows recover reliably because marker can only move after ordered scan/catch‑up, not
  from a single out‑of‑context stream event.

## Risks & Mitigations

- Slightly slower first‑paint ingestion of a single event vs direct stream processing.
  - Mitigation: First stream event triggers `forceRescan(includeCatchUp: true)` immediately; live
    scan debounce remains tight (120ms).
- Increased reliance on live timeline snapshot availability.
  - Mitigation: Existing startup hydration + initial catch‑up retry loop already ensure room
    readiness and catch‑up attempts.
- Potential test expectations relying on `_enqueue` path.
  - Mitigation: Most tests already stub `timelineEvents` as empty and rely on live scans.
    Update/extend only tests that depend on the client stream path.

## Implementation Steps

1. Replace client stream per‑event processing with signal
  - Edit `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`:
    - In `start()` at `:498-512`:
      - Keep the first‑event `forceRescan()` branch.
      - Replace `_enqueue(event)` with `_scheduleLiveScan()`.
      - Add a debug log for signal nudge.
2. Optional: Add a small counter to metrics (e.g., `signalClientStream`) if useful in diagnostics.
3. Verify marker semantics remain unchanged (advances only during `_processOrdered()` from
   scans/catch‑up).
4. Tests (targeted):
  - New: “Client stream event does not advance marker directly”
    - Arrange: last marker M; push a newer sync payload through `timelineEvents`; ensure no
      `updateReadMarker` call until a live scan runs; then simulate timeline snapshot containing the
      event and verify advancement happens after scan.
  - New: “First stream event triggers forceRescan(includeCatchUp=true)”
    - Stub consumer and verify `forceRescan` call when first event arrives.
  - Existing coverage: MatrixService connectivity → `forceRescan()` path remains; live scan
    look‑behind and drop‑old payload logic already tested.
5. Documentation
  - Update `docs/sync/*` rationale for signal‑driven ingestion.
  - Add CHANGELOG entry summarizing behavior change.

## Analyzer/Test Discipline (AGENTS.md)

- Run `dart-mcp.analyze_files` and ensure zero warnings before PR.
- Run focused tests for the modified pipeline file via `dart-mcp.run_tests` and then the full suite.
- Format via `dart-mcp.dart_format`.
- Maintain one test file per implementation file principle; add tests under
  `test/features/sync/matrix/pipeline_v2/`.
- Ensure tests and analyzer pass before creating new files.

## Rollout

- Ship as default behavior (no feature flag) to remove races. Permanently stop processing client
  stream events directly; live events act only as signals.

## Acceptance Checklist

- No direct `_enqueue` from client stream; live events only schedule rescan/catch‑up.
- Marker advancement observed only after scans/catch‑up in logs.
- Connectivity nudge still triggers recovery.
- Analyzer/test suite green; CHANGELOG and docs updated.

---

## Refinements Based on Review

### 1) _enqueue/_flush Path Clarification
- After this change, the client stream no longer calls `_enqueue`, so `_pending` remains empty in the default configuration.
- Keep `_enqueue/_flush` for the legacy/rollback path and tests. They are not exercised when running in signal‑only mode.
- Documented behavior:
  - Default: `_pending.length == 0` unless `processClientStreamEvents == true` (see Migration Toggle).
  - `_flushInterval` and `_maxBatch` only apply to the legacy path.

### 2) Rollback/Migration
- No rollback toggle. The client stream no longer feeds `_enqueue` at all. Tests must adapt to
  signal‑only behavior.

### 3) Performance Considerations
- `_flushInterval` and `_maxBatch` become effectively unused. Retain temporarily for internal batch
  helpers (and potential future use), mark them as legacy in docs, and expect `flushes` to remain 0
  in steady state.

### 4) Error Handling in Listener
- `_scheduleLiveScan()` schedules a timer; `_scanLiveTimeline()` already has try/catch.
- Implemented:
  - If `_liveTimeline == null`, we log `signal.noTimeline` (safe to ignore; hydration/attach will enable scans shortly).
  - Wrap scheduling in try/catch; on error, log and fall back to `forceRescan(includeCatchUp: true)`.

### 5) Metrics and Observability
- Implemented when `collectMetrics == true`:
  - `signalClientStream` — client stream signal nudges.
  - `signalConnectivity` — connectivity‑driven nudges (recorded via `MatrixService ➜ pipeline.recordConnectivitySignal()` before `forceRescan`).
  - `signalTimelineCallbacks` — live timeline callback nudges.
- Latency tracking:
  - Record `lastSignalAt` on signal; compute latency at the start of `_scanLiveTimeline()`; expose `signalLatencyLastMs`, `signalLatencyMinMs`, `signalLatencyMaxMs`.
- Expect `flushes` to be 0 in signal mode; not a regression.

### 6) Edge Cases
- `_liveTimeline == null` at signal time:
  - We log and still schedule the scan (safe no‑op). Hydration/catch‑up flows will bring the timeline online.
- Rapid event bursts:
  - Debounce remains 120ms; optionally coalesce concurrent scans via a `_liveScanInFlight` flag to skip overlapping scans if we see churn (can be added if needed post‑rollout).

### 7) Test Strategy Enhancements
- Unit tests under `test/features/sync/matrix/pipeline_v2/`:
  - “Client stream signals rescan (no direct processing)”: verify `_scheduleLiveScan` is called, `_enqueue` is not, and first event triggers `forceRescan(includeCatchUp: true)`.
  - “Pending queue stays empty in signal mode”: push N stream events and assert `_pending.isEmpty`; advancement occurs only after simulated `_scanLiveTimeline()`.
  - “Live timeline null at signal”: no crash; delayed `forceRescan` gets scheduled.
  - Remove legacy‑path tests. No constructor flag; the stream never calls `_enqueue`.
- Integration scenario:
  - Simulate offline backlog → go online, ensure backlog is applied via catch‑up before marker advances to any newer live event.

### 8) Monitoring Plan
- Extend `metricsSnapshot()` and `diagnosticsStrings()` to include signal counters
  (`signalClientStream`, `signalTimelineCallbacks`, `signalConnectivity`) and latency
  (`signalToScanLatencyMs.last/min/max`).
- Continue logging marker regression guards via `SyncReadMarkerService`.

### 9) Documentation and Deprecations
- Document default signal‑driven ingestion in `docs/sync/` and mark `_flushInterval`/`_maxBatch`
  as legacy knobs that are unused by the live signal path.
- Remove V2 from function names, directories, documentation, as there is only one version now.

### 10) Updated Acceptance
- In default mode, stream events do not directly invoke `_processOrdered()`; only scans/catch‑up do.
- Metrics indicate `mode=signal` and show non‑zero signal counters; `flushes` may be 0.
- Offline → online recovery shows backlog applied before any marker advancement to newer events.
