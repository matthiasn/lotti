# Sync Redundant Fetching Loop Fix

## Status: IN PROGRESS

## Goal

Stop the redundant fetch/retry loop by gating descriptor catch-up and treating
stale descriptors as superseded when the local DB already has a newer or equal
vector clock, while preserving missing-descriptor recovery.

## Requirements

- Eliminate repeated descriptor catch-up runs and retryNow thrashing without
  rate-limiting logs.
- Stale descriptors can be skipped when the DB already holds newer/equal data.
- Missing-descriptor failures must still block marker advancement until
  resolved.
- Add/adjust tests and keep analyzer clean.

## Scope

- In: descriptor catch-up scheduling, retry gating for descriptor errors, stale
  descriptor superseded skips, tests, changelog/docs as needed.
- Out: Matrix SDK changes, backfill algorithm changes, or network-layer
  behavior.

## Files and entry points

- lib/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart
- lib/features/sync/matrix/pipeline/attachment_index.dart
- lib/features/sync/matrix/sync_event_processor.dart
- test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart
- test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart
- test/features/sync/matrix/sync_event_processor_test.dart
- CHANGELOG.md
- lib/features/sync/README.md (if behavior is documented there)

## Action items

- [ ] Add a pending-set version guard so DescriptorCatchUpManager runs only when
  the pending set changes.
- [ ] Trigger retryNow/live scan only when catch-up records a new descriptor for
  a pending path.
- [ ] Skip stale-descriptor errors when DB already holds newer/equal vector
  clocks (treat as older_or_equal) and still update sequence logs.
- [ ] Update tests for descriptor catch-up behavior and superseded stale
  descriptor skip logic.
- [ ] Update CHANGELOG.md and sync docs if needed.
- [ ] Run formatter, analyzer, and targeted tests via dart-mcp.

## Testing and validation

- dart-mcp.dart_format (touched files)
- dart-mcp.analyze_files (targeted)
- dart-mcp.run_tests for:
  - test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart
  - test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart
  - test/features/sync/matrix/sync_event_processor_test.dart

## Risks and edge cases

- Pending paths must still resolve when descriptors arrive later; no deadlocks.
- Superseded skips must not drop genuinely missing newer updates.

## Open questions

- Should concurrent vector clocks ever be treated as superseded (likely no;
  treat as conflict)?
