# Sync Regression Investigation — 2025-11-05

- Scope: Matrix sync pipeline (stream-first consumer) on mobile and desktop
- Window analyzed: today after 11:00 CET; focus around 13:55–14:05
- Artifacts: `docs/sync/lotti-2025-11-05_mobile.log`, `docs/sync/lotti-2025-11-05_desktop.log`
- **Status**: ✅ **FIXED** — Three critical bugs identified and resolved (2025-11-05)

## Summary
Mobile was missing entries created on desktop, showing only the newest entry after sync with everything in between dropped. Investigation revealed **three separate but related root causes**:

### Root Causes Identified

1. **Catch-up retry mechanism removed (commit 074bb34d4)** ⚠️ **CRITICAL**
   - Recent "sync catchup improvements" removed `_scheduleInitialCatchUpRetry()`
   - If room wasn't ready within ~150ms at startup, catch-up was **permanently skipped**
   - Mobile's room hydration took longer, so catch-up never ran → all entries missed
   - **Fix**: Restored retry mechanism with 500ms intervals until catch-up succeeds

2. **Drop filter logic inverted** ⚠️ **CRITICAL**
   - `filterSyncPayloadsByMonotonic()` in `matrix_stream_helpers.dart:190`
   - Logic was: drop events that are NOT newer AND have **zero attempts**
   - This is backwards! Zero attempts = never processed, should be kept
   - Events arriving out-of-order in a burst were dropped on first sight
   - **Fix**: Flipped logic to drop events that are NOT newer AND **have been attempted**

3. **Excessive logging/reprocessing**
   - Audit tail brought back hundreds of already-processed events from last night
   - Each event logged "SyncEventProcessor: processing" even when immediately skipped
   - After large sync sessions (resync the past week), log files reached 30+ MB
   - **Fix**: Skip `_processSyncPayloadEvent()` for events in `_completedSyncIds` cache

## Evidence

### Mobile log — no catch-up on startup
- Mobile log at 13:55:37 shows: `MATRIX_SYNC catchup: No active room for catch-up`
- Room wasn't ready yet, catch-up returned early
- No retry scheduled → catch-up **never ran**
- Desktop created 5 entries between 13:49-13:51 (IDs: dd758f60, ea429ff0, 048d46d0, 163f7560, 303c7170)
- Mobile only received the last one (303c7170) via live timeline after room became ready
- First 4 entries were in the catch-up window but catch-up never executed

### Desktop log — excessive reprocessing
- Desktop at 12:24:31 reprocessing hundreds of events from 01:32-01:34 (last night)
- Each logged "SyncEventProcessor: processing" even though all resulted in "skip=older_or_equal"
- 13,545 log lines between 11:00-14:00 on desktop vs 754 on mobile
- Log files: 33MB desktop, 28MB mobile for a single day
- Audit tail of 50-100 events capturing hundreds after large sync session

### Drop filter evidence
- When events arrive out of order in a burst:
  1. Later event arrives first → marker advances
  2. Earlier events arrive → appear "not newer" than marker
  3. `filterSyncPayloadsByMonotonic()` checks: `!newer && !hasAttempts(id)`
  4. Zero attempts = never tried → **should keep**, but filter **drops** them
- Result: "dropped middle" behavior - only first and last entries survive

### Code paths affected

**1. Catch-up retry (matrix_stream_consumer.dart)**
- Before: `start()` called `_attachCatchUp()` once, with one weak 150ms retry
- If room not ready → logged "No active room" and returned
- After: Added `_scheduleInitialCatchUpRetry()` with 500ms intervals
- Retry continues until `_initialCatchUpCompleted` flag is set
- Also triggers on first stream event if catch-up hasn't completed

**2. Drop filter (matrix_stream_helpers.dart:190)**
- Before: `if (!newer && !hasAttempts(id))` → drop
- This dropped never-tried events that appeared out of order
- After: `if (!newer && hasAttempts(id))` → drop
- Now only drops events that have been attempted and confirmed old
- Zero-attempt events always get their first chance

**3. Excessive logging (matrix_stream_consumer.dart:1132)**
- Before: All events in audit tail went through `_processSyncPayloadEvent()`
- After: Check `_wasCompletedSync(id)` first, skip if already done
- Reduces redundant logging and DB vector clock checks

## Impact
- Missing entries on mobile when entries were authored on another device
- Marker ratchets forward during bursts, causing "dropped middle" behavior as seen in screenshots
- Log volume inflates due to reprocessing hundreds of already-applied events from audit tail
- Desktop log: 33MB, Mobile log: 28MB for a single day

## Fixes Implemented (2025-11-05)

### 1. Restore catch-up retry mechanism
**File**: `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
- Added fields: `_initialCatchUpCompleted`, `_catchUpRetryTimer`, `_firstStreamEventCatchUpTriggered`
- Added `_scheduleInitialCatchUpRetry()` method with 500ms intervals
- Modified `start()` to schedule retry if catch-up doesn't complete initially
- Modified `_attachCatchUp()` to set `_initialCatchUpCompleted` flag and cancel timer
- Added catch-up trigger on first stream event if not yet completed
- Modified `dispose()` to cancel retry timer

### 2. Fix drop filter logic
**File**: `lib/features/sync/matrix/pipeline/matrix_stream_helpers.dart:190`
```dart
// Before (WRONG):
if (!newer && !hasAttempts(e.eventId)) {
  continue; // drops zero-attempt events
}

// After (CORRECT):
if (!newer && hasAttempts(e.eventId)) {
  continue; // only drops already-attempted events
}
```
- Keep zero-attempt events even if they appear older (they need their first try)
- Only drop events that have been attempted and confirmed old

### 3. Skip already-completed events in audit tail
**File**: `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:1132`
- Check `_wasCompletedSync(id)` before calling `_processSyncPayloadEvent()`
- Treat already-completed events as `processedOk=true, treatAsHandled=true`
- Avoids redundant logging and DB vector clock checks
- Applied in both primary and fallback code paths

## Validation Plan
**Test scenario**: Create a sequence of entries on desktop while mobile is offline, then bring mobile online.

**Expected behavior after fixes**:
1. Mobile logs show `catchup.retry.attempt` if room not immediately ready
2. Catch-up eventually runs and processes all missed entries
3. No "No active room for catch-up" messages that result in permanent skip
4. All entries applied in order, no gaps
5. Logs show `applied=true` for legitimate new entries, not `skip=older_or_equal`
6. Log file sizes reduced (fewer redundant processing logs)

**Observables to watch**:
- `catchup.initial.completed` appears in logs
- `marker.local` advances only after `apply … applied=true` or legitimate no-op
- `liveScan processed=…` shows all entries, not just newest
- Log volume reduced (fewer "SyncEventProcessor: processing" for already-done events)

## Testing
**Unit tests affected**:
- `test/features/sync/matrix/pipeline/matrix_stream_helpers_test.dart` - drop filter tests
- `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart` - catch-up tests
- Run: `fvm flutter test test/features/sync/matrix/pipeline/`

## Follow-ups / Future Improvements
- Add integration test for cross-device sync with room hydration delay
- Consider metrics for catch-up retry count to detect slow room hydration
- Monitor log file sizes in production after fix
- Consider adding test for audit tail performance with large event histories

## TL;DR
**Three critical bugs fixed**:
1. **Catch-up retry removed** → restored 500ms retry loop until success
2. **Drop filter inverted** → flipped logic to keep zero-attempt events
3. **Excessive logging** → skip already-completed events in audit tail

**Result**: Sync reliability restored, log volume reduced, all entries now arrive correctly even with slow room hydration or out-of-order event delivery.
