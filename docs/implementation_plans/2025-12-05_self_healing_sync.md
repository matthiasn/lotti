# Self-Healing Sync Implementation Plan

**Date**: 2025-12-05

## Overview

Implement a self-healing synchronization mechanism that detects gaps in the sync sequence and automatically requests missing entries via backfill.

## Problem

Sometimes sync messages go missing (network issues, corruption, etc.). Currently there's no mechanism to detect or recover from these gaps. The user experienced an entry that never synced even after catch-up ran.

## Solution

A sequence log table tracks (host_id, counter, entry_id) pairs. When a message arrives with counter N but last seen was N-2, the system detects counter N-1 is missing. Periodically, missing entries are requested via broadcast. Any device with the entry can respond.

## Design Decisions

- **Backfill timing**: Batched periodic (every 5 minutes)
- **Gap age limit**: No limit - track all gaps
- **Stale handling**: Responder returns "deleted" status if entry was purged
- **Log pruning**: No pruning - keep all records indefinitely

---

## Implementation Phases

### Phase 1: Database Foundation

**File: `/lib/database/sync_db.dart`**

1. Add `SyncSequenceStatus` enum:
```dart
enum SyncSequenceStatus {
  received,   // Entry received and processed
  missing,    // Gap detected - not yet received
  requested,  // Backfill request sent
  backfilled, // Received via backfill
  deleted,    // Responder confirmed entry was purged
}
```

2. Add `SyncSequenceLog` table:
```dart
@DataClassName('SyncSequenceLogItem')
class SyncSequenceLog extends Table {
  TextColumn get hostId => text().named('host_id')();
  IntColumn get counter => integer()();
  TextColumn get entryId => text().named('entry_id').nullable()();
  IntColumn get status => integer().withDefault(Constant(SyncSequenceStatus.received.index))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  IntColumn get requestCount => integer().named('request_count').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {hostId, counter};
}
```

3. Update `@DriftDatabase` annotation to include new table

4. Bump schema version to 2, add migration:
```dart
@override
int get schemaVersion => 2;

// In migration onUpgrade:
if (from < 2) {
  await m.createTable(syncSequenceLog);
}
```

5. Add query methods:
- `recordSequenceEntry(SyncSequenceLogCompanion entry)`
- `getLastCounterForHost(String hostId) -> int?`
- `getMissingEntries({int limit, int maxRequestCount}) -> List<SyncSequenceLogItem>`
- `updateSequenceStatus(String hostId, int counter, SyncSequenceStatus status)`
- `incrementRequestCount(String hostId, int counter)`
- `getEntryByHostAndCounter(String hostId, int counter) -> SyncSequenceLogItem?`
- `watchMissingCount() -> Stream<int>`

---

### Phase 2: Message Types

**File: `/lib/features/sync/model/sync_message.dart`**

Add two new factory constructors:

```dart
const factory SyncMessage.backfillRequest({
  required String hostId,
  required int counter,
  required String requesterId,
}) = SyncBackfillRequest;

const factory SyncMessage.backfillResponse({
  required String hostId,
  required int counter,
  required bool deleted,
  String? entryId,
}) = SyncBackfillResponse;
```

Run `fvm flutter pub run build_runner build` to regenerate freezed files.

---

### Phase 3: Sequence Log Service

**New file: `/lib/features/sync/sequence/sync_sequence_log_service.dart`**

```dart
class SyncSequenceLogService {
  SyncSequenceLogService({
    required SyncDatabase syncDatabase,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
  });

  /// Record a sent entry (called from OutboxService)
  Future<void> recordSentEntry({
    required String entryId,
    required VectorClock vectorClock,
  });

  /// Record received entry and detect gaps
  /// Returns list of detected gaps
  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
  });

  /// Get missing entries for backfill (respects maxRequestCount)
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
  });

  /// Mark entries as requested (increment request_count)
  Future<void> markAsRequested(List<({String hostId, int counter})> entries);

  /// Handle backfill response (deleted or entry_id)
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    String? entryId,
  });

  /// Update status when entry received via normal sync
  Future<void> markAsReceived(String hostId, int counter, String entryId);
}
```

