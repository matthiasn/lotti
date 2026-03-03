# Outbox Priority Queue & Sync Observability

**Date:** 2026-03-03
**ADR:** `docs/adr/0013-outbox-priority-queue.md`
**Status:** In Progress

## Overview

Adds priority-based ordering to the outbox queue so user edits sync before
bulk resync items, and instruments the sync pipeline with structured domain
logging for diagnosability.

## Implementation Steps

### Part A: Outbox Priority Queue

1. **Add `OutboxPriority` enum** in `outbox_state_controller.dart`
2. **Add `priority` column** to `Outbox` table in `sync_db.dart`
3. **Bump schema version** 5 → 6 with migration
4. **Update query ordering** in `oldestOutboxItems`, `claimNextOutboxItem`,
   `watchOutboxItems`
5. **Assign priority** in `enqueueMessage()` based on `SyncMessage` type
6. **Update `claimNextOutboxItem` return** to include priority field
7. **Migration test** for v5 → v6 upgrade
8. **Priority ordering tests** verifying query behavior

### Part B: Sync Observability

1. **Inject `DomainLogger`** into sync components (OutboxService,
   OutboxProcessor, SyncEventProcessor, MatrixStreamProcessor,
   BackfillRequestService, BackfillResponseHandler, SyncSequenceLogService)
2. **Instrument outbox SEND path** with domain logger calls
3. **Instrument RECEIVE/ingest path** with domain logger calls
4. **Instrument backfill path** with domain logger calls
5. **Create `SyncHealthReporter`** — periodic 5-minute health summary
6. **Wire `DomainLogger`** into sync providers

### Part C: Documentation

1. ADR 0013
2. This implementation plan

## Files Modified

| File | Changes |
|------|---------|
| `lib/database/sync_db.dart` | Priority column, schema v6, migration, updated queries, health queries |
| `lib/features/sync/state/outbox_state_controller.dart` | `OutboxPriority` enum |
| `lib/features/sync/outbox/outbox_service.dart` | Priority assignment, DomainLogger |
| `lib/features/sync/outbox/outbox_processor.dart` | DomainLogger |
| `lib/features/sync/matrix/sync_event_processor.dart` | DomainLogger |
| `lib/features/sync/matrix/pipeline/matrix_stream_processor.dart` | DomainLogger |
| `lib/features/sync/sequence/sync_sequence_log_service.dart` | DomainLogger |
| `lib/features/sync/backfill/backfill_request_service.dart` | DomainLogger |
| `lib/features/sync/backfill/backfill_response_handler.dart` | DomainLogger |

## New Files

| File | Purpose |
|------|---------|
| `lib/features/sync/health/sync_health_reporter.dart` | Periodic health summary |
| `test/features/sync/health/sync_health_reporter_test.dart` | Tests |
| `test/database/sync_db_migration_test.dart` | Migration tests |

## Verification

1. `make build_runner` — regenerate Drift code
2. `dart-mcp.dart_format` — all formatted
3. `dart-mcp.analyze_files` — zero warnings
4. `dart-mcp.run_tests` — targeted tests green
