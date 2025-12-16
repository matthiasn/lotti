# Sync Bug Fixes: Gray Calendar Entries & Excessive Backfill

## Overview

Two bugs causing calendar entries to appear gray and excessive backfill requests:

1. **Bug #1**: Embedded entry links dropped when journal entity update is skipped
2. **Bug #2**: Covered vector clocks not inserted when counters don't exist yet

---

## Bug #1: Embedded Entry Links Dropped

### Problem

**File**: `lib/features/sync/matrix/sync_event_processor.dart:627-629`

```dart
// Process embedded entry links AFTER successful journal entity persistence
if (updateResult.applied &&    // <-- BUG: Links only processed when entry applied!
    entryLinks != null &&
    entryLinks.isNotEmpty) {
```

When a journal entity already exists locally (same/newer version based on vector clock comparison), `applied=false` and embedded entry links are **silently dropped**.

### Impact

- Calendar entries show gray because the EntryLink to their Task doesn't exist locally
- The link exists on the sender but never gets established on the receiver
- Eventually resolved by backfill sending the link separately, but this causes:
  - Poor UX (gray entries until backfill completes)
  - Wasted bandwidth (backfill requests for data that was already sent)

### Root Cause Analysis

The condition was likely added to avoid processing links for entries that weren't applied. However, this is incorrect because:

1. EntryLinks have their own vector clock for conflict resolution
2. `upsertEntryLink()` handles duplicates and conflicts correctly
3. The link might be new even if the journal entity is not

### Fix

Remove `updateResult.applied &&` condition. EntryLinks should be processed regardless of whether the journal entity was applied.

**Before**:
```dart
if (updateResult.applied &&
    entryLinks != null &&
    entryLinks.isNotEmpty) {
```

**After**:
```dart
// Process embedded entry links regardless of journal entity application status.
// EntryLinks have their own vector clock for conflict resolution via upsertEntryLink().
// This ensures links are established even when the entity itself is skipped
// (e.g., local version is newer), preventing gray calendar entries.
if (entryLinks != null && entryLinks.isNotEmpty) {
```

---

## Bug #2: Covered Vector Clocks Not Inserted

### Problem

**File**: `lib/features/sync/sequence/sync_sequence_log_service.dart:329-331`

```dart
if (existing != null &&    // <-- BUG: Only updates existing records!
    (existing.status == SyncSequenceStatus.missing.index ||
        existing.status == SyncSequenceStatus.requested.index)) {
```

The `_markCoveredCountersAsReceived` method only marks covered counters as received if they **already exist** in the sequence log. But superseded counters often **don't exist** because they were never sent separately - they were superseded on the sender before the outbox item was processed.

### Impact

Scenario causing unnecessary backfill:
1. Device A creates entry with VC `{A:5}`
2. Device A updates entry to VC `{A:6}` before sending → coveredVectorClocks = `[{A:5}]`
3. Device A sends entry with VC `{A:6}` and coveredVectorClocks containing the superseded VC
4. Device B receives entry, records counter 6 as received
5. Device B tries to mark counter 5 from coveredVectorClocks
6. **Counter 5 doesn't exist in Device B's sequence log** → `existing == null` → condition fails
7. Later, gap detection runs and marks counter 5 as `missing`
8. Unnecessary backfill request sent for counter 5
9. Device A responds with the same entry (since VC `{A:6}` covers counter 5)

### Root Cause Analysis

The original implementation assumed covered counters would already exist in the sequence log (e.g., from a previous sync that detected them as missing). However, the common case is:

- Entry is created and updated rapidly on Device A
- The superseded version (counter 5) was never sent
- Device B has no knowledge of counter 5 until it sees counter 6
- Gap detection sees the jump from 4 to 6 and marks 5 as missing

### Fix

Insert records for covered counters even if they don't exist yet. This pre-emptively records them as `received` before gap detection can mark them as `missing`.

**Before**:
```dart
if (existing != null &&
    (existing.status == SyncSequenceStatus.missing.index ||
        existing.status == SyncSequenceStatus.requested.index)) {
  // Mark as received
  await _syncDatabase.recordSequenceEntry(...);
  markedCount++;
}
```