**Gap detection algorithm:**
```dart
Future<List<({String hostId, int counter})>> recordReceivedEntry(...) {
  final gaps = <({String hostId, int counter})>[];
  final myHost = await _vectorClockService.getHost();

  for (final entry in vectorClock.vclock.entries) {
    final hostId = entry.key;
    final counter = entry.value;

    // Skip entries from our own host
    if (hostId == myHost) continue;

    final lastSeen = await _db.getLastCounterForHost(hostId);

    if (lastSeen != null && counter > lastSeen + 1) {
      // Gap detected! Mark missing counters
      for (var i = lastSeen + 1; i < counter; i++) {
        gaps.add((hostId: hostId, counter: i));
        await _db.recordSequenceEntry(SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(i),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }

    // Record the received entry
    await _db.recordSequenceEntry(SyncSequenceLogCompanion(
      hostId: Value(hostId),
      counter: Value(counter),
      entryId: Value(entryId),
      status: Value(SyncSequenceStatus.received.index),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  return gaps;
}
```

---

### Phase 4: Backfill Request Service

**New file: `/lib/features/sync/backfill/backfill_request_service.dart`**

```dart
class BackfillRequestService {
  BackfillRequestService({
    required SyncSequenceLogService sequenceLogService,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
    this.requestInterval = const Duration(minutes: 5),
    this.maxBatchSize = 20,
    this.maxRequestCount = 10,
  });

  Timer? _timer;
  bool _isProcessing = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(requestInterval, (_) => _processBackfillRequests());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> processNow() => _processBackfillRequests();

  Future<void> _processBackfillRequests() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final missing = await _sequenceLogService.getMissingEntries(
        limit: maxBatchSize,
        maxRequestCount: maxRequestCount,
      );

      if (missing.isEmpty) return;

      final requesterId = await _vectorClockService.getHost();

      for (final item in missing) {
        await _outboxService.enqueueMessage(
          SyncMessage.backfillRequest(
            hostId: item.hostId,
            counter: item.counter,
            requesterId: requesterId,
          ),
        );
      }

      await _sequenceLogService.markAsRequested(
        missing.map((m) => (hostId: m.hostId, counter: m.counter)).toList(),
      );

      _loggingService.captureEvent(
        'Sent ${missing.length} backfill requests',
        domain: 'SYNC_BACKFILL',
      );
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
```

---

### Phase 5: Backfill Response Handler

**New file: `/lib/features/sync/backfill/backfill_response_handler.dart`**

```dart
class BackfillResponseHandler {
  BackfillResponseHandler({
    required JournalDb journalDb,
    required SyncDatabase syncDatabase,
    required OutboxService outboxService,
    required SyncSequenceLogService sequenceLogService,
    required LoggingService loggingService,
  });

  /// Handle incoming backfill request - look up entry and respond
  Future<void> handleBackfillRequest(SyncBackfillRequest request) async {
    // Look up in our sequence log
    final logEntry = await _syncDatabase.getEntryByHostAndCounter(
      request.hostId,
      request.counter,
    );

    if (logEntry == null || logEntry.entryId == null) {
      // We don't have this entry in our log - ignore
      return;
    }

    // Check if entry exists in journal
    final journalEntry = await _journalDb.journalEntityById(logEntry.entryId!);

    if (journalEntry == null) {
      // Entry was deleted/purged - respond with deleted status
      await _outboxService.enqueueMessage(
        SyncMessage.backfillResponse(
          hostId: request.hostId,
          counter: request.counter,
          deleted: true,
        ),
      );
      return;
    }

    // Entry exists - re-send it via normal sync
    // No confirmation response needed - the sequence log is updated when
    // the entry arrives via recordReceivedEntry()
    await _outboxService.enqueueMessage(
      SyncMessage.journalEntity(
        id: journalEntry.meta.id,
        jsonPath: getRelativeJsonPath(journalEntry.meta.id),
        vectorClock: journalEntry.meta.vectorClock,
        status: SyncEntryStatus.update,
      ),
    );
  }

  /// Handle incoming backfill response
  Future<void> handleBackfillResponse(SyncBackfillResponse response) async {
    await _sequenceLogService.handleBackfillResponse(
      hostId: response.hostId,
      counter: response.counter,
      deleted: response.deleted,
      entryId: response.entryId,
    );
  }
}
```

---

### Phase 6: Integration

**File: `/lib/features/sync/matrix/sync_event_processor.dart`**

Add handling for new message types in the message switch:

