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

1. **Sync wait before catch-up**: All catch-up paths wait for SDK sync to complete (up to 10s timeout)
2. **Follow-up listener for slow networks**: If timeout occurs, a one-time listener triggers another catch-up when sync eventually completes
3. **Test seam**: `skipSyncWait` parameter allows tests to bypass sync waiting

### Changes Made

#### 1. `lib/features/sync/tuning.dart`
Added configurable timeout:
```dart
// Sync wait timeout for catch-up.
// Time to wait for Matrix SDK to sync with server before running catch-up.
// Applies to all catch-up scenarios: initial startup, app resume, wake, reconnect.
static const Duration catchupSyncWaitTimeout = Duration(seconds: 10);
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

## Rollback

If issues arise:
1. Remove sync wait call from `_attachCatchUp()`
2. Remove `_waitForSyncCompletion()` and `_setupPendingSyncListener()` methods
3. Remove `_skipSyncWait` field and constructor parameter
4. Remove `skipSyncWait: true` from all test instantiations

The existing behavior resumes (catch-up runs immediately without waiting for sync).
