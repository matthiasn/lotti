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
- Added unit tests for V2 catch-up and attachment prefetch:
  - test/features/sync/matrix/pipeline_v2/matrix_stream_consumer_test.dart
- Added integration coverage by reusing the Matrix integration test with V2:
  - integration_test/matrix_service_test.dart includes a second test case
    'Create room & join (sync v2)' that runs the full encrypted-room flow
    using the V2 pipeline (no explicit listenToTimeline).
- Next: add a reconnect case to validate catch-up bridging after restart
- Next: add optional metrics counters in V2 (processed/skipped/failures)

CI
- Added dedicated V2 workflows and scripts:
  - integration_test/run_matrix_v2_tests.sh
  - .github/workflows/flutter-matrix-v2-test.yml (normal + degraded network jobs)