```dart
case SyncBackfillRequest():
  await _backfillResponseHandler.handleBackfillRequest(syncMessage);
  return null;

case SyncBackfillResponse():
  await _backfillResponseHandler.handleBackfillResponse(syncMessage);
  return null;
```

Modify `SyncJournalEntity` handling to record received entries:

```dart
case SyncJournalEntity(...):
  // ... existing processing ...

  // After successful apply, record in sequence log
  if (updateResult.applied && syncMessage.vectorClock != null) {
    final gaps = await _sequenceLogService.recordReceivedEntry(
      entryId: journalEntity.meta.id,
      vectorClock: syncMessage.vectorClock!,
    );
    if (gaps.isNotEmpty) {
      _loggingService.captureEvent(
        'Detected ${gaps.length} gaps in sync sequence',
        domain: 'SYNC_SEQUENCE',
      );
    }
  }
```

**File: `/lib/features/sync/outbox/outbox_service.dart`**

Record sent entries in sequence log:

```dart
// After successful enqueue of SyncJournalEntity:
if (messageToEnqueue is SyncJournalEntity) {
  final journalEntity = /* load from jsonPath */;
  if (journalEntity.meta.vectorClock != null) {
    await _sequenceLogService.recordSentEntry(
      entryId: journalEntity.meta.id,
      vectorClock: journalEntity.meta.vectorClock!,
    );
  }
}
```

**File: `/lib/features/sync/tuning.dart`**

Add backfill constants:

```dart
// Backfill tuning
static const Duration backfillRequestInterval = Duration(minutes: 5);
static const int backfillBatchSize = 20;
static const int backfillMaxRequestCount = 10;
```

---

### Phase 7: Dependency Injection

**File: `/lib/get_it.dart`** (or equivalent DI setup)

Register new services:
- `SyncSequenceLogService`
- `BackfillRequestService`
- `BackfillResponseHandler`

Wire up `BackfillRequestService.start()` when sync is initialized.

---

## Testing Strategy

### Unit Tests

1. **`test/features/sync/sequence/sync_sequence_log_service_test.dart`**
   - Gap detection: counter 5 when last was 2 → marks 3, 4 missing
   - No gap: sequential counters
   - Multiple hosts tracked independently
   - Status transitions

2. **`test/features/sync/backfill/backfill_request_service_test.dart`**
   - Timer fires at correct interval (fakeAsync)
   - Batching respects maxBatchSize
   - maxRequestCount prevents infinite retries

3. **`test/features/sync/backfill/backfill_response_handler_test.dart`**
   - Request handler finds and sends entry
   - Request handler sends deleted status when entry purged
   - Response handler updates sequence log status

4. **`test/database/sync_db_migration_test.dart`**
   - Migration from v1 to v2 creates table
   - Fresh install creates all tables

### Integration Tests

1. **Full backfill flow**:
   - Device A sends entries 1, 2, 4 (skip 3)
   - Device B detects gap
   - Device B requests backfill for 3
   - Device A responds
   - Device B receives and applies entry 3

---

## Edge Cases

1. **Self-origin entries**: Skip gap detection for entries from own host
2. **Race conditions**: Entry arrives via normal sync while backfill pending → update status
3. **New device**: Large gaps expected initially → not an error condition
4. **Deleted entries**: Responder returns `deleted: true` → requester stops retrying
5. **Entry not in responder's log**: Responder ignores request (another device may have it)

---

## Files to Modify/Create

| Action | File |
|--------|------|
| Modify | `/lib/database/sync_db.dart` |
| Modify | `/lib/features/sync/model/sync_message.dart` |
| Modify | `/lib/features/sync/tuning.dart` |
| Modify | `/lib/features/sync/matrix/sync_event_processor.dart` |
| Modify | `/lib/features/sync/outbox/outbox_service.dart` |
| Create | `/lib/features/sync/sequence/sync_sequence_log_service.dart` |
| Create | `/lib/features/sync/backfill/backfill_request_service.dart` |
| Create | `/lib/features/sync/backfill/backfill_response_handler.dart` |
| Create | `/test/features/sync/sequence/sync_sequence_log_service_test.dart` |
| Create | `/test/features/sync/backfill/backfill_request_service_test.dart` |
| Create | `/test/features/sync/backfill/backfill_response_handler_test.dart` |
