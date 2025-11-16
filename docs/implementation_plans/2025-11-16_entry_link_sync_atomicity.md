# Entry Link Sync Atomicity Fix – 2025-11-16

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

- [ ] Unit test: SyncEventProcessor with embedded links
- [ ] Unit test: SyncEventProcessor with nil/empty links
- [ ] Unit test: Entry failure doesn't process links
- [ ] Unit test: Standalone SyncEntryLink still works
- [ ] Integration test: End-to-end sync with embedded links
- [ ] Integration test: Mixed client versions
- [ ] Integration test: Multiple links per entry
- [ ] Widget test: Calendar shows correct colors with synced links
- [ ] Manual test: Desktop → Mobile sync
- [ ] Manual test: Mobile → Desktop sync
- [ ] Manual test: Offline → online sync
- [ ] Log analysis: No grey entries in calendar
- [ ] Log analysis: No orphaned entry links

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
