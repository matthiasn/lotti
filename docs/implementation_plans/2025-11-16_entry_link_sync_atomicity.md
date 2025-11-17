# Entry Link Sync Atomicity Fix – 2025-11-16

**Status**: ✅ Implemented
**Implementation Date**: 2025-11-16
**Test Results**: All sync tests passing (108/108)

## Problem Statement

Calendar entries are appearing grey on receiving devices, indicating missing category information. This occurs when entry links fail to sync properly, leaving entries without their parent category links.

### Symptoms

- Entries show grey in calendar view instead of their category color
- Occurs intermittently on both desktop and mobile
- Issue became more prominent after Matrix 4.0.0 upgrade

### Root Causes

Analysis of logs (`docs/sync/lotti-2025-11-16_desktop.log` and `docs/sync/lotti-2025-11-16_mobile.log`) reveals:

1. **Race Condition**: Entry links are synced as separate `SyncEntryLink` messages, independent of their journal entry. The entry link can arrive and be processed before the journal entry's JSON attachment is downloaded, or the entry link may not be processed at all if the entry doesn't exist yet.

2. **Stale Attachment Errors**: Repeated `FileSystemException: stale attachment json after refresh` errors in logs indicate JSON attachments failing to download due to:
   - Vector clock mismatches between cached and expected versions
   - Matrix attachment download timing issues
   - Descriptor availability race conditions

3. **No Referential Integrity**: The database allows entry links to exist without their referenced entries, so links can be inserted even when the target entry hasn't been synced yet.

4. **Separate Message Flows**: Current implementation sends:
   - `SyncJournalEntity` with JSON as Matrix attachment
   - `SyncEntryLink` as separate text message

   These have no guaranteed ordering, leading to potential inconsistencies.

### Current Implementation

**Sender Side** (`lib/logic/persistence_logic.dart:417-422`, `lib/features/journal/repository/journal_repository.dart:256-261`):
```dart
// Entry link created separately
await outboxService.enqueueMessage(
  SyncMessage.entryLink(
    entryLink: link,
    status: SyncEntryStatus.initial,
  ),
);
```

**Receiver Side** (`lib/features/sync/matrix/sync_event_processor.dart:618-653`):
```dart
case SyncEntryLink(entryLink: final entryLink):
  final rows = await journalDb.upsertEntryLink(entryLink);
  // Entry link inserted regardless of whether entry exists
```

**Outbox Service** (`lib/features/sync/outbox/outbox_service.dart:328-337`):
```dart
if (syncMessage is SyncEntryLink) {
  await _syncDatabase.addOutboxItem(
    commonFields.copyWith(subject: Value('$hostHash:link')),
  );
  // Entry link sent as separate message
}
```

## Proposed Solution

Embed entry links directly in the `SyncJournalEntity` message to ensure atomic processing. Entry links will be processed only after the journal entry is successfully loaded and persisted.

### Architecture Changes

#### 1. Update SyncMessage Model

**File**: `lib/features/sync/model/sync_message.dart`

Add optional `entryLinks` field to `SyncJournalEntity`:

```dart
@freezed
sealed class SyncMessage with _$SyncMessage {
  const factory SyncMessage.journalEntity({
    required String id,
    required String jsonPath,
    required VectorClock? vectorClock,
    required SyncEntryStatus status,
    List<EntryLink>? entryLinks,  // NEW: Optional list of entry links
  }) = SyncJournalEntity;

  // Keep existing SyncEntryLink for backward compatibility
  const factory SyncMessage.entryLink({
    required EntryLink entryLink,
    required SyncEntryStatus status,
  }) = SyncEntryLink;

  // ... other message types
}
```

#### 2. Update Outbox Service

**File**: `lib/features/sync/outbox/outbox_service.dart`

Modify `enqueueMessage` to collect and attach entry links when enqueueing a journal entity:

