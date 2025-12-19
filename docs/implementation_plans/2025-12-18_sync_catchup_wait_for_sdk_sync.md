# Sync Catch-Up Fix: Wait for SDK Sync Completion

## Status: IMPLEMENTED ✅

## Problem Summary

When mobile device came online after 8 hours offline, catch-up only retrieved **3 new entries** from desktop instead of the expected ~250 entries. Root cause: catch-up runs before Matrix SDK completes `/sync` with server.

## Root Cause

In `matrix_sdk_gateway.dart:49-52`:
```dart
await _client.init(
  waitForFirstSync: false,  // <-- SDK starts before sync completes
  waitUntilLoadCompletedLoaded: false,
);
```

The catch-up strategy calls `room.getTimeline()` which returns events from the **local SDK cache**. When SDK hasn't synced yet, the cache is stale.

## Implementation (Completed)

### Key Features

1. **Sync wait before catch-up**: All catch-up paths wait for SDK sync to complete (up to 30s timeout)
2. **Follow-up listener for slow networks**: If timeout occurs, a one-time listener triggers another catch-up when sync eventually completes
3. **Test seam**: `skipSyncWait` parameter allows tests to bypass sync waiting

### Changes Made

#### 1. `lib/features/sync/tuning.dart`
Added configurable timeout:
```dart
// Sync wait timeout for catch-up.
// Time to wait for Matrix SDK to sync with server before running catch-up.
// Applies to all catch-up scenarios: initial startup, app resume, wake, reconnect.
static const Duration catchupSyncWaitTimeout = Duration(seconds: 30);
```

#### 2. `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`

Added `_waitForSyncCompletion()` helper method:
- Waits for `client.onSync` stream to emit (indicates sync complete)
- 30-second timeout allows for slow networks while preventing indefinite blocking
- If timeout occurs, sets up `_pendingSyncSubscription` to trigger follow-up catch-up

Added `_setupPendingSyncListener()` method:
- One-time listener that triggers `_runGuardedCatchUp()` when sync completes
- Handles slow networks gracefully - catch-up runs twice (once on timeout, once when sync finishes)

Modified `_attachCatchUp()`:
- Calls `_waitForSyncCompletion()` at the start of every catch-up
- Logs sync status for debugging

Added test seam:
- `skipSyncWait` constructor parameter (defaults to `false`)
- All test instantiations use `skipSyncWait: true`

#### 3. `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart`
- Added `skipSyncWait: true` to all 83 `MatrixStreamConsumer` instantiations

#### 4. `test/features/sync/matrix/pipeline/matrix_stream_consumer_signal_test.dart`
- Added `skipSyncWait: true` to all 16 `MatrixStreamConsumer` instantiations

## Catch-Up Paths Covered

All paths now wait for sync:
1. **Initial startup** - SDK never synced yet
2. **App resume** (`AppLifecycleRescanObserver`) - SDK synced before, needs fresh sync
3. **Wake from standby** (`_startWakeCatchUp()`) - SDK synced before, needs fresh sync
4. **Connectivity regain** (`MatrixService` connectivity handler) - SDK couldn't sync while offline

## Verification Scenarios

### 1. Initial Startup (Cold Start)
- Close app completely
- Create entries on desktop
- Start app on mobile
- Verify log shows `catchup.waitForSync synced=true`
- Verify ALL entries retrieved via catch-up (not backfill)

### 2. App Resume (Background/Foreground)
- Background the app on mobile
- Create entries on desktop (wait a few minutes)
- Resume app on mobile
- Verify log shows `catchup.waitForSync synced=true` after resume
- Verify new entries appear immediately

### 3. Wake from Standby
- Let device go to sleep with app in foreground
- Create entries on desktop
- Wake device
- Verify entries sync via catch-up

### 4. Network Reconnect
- Enable airplane mode on mobile
- Create entries on desktop
- Disable airplane mode
- Verify log shows `catchup.waitForSync synced=true` after reconnect
- Verify entries appear immediately

### 5. Slow Network (>30s sync)
- On slow network, sync takes longer than 30s
- Catch-up runs after 30s with stale cache (some data)
- When sync completes, `pendingSyncListener.triggered` log appears
- Another catch-up runs automatically to get remaining data

## Test Results

All 182 tests in `test/features/sync/matrix/pipeline/` pass:
- 91 tests in `matrix_stream_consumer_test.dart` (including 4 new SDK sync wait tests)
- 16 tests in `matrix_stream_consumer_signal_test.dart`
- Additional tests in other pipeline test files

### New Tests Added

