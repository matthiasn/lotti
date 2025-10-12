# Sync V2 Migration – Progress Log

Date: 2025-10-11

Scope: Scaffold feature flag, pipeline abstraction, V2 consumer stub, and wiring in service initialization.

Completed
- Historical: initial rollout proposed `enable_sync_v2`; the project now defaults to the stream-first pipeline without a flag.
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
- Updated `SyncLifecycleCoordinator` to accept a `SyncPipeline` (now always the stream pipeline)
- Wired selection via DI (historical; today the stream pipeline is unconditional)
- `MatrixService` always constructs the stream-first pipeline.
  - `lib/features/sync/matrix/matrix_service.dart`: construct V2 pipeline and pass into coordinator when flag enabled

Notes / Rationale
- Historical: V1 was retained during the rollout behind a flag; the stream pipeline is now the only implementation.
- Coordinator routes lifecycle to the stream pipeline.
- Catch-up + micro-batched processing implemented in `MatrixStreamConsumer`.

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

Issues Investigated (Integration)
- iOS CocoaPods out-of-sync on first run
  - Symptom: "The sandbox is not in sync with the Podfile.lock"
  - Resolution: run `cd ios && pod install` (or `fvm flutter clean` followed by `pod install`). Subsequent runs built successfully.
- FormatException during Sync V2 event processing leading to timeouts
  - Symptom: `FormatException: Unexpected end of input` from `readEntityFromJson` while processing `SyncEventProcessor` events; tests timed out after 30s.
  - Root cause: race condition when saving JSON. `saveJson` created the file and then wrote contents, allowing readers to observe an empty file momentarily.
  - Fix: make JSON writes atomic by writing to a temp file and renaming.
    - Change: lib/utils/file_utils.dart:79
      - Old: create file then `writeAsString`.
      - New: write to `*.tmp` with `flush: true`, then async `rename` to target; Windows-safe fallback moves existing file aside and cleans up `.bak`/`tmp` on success/failure. Avoids empty/partial reads.
  - Impact: `SyncEventProcessor` now reads fully written JSON; V2 retry/backoff remains as guard for genuine transient failures.

How To Verify
- Analyze and format:
  - `make analyze`
  - `make test` (unit suite)
- Integration (requires local homeserver and iOS/macOS tooling):
  - `./integration_test/run_matrix_v2_tests.sh`
  - Ensure variables `TEST_USER1`, `TEST_USER2`, `TEST_SERVER`, `TEST_PASSWORD` set by the script.
  - Expect SAS auto-verify to complete and both tests to pass without timeouts.

Enhancements (landed post-integration)
- Monotonic read-marker advancement to prevent regression with interleaved scans.
- Retry map bounded by TTL and max size; per-batch pruning.
- Circuit breaker (cooldown) after sustained failures; resumes automatically.
- V2 metrics gated by `enable_logging` flag; reduces log noise by default.

L10n and UI
- Localized Sync V2 flag title/description and Matrix Stats labels (Message Type, Count, Metric, Value, Refresh, Last updated).
- Matrix Stats renders V2 metrics with localized labels.

Typed Diagnostics
- Introduced a typed `V2Metrics` model (processed, skipped, failures, prefetch, flushes, catchupBatches, skippedByRetryLimit, retriesScheduled, circuitOpens).
- `MatrixService.getV2Metrics()` returns typed metrics; `getDiagnosticInfo()` still exposes raw maps for compatibility.

Follow-ups
- Consider a small resilience tweak in `FileSyncJournalEntityLoader` to re-read once if a JSON decode fails due to emptiness, though the atomic write eliminates the observed race.

Housekeeping
- Fixed documentation year typos (20025 → 2025) in implementation plan files.
- Updated progress text to reflect async rename and temp/backup cleanup strategy.

Next Steps

Implementation
- Catch-up pagination (SDK tokens): replace doubling snapshot limit with SDK pagination/backfill tokens for large rooms. Keep current logic as fallback.
- Metrics cadence: use existing logging flag or sampling as needed; no dedicated V2 flag.
- Circuit breaker/TTL knobs: read thresholds (failure count, cooldown, retry TTL, retry size cap) from config to allow tuning without code changes.

Testing
- Fake-clock TTL tests: inject a clock into the consumer (or add a test seam) to make TTL pruning fully deterministic.
- Remove internal SDK dependency: replace test import of `matrix/src/utils/cached_stream_controller.dart` with a tiny local test controller.
- Integration coverage: add an integration test that verifies monotonic marker under real event flow and that the breaker pauses/resumes as expected.
- UI tests: add test IDs for metrics rows (avoid relying on localized text). Add tests for metrics gating (on/off) and typed metrics rendering only.

Docs
- Progress log: add a short “Rollout and Observability” section (how to enable V2, where to see metrics).
- Architecture notes: document tie-breaker semantics in `TimelineEventOrdering` (ID lexicographic at equal timestamps). Note circuit breaker/TTL defaults and tuning guidance.
- Consistency: confirm all docs reference async rename (and removal of `renameSync`) and reflect Windows-safe fallback cleanup.

CI
- Add a quick typed metrics widget test job: run only UI/widget tests touching Matrix Stats to catch regressions fast.
- Consider a nightly job: run integration with degraded network + pagination (once implemented) to detect edge cases.

Polish
- Typed diagnostics adoption: move Matrix Stats fully to typed diagnostics and remove fallback map path after a deprecation window.
- Observability: keep the one-off warning when messages are dropped at retry cap (done) and consider surfacing a small “dropped” counter in the UI.

Housekeeping
- Remove debug-only helpers (`debugRetryStateSize`, `debugCircuitOpen`) once the suite stabilizes.
- Add a short README snippet on enabling V2 (feature flag and metrics gating).

Proposed Starting Tasks
- Add SDK pagination to catch-up.
- Inject a clock into the consumer and tighten TTL tests.
- Switch Matrix Stats to typed-only diagnostics and update tests accordingly.

Completed (since last update)
- Tests: removed internal SDK dependency from tests by replacing CachedStreamController usage with standard StreamController and API seams.
- Tests: added deterministic TTL pruning via injected clock; replaced debug helpers with metricsSnapshot fields and updated tests accordingly.
- Consumer: added optional backfill seam and timing knobs (flush interval, batch size, marker debounce) to improve testability without changing prod defaults.
- Catch-up: integrated SDK pagination/backfill path with graceful fallback; added tests for both the seam success path and fallback doubling.
- Streaming: added tests for room ID filtering and batched flush timing under rapid event bursts.
- Live callbacks: added a focused test to validate that combined callbacks coalesce into a single scan.
- Metrics: added coverage to assert metricsSnapshot contains and increments expected counters under mixed scenarios.