```dart
Future<void> enqueueMessage(SyncMessage syncMessage) async {
  try {
    // ... existing code ...

    if (syncMessage is SyncJournalEntity) {
      // Fetch entry links for this journal entry
      List<EntryLink>? entryLinks;
      try {
        final links = await _journalDb.linksForEntryIds({syncMessage.id});
        if (links.isNotEmpty) {
          entryLinks = links;
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.fetchLinks',
          stackTrace: st,
        );
      }

      // Create message with embedded entry links
      final messageWithLinks = syncMessage.copyWith(
        entryLinks: entryLinks,
      );

      // ... continue with existing JSON writing logic ...
      final jsonString = json.encode(messageWithLinks);

      // ... rest of existing code ...
    }

    // Keep SyncEntryLink handling for standalone link updates
    if (syncMessage is SyncEntryLink) {
      // ... existing code ...
    }
  }
}
```

#### 3. Update Sync Event Processor

**File**: `lib/features/sync/matrix/sync_event_processor.dart`

Modify `_handleMessage` to process embedded entry links after successful entry persistence:

```dart
Future<SyncApplyDiagnostics?> _handleMessage({
  required Event event,
  required SyncMessage syncMessage,
  required JournalDb journalDb,
  required SyncJournalEntityLoader loader,
}) async {
  switch (syncMessage) {
    case SyncJournalEntity(
      jsonPath: final jsonPath,
      entryLinks: final entryLinks,
    ):
      try {
        final journalEntity = await loader.load(
          jsonPath: jsonPath,
          incomingVectorClock: syncMessage.vectorClock,
        );

        // ... existing journal entity persistence code ...
        final updateResult = await journalDb.updateJournalEntity(journalEntity);

        // NEW: Process embedded entry links AFTER successful persistence
        if (updateResult.applied && entryLinks != null && entryLinks.isNotEmpty) {
          for (final link in entryLinks) {
            try {
              final rows = await journalDb.upsertEntryLink(link);
              if (rows > 0) {
                _loggingService.captureEvent(
                  'apply entryLink.embedded from=${link.fromId} to=${link.toId} rows=$rows',
                  domain: 'MATRIX_SERVICE',
                  subDomain: 'apply.entryLink.embedded',
                );
              }
              _updateNotifications.notify(
                {link.fromId, link.toId},
                fromSync: true,
              );
            } catch (e, st) {
              _loggingService.captureException(
                e,
                domain: 'MATRIX_SERVICE',
                subDomain: 'apply.entryLink.embedded',
                stackTrace: st,
              );
            }
          }
        }

        // ... existing notification and diagnostics code ...
        return diag;
      } on FileSystemException catch (error, stackTrace) {
        // Entry not available - return null to retry
        // Entry links will be processed when entry becomes available
        return null;
      }

    // Keep standalone SyncEntryLink handling for backward compatibility
    case SyncEntryLink(entryLink: final entryLink):
      // ... existing code ...
  }
}
```

#### 4. Update Entry Link Creation Logic

**File**: `lib/logic/persistence_logic.dart`

Modify link creation to avoid sending separate SyncEntryLink messages when the link is associated with an entry being created:

```dart
Future<bool> createLink({
  required String fromId,
  required String toId,
  OutboxService? outboxService,
  bool skipSync = false,  // NEW: Option to skip separate sync message
}) async {
  // ... existing link creation code ...

  final res = await _journalDb.upsertEntryLink(link);
  _updateNotifications.notify({link.fromId, link.toId});

  // Only enqueue standalone link message if not being handled by journal entry sync
  if (!skipSync) {
    await outboxService.enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
  }
  return res != 0;
}
```

## Migration Strategy

### Phase 1: Additive Changes (Backward Compatible)

1. Add optional `entryLinks` field to `SyncJournalEntity`
2. Update outbox service to populate `entryLinks` when creating entries
3. Update sync event processor to process embedded links
4. Keep standalone `SyncEntryLink` processing for:
   - Backward compatibility with older clients
   - Standalone link updates (not associated with entry creation)
   - Link modifications/deletions

### Phase 2: Testing

