# Comprehensive Sync Integration Tests Implementation Plan

## Summary

This plan addresses the gap between the current shallow integration testing and the real-world scenarios that cause sync failures. The existing integration test (`integration_test/matrix_service_test.dart`) covers basic room creation, device verification, and message exchange, but does not adequately test edge cases around flaky networks, device availability, wake-from-standby scenarios, and failure recovery mechanisms.

## Current State Analysis

### Existing Integration Test Infrastructure

**Docker Compose setup** (`integration_test/docker/docker-compose.yml`):
- Dendrite Matrix homeserver (v0.13.8)
- PostgreSQL database
- Toxiproxy for network simulation

**Network simulation** (`integration_test/setup_toxiproxy_docker.sh`):
- Latency injection (200ms)
- Bandwidth throttling (300 KB/s)
- Proxy on port 18008 for degraded network tests

**GitHub Actions** (`.github/workflows/flutter-matrix-test.yml`):
- Two test jobs: normal network and degraded network
- Uses `SLOW_NETWORK` environment variable to toggle behavior

### Current Test Coverage

The existing `matrix_service_test.dart` tests:
- Room creation and joining
- Device verification via emoji comparison
- Message sending and receiving (100 messages normal, 10 degraded)
- Two-device sync (Alice and Bob)

### Gap Analysis

| Scenario | Currently Tested | Priority |
|----------|------------------|----------|
| Basic message sync | Yes | - |
| Device verification | Yes | - |
| Device offline during sync | No | High |
| Wake from standby catch-up | No | High |
| Network interruption mid-sync | No | High |
| Partial message delivery | No | High |
| Retry/backoff behavior | No | High |
| Circuit breaker activation | No | Medium |
| Concurrent multi-device edits | No | Medium |
| Attachment sync under network issues | No | Medium |
| Connection flapping | No | Medium |
| Room re-join after disconnect | No | Low |
| Large backlog catch-up | No | Low |

## Goals

1. Create integration tests that exercise real failure scenarios
2. Test the retry and circuit breaker mechanisms under realistic conditions
3. Validate catch-up behavior after device goes offline/standby
4. Test concurrent multi-device sync with conflicts
5. Verify attachment handling under network degradation
6. Provide confidence that sync recovery mechanisms work correctly

## Non-Goals

- Unit testing individual components (covered separately)
- UI/widget integration tests
- Performance benchmarking
- Testing Matrix SDK internals

## Architecture Overview

### Test Categories

```
integration_test/
├── docker/
│   ├── docker-compose.yml          # Existing
│   └── config/                      # Existing Dendrite config
├── matrix_service_test.dart        # Existing basic tests
├── sync_resilience_test.dart       # NEW: Network failure scenarios
├── sync_catchup_test.dart          # NEW: Offline/wake scenarios
├── sync_conflict_test.dart         # NEW: Multi-device conflicts
├── sync_attachment_test.dart       # NEW: Attachment handling
├── helpers/
│   ├── toxiproxy_controller.dart   # NEW: Programmatic proxy control
│   ├── test_matrix_service.dart    # NEW: Test harness utilities
│   └── sync_test_helpers.dart      # NEW: Common test utilities
├── setup_toxiproxy_docker.sh       # Existing
└── run_matrix_tests.sh             # Existing
```

### Toxiproxy Controller

The key enabler is programmatic control of Toxiproxy to simulate network conditions during test execution:

```dart
/// Programmatic interface to Toxiproxy for integration tests.
class ToxiproxyController {
  ToxiproxyController({this.baseUrl = 'http://localhost:8474'});
  final String baseUrl;

  /// Add latency to all requests (simulates slow network)
  Future<void> addLatency(String proxyName, Duration latency);

  /// Limit bandwidth (simulates congested network)
  Future<void> limitBandwidth(String proxyName, int kbPerSecond);

  /// Cut connection entirely (simulates offline)
  Future<void> disconnect(String proxyName);

  /// Restore normal connectivity
  Future<void> restore(String proxyName);

  /// Simulate intermittent connectivity (random disconnects)
  Future<void> enableConnectionFlapping(String proxyName, {
    Duration disconnectDuration = const Duration(seconds: 2),
    Duration connectedDuration = const Duration(seconds: 5),
  });

  /// Simulate packet loss
  Future<void> addPacketLoss(String proxyName, double percentage);

  /// Reset all toxics
  Future<void> resetAll(String proxyName);
}
```

