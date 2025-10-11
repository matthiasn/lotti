# Sync V2 Migration – Progress Log

Date: 2025-10-11

Scope: Scaffold feature flag, pipeline abstraction, V2 consumer stub, and wiring in service initialization.

Completed
- Added config flag `enable_sync_v2` (default false)
  - Constant: `lib/utils/consts.dart`
  - Init: `lib/database/journal_db/config_flags.dart`
- Created `SyncPipeline` interface
  - File: `lib/features/sync/matrix/pipeline/sync_pipeline.dart`
- Added `MatrixStreamConsumer` (V2 scaffold)
  - File: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
  - Attach-time catch-up implemented (bounded snapshot, sorted, after lastProcessed)
  - Streaming micro-batch added (attachments prefetch → text processing → advance id)
  - Debounced read-marker updates via `SyncReadMarkerService`
  - Live timeline callbacks + bounded live scan to catch mobile-delayed streams
  - Per-event retry with exponential backoff + jitter and retry cap (advances past poisoned events)
  - Failure-safe advancement: do not advance past first not-yet-due failure; retry or skip when cap reached
  - v2Metrics exposed via diagnostics and rendered in Matrix Stats page (with Refresh + Last updated)
- Updated `SyncLifecycleCoordinator` to accept an optional `SyncPipeline`
  - Uses V2 pipeline if provided; falls back to V1 listener otherwise
- Wired selection via DI
  - `lib/get_it.dart`: initialize flags early, read `enable_sync_v2`, pass to `MatrixService`
  - `lib/features/sync/matrix/matrix_service.dart`: construct V2 pipeline and pass into coordinator when flag enabled

Notes / Rationale
- Kept V1 intact; V2 runs only when the flag is enabled (requires restart via DI path).
- Avoided refactoring `SyncEngine` public surface; coordinator now routes start/teardown to either V1 or V2.
- Next steps will implement catch-up + micro-batched processing in `MatrixStreamConsumer`.

Next
- Unit/UI Tests
  - Pipeline V2: catch-up, prefetch, hydration + live timeline tests
    - test/features/sync/matrix/pipeline_v2/matrix_stream_consumer_test.dart
  - Matrix Stats UI: counts, v2Metrics refresh, loading and error states
    - test/features/sync/ui/matrix_stats_page_test.dart
- Integration Tests
  - Split V2 integration into matrix_service_v2_test.dart
  - SAS device verification auto-accept flow (prevents “unverified devices” send block)
  - Reconnect scenario with verification and batch send on both devices
  - Runner script for V2 tests

CI
- Added dedicated V2 workflows and scripts:
  - integration_test/run_matrix_v2_tests.sh
  - .github/workflows/flutter-matrix-v2-test.yml (normal + degraded network jobs)