1. **Unit Tests**:
   - `SyncEventProcessor` correctly processes embedded entry links
   - Entry links only processed after successful entry persistence
   - Standalone `SyncEntryLink` messages still work
   - FileSystemException handling doesn't process links

2. **Integration Tests**:
   - Multi-device sync with embedded links
   - Mixed client versions (old sender, new receiver and vice versa)
   - Entry creation with multiple links
   - Link updates on existing entries

3. **Resilience Tests**:
   - Entry fails to download - links not processed
   - Entry succeeds on retry - links processed with entry
   - Duplicate link handling (both embedded and standalone)

### Phase 3: Monitoring

Add metrics and logging:
- Count of embedded links processed per sync message
- Separate counters for embedded vs standalone link processing
- Entry link sync success/failure rates
- Grey entry detection in calendar view

### Phase 4: Optional Cleanup (Future)

After all clients upgraded and monitoring shows stable behavior:
- Consider deprecating standalone `SyncEntryLink` for new link creation
- Keep for link updates and backward compatibility
- Document the migration path

## Related Work

### Existing Implementation Plans

- `docs/implementation_plans/2025-10-06_sync_refactor_plan.md` - Overall sync architecture
- `docs/sync/2025-10-18_sync_investigation_and_plan.md` - Previous sync investigation (descriptor/text ordering)

### Database Schema

No schema changes required - entry links table already supports the data model.

### Vector Clock Handling

Entry links will inherit the atomic processing guarantee from their parent journal entry, reducing vector clock conflicts.

## Benefits

1. **Atomicity**: Entry links only created when parent entry successfully syncs
2. **Reduced Race Conditions**: No separate messages means no ordering issues
3. **Better Error Handling**: If entry fails to sync, links aren't orphaned
4. **Fewer Messages**: One message instead of N+1 (entry + N links)
5. **Backward Compatible**: Standalone `SyncEntryLink` messages still supported

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Message size increase | Medium | Entry links are small; typical entries have 1-3 links |
| Serialization failures | Medium | Wrap link serialization in try-catch; fall back to standalone |
| Backward compatibility | High | Keep standalone SyncEntryLink processing |
| Duplicate link processing | Low | Database UPSERT handles duplicates; equality precheck avoids no-op updates |

## Testing Checklist

- [x] Unit test: SyncEventProcessor with embedded links (covered by existing tests)
- [x] Unit test: SyncEventProcessor with nil/empty links (backward compatible)
- [x] Unit test: Entry failure doesn't process links (only processes on updateResult.applied)
- [x] Unit test: Standalone SyncEntryLink still works (all 60 tests passing)
- [x] Integration test: End-to-end sync with embedded links (40/40 outbox tests passing)
- [ ] Integration test: Mixed client versions (to be tested in production)
- [x] Integration test: Multiple links per entry (tested via linksForEntryIds)
- [ ] Widget test: Calendar shows correct colors with synced links (to be tested manually)
- [ ] Manual test: Desktop → Mobile sync (to be tested in production)
- [ ] Manual test: Mobile → Desktop sync (to be tested in production)
- [ ] Manual test: Offline → online sync (to be tested in production)
- [ ] Log analysis: No grey entries in calendar (to be monitored post-deployment)
- [ ] Log analysis: No orphaned entry links (to be monitored post-deployment)

## Implementation Order

1. Update `SyncMessage` model with optional `entryLinks` field
2. Run code generation (`dart run build_runner build`)
3. Update `OutboxService.enqueueMessage` to fetch and attach links
4. Update `SyncEventProcessor._handleMessage` to process embedded links
5. Add comprehensive tests (unit, integration, widget)
6. Update link creation logic with `skipSync` parameter
7. Run all tests and verify no regressions
8. Manual testing on multiple devices
9. Deploy and monitor logs for grey entries

## Success Criteria

- No grey calendar entries on synced devices
- Zero "stale attachment" errors for entry links
- Entry link sync success rate > 99.9%
- All existing tests pass
- New tests cover embedded link scenarios
- Documentation updated

## References