Group: "SDK sync wait before catch-up"
1. **waits for sync completion before catch-up and logs synced=true** - Verifies sync completes within timeout
2. **times out and sets up pending listener on slow sync** - Verifies timeout logs and synced=false
3. **pending sync listener triggers follow-up catch-up after timeout** - Verifies follow-up mechanism
4. **dispose completes without error when pending sync subscription exists** - Verifies clean disposal

## Follow-Up Fix: Concurrent forceRescan Guard (2025-12-19)

### Problem Discovered

During testing, the sync wait worked correctly (`synced=true`), but catch-up still missed entries. Analysis of logs revealed:

```
00:35:14.344 - forceRescan.start (connectivity)
00:35:14.594 - forceRescan.start (startup)  <- concurrent!
00:35:23.986 - processOrdered: timeout waiting for previous batch
```

**Root cause**: `MatrixService` triggers `forceRescan()` from both connectivity and startup handlers simultaneously. Both ran `_attachCatchUp()` concurrently, causing:
1. Both retrieved 162 events from timeline
2. First catch-up acquired `_processingInFlight` lock in `_processOrdered()`
3. Second catch-up waited 5 seconds (100×50ms polling loop)
4. Processing 162 events took >5 seconds
5. Second catch-up threw `TimeoutException`, discarding its events

### Fix Applied

Added `_forceRescanInFlight` guard in `forceRescan()` to serialize concurrent calls:

```dart
bool _forceRescanInFlight = false;

Future<void> forceRescan({bool includeCatchUp = true}) async {
  if (_forceRescanInFlight) {
    _loggingService.captureEvent('forceRescan.skipped (already in flight)', ...);
    return;
  }
  _forceRescanInFlight = true;
  try {
    // ... catch-up and scan
  } finally {
    _forceRescanInFlight = false;
  }
}
```

This is separate from `_catchUpInFlight` (managed by `_startCatchupNow()`) to avoid conflicts with internal signal-driven catch-ups.

## Follow-Up Fix #2: Skip Catch-Up When _catchUpInFlight (2025-12-19)

### Problem Discovered

After the first fix, logs still showed concurrent catch-ups causing timeouts:

```
01:26:56.039626 - catchUpRetry: starting guarded catch-up (sets _catchUpInFlight = true)
01:26:56.422687 - synced=true (starts processing 86 events)
... (processing takes ~75 seconds) ...
01:28:07.371736 - forceRescan.start (connectivity) <- starts WHILE catchUpRetry still processing!
01:28:09.555600 - synced=true (TWO concurrent catch-ups!)
01:28:09.647914 - processOrdered: waiting for previous batch to complete
```

**Root cause**: `forceRescan()` was guarded by `_forceRescanInFlight` to prevent concurrent `forceRescan` calls, but it could still run concurrently with `_runGuardedCatchUp()` which uses a different flag (`_catchUpInFlight`).

### Fix Applied

Added `_catchUpInFlight` check in `forceRescan()` with a bypass parameter for internal callers:

```dart
Future<void> forceRescan({
  bool includeCatchUp = true,
  bool bypassCatchUpInFlightCheck = false,  // NEW
}) async {
  // ...
  if (includeCatchUp) {
    if (!bypassCatchUpInFlightCheck && _catchUpInFlight) {
      // Skip - another catch-up is in flight from _runGuardedCatchUp
      _loggingService.captureEvent('forceRescan.skippedCatchUp (catchUpInFlight)', ...);
    } else {
      await _attachCatchUp();
    }
  }
  await _scanLiveTimeline();  // Always runs
}
```

`_startCatchupNow()` passes `bypassCatchUpInFlightCheck: true` because it intentionally sets `_catchUpInFlight` before calling `forceRescan()`.

External callers (MatrixService connectivity/startup handlers) use the default `bypassCatchUpInFlightCheck: false`, so they respect the existing catch-up-in-flight status.

### Why the 5-Second Timeout Exists

The `_processOrdered()` method has a serialization loop:
```dart
while (_processingInFlight && waitCount < 100) {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  waitCount++;
}
```

This was designed as a safety net, not a primary concurrency mechanism. The real fix is preventing concurrent catch-ups from reaching this point.

## Rollback

If issues arise:
1. Remove sync wait call from `_attachCatchUp()`
2. Remove `_waitForSyncCompletion()` and `_setupPendingSyncListener()` methods
3. Remove `_skipSyncWait` field and constructor parameter
4. Remove `skipSyncWait: true` from all test instantiations
5. Remove `_forceRescanInFlight` guard from `forceRescan()`
6. Remove `bypassCatchUpInFlightCheck` parameter and `_catchUpInFlight` check from `forceRescan()`
7. Remove `bypassCatchUpInFlightCheck: true` from `_startCatchupNow()`'s call to `forceRescan()`

The existing behavior resumes (catch-up runs immediately without waiting for sync).
