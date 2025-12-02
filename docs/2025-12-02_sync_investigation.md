# Sync Investigation - Root Cause Analysis

**Date:** 2025-12-02
**Issue:** Entries not syncing between devices after sync refactor (Sept-Oct 2025)

## Executive Summary

The sync system underwent a major rewrite from September-October 2025. While the new architecture is more sophisticated (stream-first pipeline, typed metrics, retry with backoff), it introduced several reliability regressions that cause entries to be permanently skipped.

## Key Findings

### 1. Retry Cap with Marker Advancement (`treatAsHandled`)

**Location:** `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:340-354`

**Problem:** After `_maxRetriesPerEvent` (5 attempts), events are marked as `treatAsHandled = true`, which allows the read marker to advance past them - **permanently skipping** the event.

```dart
if (nextAttempts >= _maxRetriesPerEvent && !isMissingAttachment) {
  treatAsHandled = true;  // THIS IS THE PROBLEM
  _retryTracker.clear(id);
  // ... event is now permanently skipped
}
```

**Impact:** Any event that fails 5 times (network issues, attachment not ready, processing errors) is lost forever.

### 2. Lazy Attachment Fetching Breaks Ordering

**OLD CODE:** `saveAttachment()` immediately downloaded and saved attachments when the attachment event arrived.

**NEW CODE:** `AttachmentIngestor.process()` only records the descriptor in an in-memory `AttachmentIndex`. Actual download happens later in `SmartJournalEntityLoader._ensureMediaOnMissing()`.

**Problem:** If the sync payload event arrives before its attachment descriptor (due to Matrix event ordering), the entity processing fails because the attachment can't be found. After 5 retries, the entry is lost.

### 3. Fallback Tail Limit When Marker Not Found

**Location:** `lib/features/sync/matrix/pipeline/matrix_stream_helpers.dart:134-152`

**OLD CODE:** If marker not found, processed ALL events in timeline.
**NEW CODE:** If marker not found, falls back to only the last 30 events (`tailLimit = 30`).

```dart
final slice = idx >= 0
    ? events.sublist(idx + 1)
    : events.sublist((events.length - tailLimit).clamp(0, events.length));
```

**Impact:** If device was offline for a while and the marker event is no longer in Matrix's local timeline, all events between the lost marker and the last 30 are skipped.

### 4. In-Memory State Loss

**Problem:** `AttachmentIndex` and `RetryTracker` are in-memory only. If the app crashes or restarts mid-sync:
- Attachment descriptors that were indexed but not yet used are lost
- Retry state is lost, but marker might have already advanced

### 5. Catch-up Pagination Limits

**Location:** `lib/features/sync/matrix/pipeline/catch_up_strategy.dart`

**Problem:** `maxLookback = 4000` events. If more than 4000 events occurred since last sync, older events won't be caught up.

## Comparison: Old vs New

| Aspect | Old Code | New Code |
|--------|----------|----------|
| Attachment handling | Immediate download | Lazy (index only) |
| Retry on failure | No explicit retry cap | 5 retries then skip |
| Marker not found fallback | Process ALL events | Process last 30 only |
| State persistence | Minimal | In-memory only |
| Failure recovery | Retry on next sync cycle | Permanent skip after cap |

## Fixes Applied (2025-12-02)

### Fix 1: Remove `treatAsHandled` Marker Advancement ✅ DONE

Changed `matrix_stream_consumer.dart` to keep retrying indefinitely instead of marking events as handled after retry cap. Failed events now block marker advancement forever until they succeed.

### Fix 2: Increase Fallback Tail Limit ✅ DONE

Changed `_liveScanTailLimit` from 30 to 1000 in `matrix_stream_consumer.dart:219`.

## Deferred Improvements

### Priority 2: Restore Eager Attachment Download (DEFERRED)

Either:
- Download attachments immediately when recording in `AttachmentIndex`
- Or at minimum, ensure attachment processing happens before payload processing in the batch

### Priority 3: Persist Failed Event IDs (DEFERRED)

Store failed event IDs in the database (not just in-memory) so they can be retried after app restart:
```dart
// Suggested: Add failed_sync_events table
class FailedSyncEvent {
  final String eventId;
  final DateTime firstFailure;
  final int attempts;
  final String? lastError;
}
```

### Priority 4: Add "Missing Base" Detection (DEFERRED)

The code has `JournalUpdateSkipReason.missingBase` but it doesn't seem to block marker advancement properly for linked entries.

## Files Modified

1. `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
   - ✅ Removed `treatAsHandled = true` for retry cap (lines 342-355, 390-399)
   - ✅ Increased `_liveScanTailLimit` from 30 to 1000 (line 219)

## Files to Modify (Deferred)

2. `lib/features/sync/matrix/pipeline/attachment_ingestor.dart`
   - Add eager download capability

3. `lib/database/database.dart` (or new file)
   - Add persistence for failed sync events

4. `lib/features/sync/matrix/smart_journal_entity_loader.dart`
   - Improve handling when attachment not in index

## Testing Recommendations

1. **Test offline scenario:** Create entry on device A, wait for marker to advance, bring device B online after 50+ events - verify all entries sync
2. **Test attachment ordering:** Send attachment descriptor after payload - verify entity is eventually synced
3. **Test app restart mid-sync:** Kill app during sync, restart - verify no entries lost
4. **Test retry exhaustion:** Simulate persistent failure - verify entry is NOT permanently skipped

## Conclusion

The core issue is the introduction of `treatAsHandled = true` after retry exhaustion, combined with the lazy attachment fetching that creates ordering dependencies. The old code was simpler and more robust - it just processed everything it saw, downloading attachments eagerly, without complex marker-based skipping logic.