## Detailed Test Scenarios

### 1. Network Resilience Tests (`sync_resilience_test.dart`)

#### 1.1 Network Interruption During Sync
```
Scenario: Device loses connectivity while receiving sync messages
Given: Alice and Bob are syncing
When: Alice sends 50 messages
And: Bob's network is cut after receiving 20 messages
And: Bob's network is restored after 10 seconds
Then: Bob should eventually receive all 50 messages
And: No duplicate messages should appear
And: Message order should be preserved
```

**Implementation details**:
- Use Toxiproxy to disconnect Bob mid-stream
- Verify retry tracker schedules retries
- Verify catch-up runs on reconnection
- Assert message count and ordering

#### 1.2 Connection Flapping
```
Scenario: Device experiences intermittent connectivity
Given: Alice and Bob are syncing
When: Alice sends 100 messages over 60 seconds
And: Bob's connection flaps every 5 seconds
Then: Bob should eventually receive all messages
And: Circuit breaker should activate if failures accumulate
And: Recovery should complete after stable connection
```

**Implementation details**:
- Use Toxiproxy's timeout toxic with short windows
- Monitor circuit breaker state via metrics
- Verify eventual consistency

#### 1.3 Extreme Latency
```
Scenario: Device operates under very high latency
Given: Alice and Bob are syncing
When: Latency is set to 5000ms
And: Alice sends 20 messages
Then: Bob should receive all messages (with longer timeout)
And: No timeouts should cause permanent data loss
```

#### 1.4 Bandwidth Starvation
```
Scenario: Device operates under severe bandwidth constraints
Given: Alice and Bob are syncing
When: Bandwidth is limited to 10 KB/s
And: Alice sends 10 messages with small attachments
Then: Bob should eventually receive all messages and attachments
And: Retries should handle partial transfers
```

### 2. Catch-Up Scenarios (`sync_catchup_test.dart`)

#### 2.1 Wake from Standby
```
Scenario: Device wakes after being idle
Given: Alice and Bob were syncing
And: Bob's last sync marker is at message 50
When: Alice sends messages 51-100 while Bob is "asleep"
And: Bob "wakes up" (simulated via time gap detection)
Then: Bob should run catch-up before advancing marker
And: Messages 51-100 should all be received
And: No messages should be skipped
```

**Implementation details**:
- Simulate standby by:
  1. Stopping Bob's pipeline
  2. Having Alice send messages
  3. Advancing virtual time past standby threshold
  4. Restarting Bob's pipeline
- Verify `_wakeCatchUpPending` flag behavior
- Assert all messages received in order

#### 2.2 Large Backlog After Extended Offline
```
Scenario: Device comes online after being offline for hours
Given: Alice has been sending messages for simulated "hours"
And: Bob was offline (1000+ messages in backlog)
When: Bob comes online
Then: Catch-up should use pagination/backfill
And: All messages should eventually sync
And: Progress should be observable via metrics
```

**Implementation details**:
- Use `CatchUpStrategy.collectEventsForCatchUp` with `maxLookback`
- Verify backfill pagination works correctly
- Monitor `catchupBatches` metric

#### 2.3 Marker Advancement Integrity
```
Scenario: Marker never skips events during catch-up
Given: Bob's marker is at event M
And: Events M+1 through M+100 exist
When: A newer event M+150 arrives via live stream
And: Catch-up is running
Then: Marker should advance through M+1...M+100 first
And: M+150 should not cause marker to skip ahead
And: Wake catch-up flag should block premature advancement
```

### 3. Multi-Device Conflict Tests (`sync_conflict_test.dart`)

#### 3.1 Concurrent Edits to Same Entry
```
Scenario: Two devices edit the same journal entry
Given: Alice and Bob both have entry E with vectorClock {alice: 1, bob: 1}
When: Alice updates E to {alice: 2, bob: 1}
And: Bob simultaneously updates E to {alice: 1, bob: 2}
And: Both devices sync
Then: One device should see a conflict created
And: Both versions should be preserved
And: Vector clocks should be correctly merged
```

