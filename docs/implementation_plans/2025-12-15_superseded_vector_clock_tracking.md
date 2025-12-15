# Implementation Plan: Superseded Vector Clock Tracking

## Problem Statement

When an entry is updated multiple times rapidly, the outbox creates multiple items that all end up sending the **same final state** (because the JSON file is overwritten). This causes:

1. **False gap detection**: Receivers see VC `{A:7}` but expect counters 5, 6, 7 - they mark 5 and 6 as "missing"
2. **Unnecessary backfill requests**: Receivers request counters 5 and 6, which will return the same entry
3. **Wasted bandwidth**: Multiple outbox items send identical data

## Solution Overview

Track which vector clocks are "covered" by an outbox item, so receivers know which counters are superseded and don't need separate backfill requests.

---

## Phase 1: Sync Message Model Changes

### File: `lib/features/sync/model/sync_message.dart`

Add `coveredVectorClocks` field to `SyncJournalEntity` and `SyncEntryLink`:

```dart
const factory SyncMessage.journalEntity({
  required String id,
  required String jsonPath,
  required VectorClock? vectorClock,
  List<VectorClock>? coveredVectorClocks,  // NEW
  required SyncEntryStatus status,
  List<EntryLink>? entryLinks,
  String? originatingHostId,
}) = SyncJournalEntity;

const factory SyncMessage.entryLink({
  required EntryLink entryLink,
  required SyncEntryStatus status,
  String? originatingHostId,
  List<VectorClock>? coveredVectorClocks,  // NEW
}) = SyncEntryLink;
```

### Regenerate Code
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Phase 2: Outbox Database Infrastructure

### File: `lib/database/sync_db.dart`

#### 2a. Add `entryId` column to Outbox table schema:

```dart
@DataClassName('OutboxItem')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  IntColumn get status => integer().withDefault(Constant(OutboxStatus.pending.index))();
  IntColumn get retries => integer().withDefault(const Constant(0))();
  TextColumn get message => text()();
  TextColumn get subject => text()();
  TextColumn get filePath => text().named('file_path').nullable()();
  TextColumn get entryId => text().named('entry_id').nullable()();  // NEW
}
```

#### 2b. Increment schema version and add migration:

```dart
@override
int get schemaVersion => 4;  // Increment from current version

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 4) {
      // Add entryId column for outbox deduplication
      await m.addColumn(outbox, outbox.entryId);
    }
  },
);
```

#### 2c. Add query and update methods:

```dart
/// Find a pending outbox item for a specific entry ID.
/// Returns the most recent pending item for this entry, or null.
Future<OutboxItem?> findPendingByEntryId(String entryId) async {
  return (select(outbox)
        ..where((t) => t.status.equals(OutboxStatus.pending.index))
        ..where((t) => t.entryId.equals(entryId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(1))
      .getSingleOrNull();
}

/// Update an existing outbox item's message and subject.
Future<int> updateOutboxMessage({
  required int itemId,
  required String newMessage,
  required String newSubject,
}) {
  return (update(outbox)..where((t) => t.id.equals(itemId)))
      .write(OutboxCompanion(
        message: Value(newMessage),
        subject: Value(newSubject),
        updatedAt: Value(DateTime.now()),
      ));
}
```

### Regenerate Drift code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Phase 3: Outbox Service - Merge Superseded Entries

### File: `lib/features/sync/outbox/outbox_service.dart`

Modify `enqueueMessage()` for `SyncJournalEntity` to check for existing pending items and set `entryId`:

