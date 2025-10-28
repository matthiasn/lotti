# Catch-Up Missing Events After Offline Period

## Summary

Two related P0 bugs cause sync failures when devices go offline and return online:

1. **No catch-up trigger**: When device goes offline during app session and returns online, no
   catch-up runs (only live scan processes ~10 newest events)
2. **Incomplete backlog**: When catch-up does run, it stops escalating once marker + pre-context
   found, potentially missing thousands of events after the marker

Both result in gray boxes (missing EntryLinks) in the UI.

## Related Docs

- 2025-10-27 — Matrix Live Events → Signal-Only Rescan/Catch‑Up: [2025-10-27_matrix_live_events_signal_driven_catchup.md](2025-10-27_matrix_live_events_signal_driven_catchup.md)
- 2025-10-23 — Sync Catch-Up Reliability — Journal Update Contract Fix: [2025-10-23_sync_marker_contract_fix.md](2025-10-23_sync_marker_contract_fix.md)

## Goals

- Always trigger a catch-up on stream signals and connectivity regain.
- Retrieve the full backlog after the marker; escalate until the snapshot is not full.
- Preserve existing pre-context semantics (count/since-ts) with no regressions.
- Prevent overlapping catch-ups with a lightweight in-flight guard.
- Keep performance characteristics for recent markers (fast/cheap catch-ups).
- Keep marker advancement tied to ordered batches from scans/catch-up, not direct stream events.

## Non-Goals

- No changes to attachment ingestion, descriptor catch-up manager, or vector-clock semantics.
- No database contract changes (covered by 2025-10-23 contract fix plan).
- No UI/UX changes beyond eliminating gray boxes; metrics additions are optional.
- No adjustments to configured `maxLookback`; escalation respects existing safety bounds.

## Problem 1: No Catch-Up Trigger (P0)

### Timeline of Events (from mobile2 log - 2025-10-28)

1. **13:48:50** - Mobile2 set marker to `$r9OAKi7ON...` and went offline/background
2. **13:52:17** - Desktop sent EntryLink linking planning entry to task
3. **13:55:58** - Mobile2 came back online, received stream events
4. **13:55:59** - Mobile2 jumped marker directly to `$sb6A4ve...`, **skipping the EntryLink entirely
   **

### Root Cause

In `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:512-521`:

```dart
if (!_initialCatchUpCompleted && !_firstStreamEventCatchUpTriggered) {
  _firstStreamEventCatchUpTriggered = true;
  unawaited(forceRescan());
}
```

**The bug**: `_initialCatchUpCompleted` is set to `true` after first catch-up and **never resets**.
When device comes back online during same session, the guard fails and only live scan runs.

### Solution: Always Catch-Up on Signal

**Key insight**: When marker is recent (1 min old), catch-up is cheap:

- Marker found in small snapshot (200 events)
- Returns only events after marker (5-10 events)
- Cost same as live scan

**Implementation**: Every signal triggers catch-up.

```dart
bool _catchUpInFlight = false;

_sub = _sessionManager.timelineEvents.listen((event) {
  final roomId = _roomManager.currentRoomId;
  if (roomId == null || event.roomId != roomId) return;

  if (_collectMetrics) _metrics.incSignalClientStream();
  _loggingService.captureEvent('signal.clientStream', domain: syncLoggingDomain, subDomain: 'signal');

  if (_catchUpInFlight) {
    _loggingService.captureEvent('signal.catchup.skipped inFlight=true', domain: syncLoggingDomain, subDomain: 'signal');
    return;
  }

  _catchUpInFlight = true;
  unawaited(
    forceRescan(includeCatchUp: true).whenComplete(() {
      _catchUpInFlight = false;
    }),
  );
});
```

**Changes**:

- Delete `_initialCatchUpCompleted` and `_firstStreamEventCatchUpTriggered` fields
- Delete conditional logic
- Add `_catchUpInFlight` guard to prevent overlapping catch-ups
- Every signal = catch-up

## Problem 2: Incomplete Backlog (P0)

### Timeline of Events (from mobile log - 2025-10-28)

1. **10:39:10** - Mobile last marker: `$UYfuxIY...`
2. **10:39-13:36** - Device offline/background, desktop creates ~3000 events
3. **13:36:51** - Catch-up runs: `catchup.done events=301`
4. **Result**: Only 301 events caught up (300 pre-context + 1 marker), missing ~2700 events

### Root Cause

In `lib/features/sync/matrix/pipeline/catch_up_strategy.dart:57-88`, `needsMore()`:

```dart
bool needsMore() {
  if (idx < 0 && !attempted) return true;
  if (idx < 0) return false;
  final availablePre = idx + 1;
  final needCount = preContextCount > 0 && availablePre < preContextCount;
  final needSinceTs = preContextSinceTs != null &&
      (events.isEmpty || TimelineEventOrdering.timestamp(events.first) > preContextSinceTs);
  return needCount || needSinceTs;  // BUG: Only checks PRE-context!
}
```