**Implementation details**:
- Create entry on both devices with same ID
- Modify on both without syncing
- Trigger sync and verify conflict handling
- Check `conflictsCreated` metric

#### 3.2 Rapid Sequential Edits
```
Scenario: One device sends rapid updates before other catches up
Given: Alice has entry E at version 1
When: Alice sends updates v2, v3, v4, v5 in rapid succession
And: Bob starts with v1 and catches up
Then: Bob should end up at v5
And: No intermediate versions should be permanently lost
And: Vector clock should be consistent
```

#### 3.3 Three-Device Sync
```
Scenario: Three devices sync with varying connectivity
Given: Alice, Bob, and Carol share a sync room
When: Each device sends 20 messages
And: Network conditions vary per device
Then: All devices should eventually converge
And: Each device should have 60 messages
And: Message ordering should be consistent
```

### 4. Attachment Sync Tests (`sync_attachment_test.dart`)

#### 4.1 Attachment Arrives Before Descriptor
```
Scenario: Binary attachment is downloaded before text descriptor
Given: Alice sends a journal entry with an image
When: Bob's network is slow
And: Attachment binary arrives before the JSON descriptor
Then: Attachment should be indexed and waiting
And: When descriptor arrives, entry should complete
And: No data should be lost
```

**Implementation details**:
- Use `AttachmentIndex` to verify indexing
- Verify `DescriptorCatchUpManager` behavior
- Check `pendingJsonPaths` metric

#### 4.2 Attachment Download Failure with Retry
```
Scenario: Attachment download fails and retries
Given: Alice sends entry with large attachment
When: Bob's download is interrupted at 50%
Then: Retry should be scheduled with backoff
And: Eventually attachment should complete
And: Entry should be processed after attachment available
```

#### 4.3 Missing Attachment Blocks Entry Processing
```
Scenario: Entry processing waits for missing attachment
Given: Alice sends entry referencing attachment A
When: Bob receives descriptor but not attachment A
Then: Entry should be marked for retry
And: `FileSystemException` should trigger descriptor catch-up
And: Entry should process once attachment arrives
```

### 5. Component Integration Tests

#### 5.1 Retry Tracker Behavior Under Load
```
Scenario: Many events fail and are retried
Given: 100 events arrive with dependencies on missing attachments
When: Attachments arrive over time
Then: Retry tracker should schedule with exponential backoff
And: TTL pruning should prevent unbounded growth
And: All events should eventually process
```

#### 5.2 Circuit Breaker Activation and Recovery
```
Scenario: Circuit breaker opens after consecutive failures
Given: Network is completely broken
When: 50 consecutive processing failures occur
Then: Circuit breaker should open
And: Processing should pause for cooldown
And: After cooldown, processing should resume
And: Recovery should complete once network is stable
```

**Implementation details**:
- Verify `circuitOpens` metric
- Verify cooldown timer behavior
- Verify `_circuit.isOpen()` state

#### 5.3 Read Marker Debouncing
```
Scenario: Rapid marker updates are debounced
Given: 100 events process in quick succession
When: Each event would advance the marker
Then: Remote marker update should be debounced
And: Local marker should be persisted immediately
And: Final marker should be correct
```

## Implementation Steps

### Phase 1: Infrastructure (Days 1-2)

1. **Create ToxiproxyController**
   - HTTP client for Toxiproxy API
   - Methods for common network conditions
   - Helper for waiting until toxic takes effect

2. **Create test helper utilities**
   - `TestMatrixService` wrapper with test seams
   - `SyncTestHelpers` for common assertions
   - `waitForSync()` utility with timeout

3. **Update docker-compose.yml**
   - Ensure Toxiproxy API port (8474) is accessible
   - Add health checks for reliable startup

4. **Create test runner scripts**
   - New script for running specific test categories
   - Script for running all integration tests with proper teardown

### Phase 2: Network Resilience Tests (Days 3-5)

1. **Implement `sync_resilience_test.dart`**
   - Network interruption test
   - Connection flapping test
   - Extreme latency test
   - Bandwidth starvation test

2. **Add metrics assertions**
   - Create helpers to read and assert on `metricsSnapshot()`
   - Verify retry counts, failure counts, etc.