```dart
if (messageToEnqueue is SyncJournalEntity) {
  final journalEntityMsg = messageToEnqueue;

  // Check for existing pending outbox item for this entry
  final existingItem = await _syncDatabase.findPendingByEntryId(
    journalEntityMsg.id,
  );

  if (existingItem != null) {
    // Merge: add old VC to coveredVectorClocks
    final oldMessage = SyncMessage.fromJson(
      json.decode(existingItem.message) as Map<String, dynamic>,
    ) as SyncJournalEntity;

    final coveredClocks = <VectorClock>[
      ...?oldMessage.coveredVectorClocks,
      if (oldMessage.vectorClock != null) oldMessage.vectorClock!,
    ];

    // Refresh JSON file and get new local counter
    final latest = await _journalDb.journalEntityById(journalEntityMsg.id);
    if (latest != null) {
      final canonicalPath = entityPath(latest, _documentsDirectory);
      await _saveJson(canonicalPath, jsonEncode(latest));
    }
    final journalEntity = await readEntityFromJson(fullPath);
    final localCounter = journalEntity.meta.vectorClock?.vclock[host];

    // Update with new message including covered clocks
    final mergedMessage = journalEntityMsg.copyWith(
      vectorClock: journalEntity.meta.vectorClock,
      coveredVectorClocks: coveredClocks.isEmpty ? null : coveredClocks,
    );

    await _syncDatabase.updateOutboxMessage(
      itemId: existingItem.id,
      newMessage: json.encode(mergedMessage.toJson()),
      newSubject: '$hostHash:$localCounter',
    );

    _loggingService.captureEvent(
      'enqueue MERGED type=SyncJournalEntity id=${journalEntityMsg.id} coveredClocks=${coveredClocks.length}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );

    // Still record in sequence log for the new counter
    if (_sequenceLogService != null && journalEntity.meta.vectorClock != null) {
      await _sequenceLogService!.recordSentEntry(
        entryId: journalEntity.meta.id,
        vectorClock: journalEntity.meta.vectorClock!,
      );
    }
    return; // Don't create new outbox item
  }

  // For new items, include entryId in the companion:
  await _syncDatabase.addOutboxItem(
    commonFields.copyWith(
      filePath: Value(...),
      subject: Value('$hostHash:$localCounter'),
      entryId: Value(journalEntityMsg.id),  // NEW: Set entryId for lookups
    ),
  );
  // ... rest of existing logic ...
}
```

Apply similar logic for `SyncEntryLink`.

---

## Phase 4: Receiver - Process Covered Vector Clocks

### File: `lib/features/sync/sequence/sync_sequence_log_service.dart`

Add parameter and processing to `recordReceivedEntry()`:

```dart
Future<List<({String hostId, int counter})>> recordReceivedEntry({
  required String entryId,
  required VectorClock vectorClock,
  required String originatingHostId,
  List<VectorClock>? coveredVectorClocks,  // NEW PARAMETER
  SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
}) async {
  // ... existing gap detection and recording logic ...

  // NEW: Process covered vector clocks
  if (coveredVectorClocks != null && coveredVectorClocks.isNotEmpty) {
    await _markCoveredCountersAsReceived(
      coveredVectorClocks: coveredVectorClocks,
      entryId: entryId,
      payloadType: payloadType,
    );
  }

  return gaps;
}

/// Mark counters from covered vector clocks as received.
/// These are counters that were "spent" on superseded versions of the entry.
Future<void> _markCoveredCountersAsReceived({
  required List<VectorClock> coveredVectorClocks,
  required String entryId,
  required SyncSequencePayloadType payloadType,
}) async {
  final myHost = await _vectorClockService.getHost();
  final now = DateTime.now();
  var markedCount = 0;

  for (final coveredClock in coveredVectorClocks) {
    for (final entry in coveredClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Skip our own host
      if (hostId == myHost) continue;

      // Check if this counter is marked as missing or requested
      final existing = await _syncDatabase.getEntryByHostAndCounter(hostId, counter);

      if (existing != null &&
          (existing.status == SyncSequenceStatus.missing.index ||
           existing.status == SyncSequenceStatus.requested.index)) {
        // Mark as received - it's covered by the entry we just received
        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(payloadType.index),
            status: Value(SyncSequenceStatus.received.index),
            updatedAt: Value(now),
          ),
        );
        markedCount++;
      }
    }
  }

  if (markedCount > 0) {
    _loggingService.captureEvent(
      'markCoveredCountersAsReceived: marked $markedCount counters as received for entry=$entryId',
      domain: 'SYNC_SEQUENCE',
      subDomain: 'coveredClocks',
    );
  }
}
```