**The bug**: Once marker found and pre-context satisfied, stops escalating. If snapshot has 400
events but timeline has 5000, returns only 400 events, missing 4600.

### Solution: Continue Until Timeline End

**Simple fix**: Keep escalating until snapshot is not full (reached timeline end).

```dart
bool needsMore() {
  if (idx < 0 && !attempted) return true;
  if (idx < 0) return false;

  // Check pre-context requirements
  final availablePre = idx + 1;
  final needCount = preContextCount > 0 && availablePre < preContextCount;
  final needSinceTs = preContextSinceTs != null &&
      (events.isEmpty || TimelineEventOrdering.timestamp(events.first) > preContextSinceTs);

  if (needCount || needSinceTs) return true;  // Need more pre-context

  // NEW: Check if snapshot is full (might have more events after marker)
  final reachedStart = events.length < limit;
  if (!reachedStart) return true;  // Snapshot full, keep escalating

  return false;  // Snapshot not full, reached timeline end
}
```

**Why this works**:

- Escalates until marker found + pre-context satisfied (existing behavior)
- **NEW**: Continues escalating until `events.length < limit` (reached timeline start/end)
- When snapshot has fewer events than requested limit, we've reached the boundary

## Implementation Steps

### Step 1: Fix Catch-Up Trigger

1. Open `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
2. Delete fields:
  - `bool _initialCatchUpCompleted = false;`
  - `bool _firstStreamEventCatchUpTriggered = false;`
3. Delete `_initialCatchUpRetryTimer` logic
4. Add field: `bool _catchUpInFlight = false;`
5. Replace stream listener (lines 509-532) with always-catchup implementation above

### Step 2: Fix Incomplete Backlog

1. Open `lib/features/sync/matrix/pipeline/catch_up_strategy.dart`
2. Update `needsMore()` function (lines 57-67) with new logic above

### Step 3: Testing

- **Unit test**: Signal while catch-up running → skipped, no overlap
- **Unit test**: Recent marker → catch-up returns few events quickly
- **Unit test**: Stale marker (1 hour) → catch-up escalates fully
- **Unit test**: 5000-event backlog → catch-up escalates to maxLookback, returns all events
- **Integration test**: Background app 5+ mins, foreground → catch-up runs, EntryLink received
- **Integration test**: Offline 3 hours with 3000 events created → catch-up retrieves all

### Step 4: Verification

1. Run analyzer: `mcp__dart-mcp-local__analyze_files`
2. Run formatter: `mcp__dart-mcp-local__dart_format`
3. Run tests: `mcp__dart-mcp-local__run_tests` for affected files

## Acceptance Criteria

### Catch-Up Trigger

- [ ] Every stream signal triggers catch-up (no conditional logic)
- [ ] `_catchUpInFlight` prevents overlapping catch-ups
- [ ] Recent marker (< 5 min): fast catch-up
- [ ] Stale marker (> 1 hour): full catch-up
- [ ] EntryLink sent during offline period received after coming back online

### Incomplete Backlog

- [ ] Catch-up escalates until `events.length < limit` (timeline boundary reached)
- [ ] Large backlog (5000 events) fully retrieved within maxLookback
- [ ] Pre-context behavior unchanged
- [ ] No infinite loops

### Both

- [ ] Gray boxes (broken EntryLinks) no longer appear after offline periods
- [ ] All tests pass
- [ ] Analyzer zero warnings
- [ ] Formatted

## Impact

**Performance**: Minimal. Always-catchup adds overhead only when marker is stale (offline period),
which is when we need it. Recent markers (normal case) remain fast.

**Risk**: Low. Changes are localized to catch-up logic. Worst case: more frequent catch-ups than
necessary, but deduplication prevents reprocessing.

## Rollout Plan

- Land code changes behind the `_catchUpInFlight` guard (no feature flag required).
- Unit tests: add targeted coverage for signal-triggered catch-up and backlog completion.
- Targeted manual QA on desktop and mobile:
  - Offline window (minutes) → foreground → verify EntryLink backfills before marker advances.
  - Large backlog (thousands) → verify escalation until snapshot not full.
- Monitoring/observability:
  - Enable optional signal counters (client stream/connectivity/timeline callbacks) if available.
  - Watch logs for repeated escalation and final `events.length < limit` boundary.
- Rollback: single-commit revert restores prior behavior if unexpected regressions appear.

## Priority

**P0** (Critical): Fixes data loss / broken links visible to users

- **Target**: Implement and ship today
- **Risk if delayed**: Users continue experiencing broken links after offline periods