### Phase 3: Catch-Up Tests (Days 6-7)

1. **Implement `sync_catchup_test.dart`**
   - Wake from standby test
   - Large backlog test
   - Marker integrity test

2. **Add standby simulation**
   - Method to pause/resume pipeline
   - Time manipulation for standby detection

### Phase 4: Conflict Tests (Day 8)

1. **Implement `sync_conflict_test.dart`**
   - Concurrent edit test
   - Rapid sequential edit test
   - Three-device test

2. **Add vector clock assertions**
   - Helpers to parse and compare vector clocks
   - Conflict detection verification

### Phase 5: Attachment Tests (Day 9)

1. **Implement `sync_attachment_test.dart`**
   - Descriptor timing tests
   - Download failure tests
   - Missing attachment tests

2. **Add attachment assertions**
   - Verify file existence
   - Verify index state

### Phase 6: CI Integration (Day 10)

1. **Update GitHub Actions workflow**
   - Add new test categories as separate jobs
   - Configure appropriate timeouts
   - Add failure reporting

2. **Add test documentation**
   - Update test/README.md
   - Document how to run tests locally
   - Document Toxiproxy setup

## Test Environment Requirements

### Local Development

```bash
# Start test infrastructure
cd integration_test/docker
docker compose up -d

# Wait for services
./wait_for_services.sh

# Run specific test category
./run_resilience_tests.sh
./run_catchup_tests.sh
./run_conflict_tests.sh
./run_attachment_tests.sh

# Run all integration tests
./run_all_integration_tests.sh

# Cleanup
docker compose down -v
```

### CI Environment

The GitHub Actions workflow already handles:
- Docker Compose startup
- Toxiproxy setup
- Test execution

Add parallel jobs for new test categories:

```yaml
jobs:
  test_resilience:
    name: Network Resilience Tests
    # ...

  test_catchup:
    name: Catch-Up Tests
    # ...

  test_conflict:
    name: Conflict Tests
    # ...

  test_attachment:
    name: Attachment Tests
    # ...
```

## Risk Mitigation

### Test Flakiness

**Risk**: Integration tests may be flaky due to timing issues.

**Mitigation**:
- Use generous but bounded timeouts
- Implement robust `waitUntil` helpers with exponential backoff
- Add retries at the test runner level (max 2 retries)
- Log detailed diagnostics on failure

### Infrastructure Complexity

**Risk**: Docker/Toxiproxy setup may be unreliable.

**Mitigation**:
- Add health checks before test execution
- Implement graceful degradation (skip tests if infra unavailable)
- Document manual testing procedures as fallback

### Test Execution Time

**Risk**: Comprehensive tests may take too long.

**Mitigation**:
- Run tests in parallel where possible
- Use shorter timeouts for degraded network tests (adjust message counts)
- Implement test tagging for selective execution

## Success Criteria

1. **Coverage**: All identified gap scenarios have passing tests
2. **Reliability**: Tests pass consistently (>95% success rate)
3. **CI Integration**: All tests run in GitHub Actions on every push
4. **Documentation**: Test scenarios and setup fully documented
5. **Maintainability**: Test helpers reduce code duplication

## Acceptance Checklist

- [ ] ToxiproxyController implemented and tested
- [ ] All 4 test categories implemented
- [ ] Tests pass locally with fresh Docker setup
- [ ] Tests pass in GitHub Actions CI
- [ ] Test documentation in test/README.md updated
- [ ] CHANGELOG entry added
- [ ] No analyzer warnings in test files

## Future Enhancements

1. **Chaos Engineering Mode**: Random fault injection during regular test runs
2. **Performance Baseline**: Track sync times and establish regression detection
3. **Visual Test Dashboard**: Real-time view of test execution and metrics
4. **Automated Flakiness Detection**: Track and flag unreliable tests

## References

- Current integration test: `integration_test/matrix_service_test.dart`
- Sync pipeline: `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
- Retry logic: `lib/features/sync/matrix/pipeline/retry_and_circuit.dart`
- Toxiproxy documentation: https://github.com/Shopify/toxiproxy
- GitHub Actions workflow: `.github/workflows/flutter-matrix-test.yml`