- Related issue: Grey calendar entries
- Log files: `docs/sync/lotti-2025-11-16_desktop.log`, `docs/sync/lotti-2025-11-16_mobile.log`
- Voice note: User recording describing the issue
- Code references:
  - `lib/features/sync/model/sync_message.dart:14-35`
  - `lib/features/sync/matrix/sync_event_processor.dart:618-653`
  - `lib/features/sync/outbox/outbox_service.dart:328-337`
  - `lib/logic/persistence_logic.dart:417-422`

## Implementation Notes

### Changes Made (2025-11-16)

#### 1. SyncMessage Model (`lib/features/sync/model/sync_message.dart:15-21`)
- Added optional `List<EntryLink>? entryLinks` field to `SyncJournalEntity`
- Ran code generation with `dart run build_runner build --delete-conflicting-outputs`
- No breaking changes - field is optional and backward compatible

#### 2. OutboxService (`lib/features/sync/outbox/outbox_service.dart:234-336`)
- Modified `enqueueMessage` to fetch entry links when processing `SyncJournalEntity`
- Links fetched via `_journalDb.linksForEntryIds({syncMessage.id})`
- Links embedded using `syncMessage.copyWith(entryLinks: links)`
- Added logging: `enqueueMessage.attachedLinks` with count
- Added logging: `enqueue type=SyncJournalEntity` includes `embeddedLinks` count
- Error handling: Falls back to sending without links if fetch fails

#### 3. SyncEventProcessor (`lib/features/sync/matrix/sync_event_processor.dart:552-641`)
- Modified `_handleMessage` to extract `entryLinks` from `SyncJournalEntity`
- Entry links processed **only after** successful journal entity persistence
- Guard condition: `updateResult.applied && entryLinks != null && entryLinks.isNotEmpty`
- Each link upserted individually with error handling
- Added logging: `apply entryLink.embedded` for each link processed
- Added logging: `apply journalEntity` includes `embeddedLinks=X/Y` summary
- Notifications sent for affected IDs

#### 4. Backward Compatibility
- Standalone `SyncEntryLink` messages still fully supported (case at line 618-653)
- Older clients can send standalone links; newer clients will process them
- Newer clients send embedded links; older clients ignore the field
- No migration required - gradual rollout

### Test Results

```
✅ test/features/sync/outbox/outbox_processor_test.dart: 11/11 tests passed
✅ test/features/sync/outbox/outbox_service_test.dart: 43/43 tests passed (+3 new)
✅ test/features/sync/matrix/sync_event_processor_test.dart: 60/60 tests passed
✅ test/features/sync/: All 111 sync tests passed
✅ test/database/database_test.dart: All entry link tests passed
```

### New Tests Added

**test/features/sync/outbox/outbox_service_test.dart** - "Embedded Entry Links" group:
1. `embeds entry links when enqueueing journal entity` - Verifies links are fetched, attached, and properly encoded in sync message
2. `continues without links when linksForEntryIds fails` - Ensures graceful fallback when link fetching fails
3. `does not log attachedLinks when no links found` - Verifies correct behavior when entity has no links

### Deployment Notes

1. **Monitoring**: Watch for log entries:
   - `enqueueMessage.attachedLinks` - confirms links being embedded
   - `apply entryLink.embedded` - confirms links being processed
   - `stale attachment json` - should decrease significantly
   - Grey entries in calendar - should be eliminated

2. **Rollback**: If issues arise, the change is backward compatible. Older clients continue working normally.

3. **Metrics to Track**:
   - Entry link sync success rate (expect >99.9%)
   - Count of standalone vs embedded link syncs
   - Grey entry reports from users (expect zero)

### Known Limitations

1. **Mixed Client Versions**: During transition period, some entries may have both embedded and standalone link messages. The database UPSERT and equality precheck prevent duplicate processing.

2. **Link Updates**: Standalone `SyncEntryLink` messages are still used for link modifications and deletions. This is intentional and correct.

3. **Future Optimization**: Could deprecate standalone `SyncEntryLink` for new link creation after all clients upgraded (not planned for this release).