### File: `lib/features/sync/matrix/sync_event_processor.dart`

Pass `coveredVectorClocks` to `recordReceivedEntry()`:

```dart
// Around line 672-676
final gaps = await _sequenceLogService!.recordReceivedEntry(
  entryId: journalEntity.meta.id,
  vectorClock: syncMessage.vectorClock!,
  originatingHostId: syncMessage.originatingHostId!,
  coveredVectorClocks: syncMessage.coveredVectorClocks,  // NEW
);
```

---

## Phase 5: Tests

### New Test File: `test/features/sync/outbox/outbox_merge_test.dart`

```dart
group('Outbox superseded entry merging', () {
  test('merges consecutive updates to same entry', () async {
    // Create entry, enqueue
    // Update entry, enqueue again
    // Verify: only 1 outbox item exists
    // Verify: coveredVectorClocks contains first VC
  });

  test('coveredVectorClocks accumulates across multiple updates', () async {
    // Create entry, enqueue (VC 5)
    // Update entry, enqueue (VC 6)
    // Update entry, enqueue (VC 7)
    // Verify: 1 outbox item with coveredVectorClocks = [VC5, VC6]
  });
});
```

### Update: `test/features/sync/sequence/sync_sequence_log_service_test.dart`

```dart
group('coveredVectorClocks processing', () {
  test('marks covered counters as received', () async {
    // Setup: create missing entries for counters 5, 6
    // Call recordReceivedEntry with coveredVectorClocks containing VC5, VC6
    // Verify: counters 5, 6 now have status=received
  });

  test('does not downgrade backfilled status', () async {
    // Setup: counter 5 already backfilled
    // Call with coveredVectorClocks containing VC5
    // Verify: counter 5 still has status=backfilled
  });
});
```

---

## File Change Summary

| File | Changes |
|------|---------|
| `lib/features/sync/model/sync_message.dart` | Add `coveredVectorClocks` field to SyncJournalEntity and SyncEntryLink |
| `lib/database/sync_db.dart` | Add `entryId` column, migration, `findPendingByEntryId()`, `updateOutboxMessage()` |
| `lib/features/sync/outbox/outbox_service.dart` | Merge logic in `enqueueMessage()`, set `entryId` on new items |
| `lib/features/sync/sequence/sync_sequence_log_service.dart` | Add `coveredVectorClocks` parameter, `_markCoveredCountersAsReceived()` |
| `lib/features/sync/matrix/sync_event_processor.dart` | Pass `coveredVectorClocks` to `recordReceivedEntry()` |
| `test/database/sync_db_migration_test.dart` | Add migration test for `entryId` column |
| `test/features/sync/outbox/outbox_merge_test.dart` | New test file for merge behavior |
| `test/features/sync/sequence/sync_sequence_log_service_test.dart` | Add covered clocks tests |

---

## Backward Compatibility

- **Old senders**: Won't include `coveredVectorClocks` - receivers handle as today (gaps detected, backfill requested)
- **Old receivers**: Will ignore unknown `coveredVectorClocks` field in JSON - works but less efficient
- **Mixed environments**: Graceful degradation - worst case is current behavior

---

## Implementation Order

1. Phase 1: Model changes + regenerate (foundation)
2. Phase 2: Database methods (infrastructure)
3. Phase 4: Receiver processing (can test with manual data)
4. Phase 3: Outbox merge logic (complete sender side)
5. Phase 5: Tests (verify everything works)

This order allows incremental testing - receiver can be tested before sender is complete.
