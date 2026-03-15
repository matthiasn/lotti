# Plan: Long-Running Offline Convergence Integration Test

## Context

Recent sync reliability fixes (#2792, #2800) addressed a real production incident where ~1500 entries sent while a receiver was offline caused a retransmission storm instead of clean catch-up. The fixes changed catch-up to use timestamps as authoritative anchors, preserved full gaps in sequence logging, and expanded initial catch-up pagination. However, the integration tests only exercise 100 messages with both devices online simultaneously. We need a test that validates the exact offline convergence scenario that prompted these fixes.

## Scenario: Large Offline Convergence

```mermaid
flowchart TD
    A1["Alice: init + login + createRoom"] --> A2
    A2["Alice sends 1500 messages (Bob does NOT exist)"] --> A3
    A3["Alice finishes — room has 3000 events (1500 file + 1500 text)"] --> B1
    B1["Bob: create client + init + login"] --> B2
    B2["Alice invites Bob → Bob joins room"] --> B3
    B3["SAS emoji verification"] --> B4
    B4["Bob: forceRescan + retryNow polling loop"] --> B5
    B5{"bobDb count >= 1500?"} -->|No| B4
    B5 -->|Yes| C1
    C1["Assert: count == 1500, failures == 0, no circuit opens"]
```

**Why Option A (Bob doesn't exist during sending):** This is the purest simulation of offline — Bob has no stale markers, no local echo IDs, no partial sync state. It exactly mirrors the production incident where a device reconnects after a large offline burst.

## Implementation Steps

### Step 1: Extract shared helpers to reduce duplication

Extract from the existing test into file-level functions:

1. **`_performSasVerification()`** — the emoji verification dance (currently lines ~361-455)
   - Parameters: `alice`, `bob`, `timeout`
   - Returns when both have empty unverified device lists

2. **`_sendTestMessage()`** — promote from test-local closure to file-level function
   - Parameters: `index`, `device`, `deviceName`, `roomId`
   - Currently defined inline at ~line 457

### Step 2: Add the new test

Add a second `test()` inside the existing `MatrixService V2 Tests` group, after the current test. Key structure:

```
test('Offline convergence: Bob catches up 1500 messages sent while offline', () async {
  // Phase 1: Create Alice with fresh DB/client (unique names: AliceConv, alice_conv_db)
  // Phase 2: Alice init + login + createRoom
  // Phase 3: Alice sends 1500 messages (50 on SLOW_NETWORK)
  // Phase 4: Create Bob with fresh DB/client (BobConv, bob_conv_db)
  // Phase 5: Bob init + login
  // Phase 6: Alice invites Bob, Bob joins, SAS verification
  // Phase 7: Bob forceRescan + retryNow polling loop (2 min timeout, 200ms delay)
  // Phase 8: Assertions
});
```

### Step 3: Assertions

| Assertion | Why |
|---|---|
| `bobDb.getJournalCount() == n` | All entries converged |
| `metrics.failures == 0` | No processing failures |
| `metrics.circuitOpens == 0` | Circuit breaker never tripped |

Metrics are logged via `debugPrint` for diagnostic visibility regardless.

## Files to Modify

- `integration_test/matrix_service_test.dart` — extract helpers + add new test

## Reuse

- `_createMatrixService()` — existing file-level helper (line 42)
- `createMatrixClient()` — from `lib/features/sync/matrix/client.dart`
- `waitUntilAsync()`, `waitSeconds()` — from `test/utils/utils.dart`
- `SyncMetrics.fromMap()` — from `lib/features/sync/matrix/pipeline/sync_metrics.dart`
- Shared infra from `setUpAll`: `sharedLoggingService`, `sharedUserActivityService`, `sharedDocumentsDirectory`, `sharedAiConfigRepository`, `mockUpdateNotifications`, `secureStorageMock`

## Sizing

- **1500 messages** normal / 50 degraded
- Catch-up should converge in seconds, not minutes — the catch-up pagination fix (#2800) ensures all events are fetched in the initial timeline expansion
- **2-minute convergence timeout** (generous buffer; actual convergence expected within 10-30 seconds)
- 200ms delay between retry nudges (same as existing test)

## Follow-Up Scenarios (not in this PR)

1. **Bidirectional offline**: Both send while other is offline, then both come online
2. **Partial offline with reconnect**: Bob gets some, goes offline, Alice sends more, Bob reconnects
3. **Concurrent send during catch-up**: Alice keeps sending while Bob catches up
4. **Three-device convergence**: Alice, Bob, Carol

## Verification

1. Run `bash integration_test/run_matrix_tests.sh` locally — both tests must pass
2. Check Bob's metrics output shows `failures: 0`, `circuitOpens: 0`, reasonable `catchupBatches`
3. Analyzer must be green: `dart-mcp.analyze_files`
4. Formatter: `dart-mcp.dart_format`