**After**:
```dart
// Insert or update record for covered counter
// - If doesn't exist: insert as received (pre-empt gap detection)
// - If exists with missing/requested: update to received
// - If exists with received/backfilled: skip (don't downgrade)
if (existing == null) {
  // Counter doesn't exist - insert as received to pre-empt gap detection
  await _syncDatabase.recordSequenceEntry(
    SyncSequenceLogCompanion(
      hostId: Value(hostId),
      counter: Value(counter),
      entryId: Value(entryId),
      payloadType: Value(payloadType.index),
      status: Value(SyncSequenceStatus.received.index),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );
  markedCount++;
} else if (existing.status == SyncSequenceStatus.missing.index ||
           existing.status == SyncSequenceStatus.requested.index) {
  // Existing record with missing/requested - update to received
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
// If already received/backfilled, skip - don't downgrade status
```

---

## File Change Summary

| File | Changes |
|------|---------|
| `lib/features/sync/matrix/sync_event_processor.dart` | Remove `updateResult.applied &&` from embedded link processing (line 627) |
| `lib/features/sync/sequence/sync_sequence_log_service.dart` | Fix `_markCoveredCountersAsReceived` to insert records for non-existent counters (lines 329-344) |

---

## Testing Strategy

### Bug #1 Tests

**Test case**: Embedded links processed when entity update is skipped

```dart
test('processes embedded links even when journal entity is skipped', () async {
  // 1. Create journal entity locally with VC {A:5}
  final entity = createTestEntity(vectorClock: VectorClock({'A': 5}));
  await journalDb.updateJournalEntity(entity);

  // 2. Receive same entity via sync with embedded link
  final link = EntryLink.basic(
    id: 'link-1',
    fromId: 'task-1',
    toId: entity.meta.id,
    // ...
  );

  final syncMessage = SyncMessage.journalEntity(
    id: entity.meta.id,
    jsonPath: '...',
    vectorClock: VectorClock({'A': 5}), // Same VC - will be skipped
    status: SyncEntryStatus.update,
    entryLinks: [link],
    originatingHostId: 'A',
  );

  await processor.apply(event, syncMessage);

  // 3. Verify link was inserted even though entity was skipped
  final storedLink = await journalDb.entryLinkById('link-1');
  expect(storedLink, isNotNull);
});
```

### Bug #2 Tests

**Test case**: Covered counters inserted for non-existent records

```dart
test('inserts covered counters that do not exist in sequence log', () async {
  // 1. Receive entry with coveredVectorClocks containing counters not in log
  final coveredVCs = [VectorClock({'B': 5})];

  await sequenceLogService.recordReceivedEntry(
    entryId: 'entry-1',
    vectorClock: VectorClock({'B': 6}),
    originatingHostId: 'B',
    coveredVectorClocks: coveredVCs,
  );

  // 2. Verify counter 5 was inserted as received
  final entry5 = await syncDb.getEntryByHostAndCounter('B', 5);
  expect(entry5, isNotNull);
  expect(entry5!.status, SyncSequenceStatus.received.index);

  // 3. Verify counter 6 was also recorded
  final entry6 = await syncDb.getEntryByHostAndCounter('B', 6);
  expect(entry6, isNotNull);
  expect(entry6!.status, SyncSequenceStatus.received.index);
});

test('gap detection does not mark covered counters as missing', () async {
  // 1. Simulate receiving counter 4, then counter 6 with covered VC for 5
  await sequenceLogService.recordReceivedEntry(
    entryId: 'entry-4',
    vectorClock: VectorClock({'B': 4}),
    originatingHostId: 'B',
  );

  await sequenceLogService.recordReceivedEntry(
    entryId: 'entry-6',
    vectorClock: VectorClock({'B': 6}),
    originatingHostId: 'B',
    coveredVectorClocks: [VectorClock({'B': 5})],
  );

  // 2. Verify no entries are marked as missing
  final missing = await syncDb.getMissingEntries();
  expect(missing, isEmpty);
});
```

---

## Backward Compatibility

Both fixes are fully backward compatible:
- No protocol changes required
- No database schema changes required
- Only affects receiver-side processing logic
- Old clients sending messages without coveredVectorClocks continue to work (worst case: current behavior)

---

## Related Files

- `lib/features/sync/README.md` - Sync architecture documentation
- `lib/features/sync/outbox/outbox_service.dart` - Outbox merge logic that populates coveredVectorClocks
- `lib/database/sync_db.dart` - SyncSequenceStatus enum and database operations
- `test/features/sync/matrix/sync_event_processor_test.dart` - Existing processor tests
- `test/features/sync/sequence/sync_sequence_log_service_test.dart` - Existing sequence log tests
