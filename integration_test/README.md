# Integration Tests

Integration tests verify end-to-end functionality that cannot be adequately tested with unit tests alone. They exercise real infrastructure components and multi-device interactions.

## Test Suites

### 1. Matrix Sync Tests (`matrix_service_test.dart`)

**What it tests:**
- Two-device sync flow with real Matrix homeserver (Dendrite)
- Room creation and encrypted room join
- Device discovery and SAS emoji verification
- Bidirectional message exchange (100 messages each direction, or 10 in slow network mode)
- Self-event suppression (devices don't re-apply their own messages)
- Message persistence to local database

**Problems this catches:**
- Regressions in Matrix SDK integration
- Encryption/decryption failures
- Device verification protocol issues
- Message ordering and deduplication bugs
- Database persistence failures during sync
- Race conditions in concurrent message processing

### 2. Sync Resilience Tests (`sync_resilience_test.dart`)

Tests sync behavior under adverse network conditions using Toxiproxy.

#### Test Cases:

| Test | Scenario | What It Verifies |
|------|----------|------------------|
| Network interruption during sync | Alice sends messages, network is cut mid-way, then restored | Messages sent while offline eventually sync after reconnection |
| High latency | 500ms latency added to all network calls | Sync completes correctly despite slow responses |
| Bandwidth throttling | Network limited to 10 KB/s | Large payloads sync without data loss or corruption |
| Multiple network interruptions | Network toggled on/off multiple times during sync | Eventual consistency after repeated disruptions |

**Problems this catches:**
- Sync failures after device wake from sleep/standby
- Message loss during network transitions (WiFi ↔ cellular)
- Retry logic failures
- Catch-up mechanism bugs after extended offline periods
- Circuit breaker misbehavior

### 3. Home Integration Test (`home_integration_test.dart`)

Basic UI smoke test that creates a journal entry through the UI.

**Problems this catches:**
- App startup crashes
- Navigation failures
- Basic widget rendering issues

## Infrastructure

### Docker Services

The Matrix tests require a Docker Compose environment with:

| Service | Purpose |
|---------|---------|
| [Dendrite](https://github.com/matrix-org/dendrite) | Matrix homeserver for testing |
| [PostgreSQL](https://hub.docker.com/_/postgres/) | Database backend for Dendrite |
| [Toxiproxy](https://github.com/Shopify/toxiproxy) | TCP proxy for simulating network conditions |

### Running the Tests

1. **Start the Docker environment:**
   ```shell
   cd docker
   docker-compose up
   ```

2. **Run the Matrix sync test:**
   ```shell
   ./run_matrix_tests.sh
   ```

3. **Run with simulated bad network:**
   ```shell
   # Set up Toxiproxy
   ./setup_toxiproxy_docker.sh

   # Run against degraded network (500ms latency, 100 KB/s)
   SLOW_NETWORK=true ./run_matrix_tests.sh
   ```

### Test Users

The test script creates dedicated test users on the Dendrite server. Each resilience test uses a separate user pair to avoid device accumulation across test runs:

- `TEST_USER1` / `TEST_USER2` - Matrix sync test
- `TEST_USER3` through `TEST_USER8` - Resilience tests (one pair per test)

### Performance Expectations

| Mode | Matrix Sync Test | Resilience Tests |
|------|------------------|------------------|
| Normal network | ~50s | ~2-3 min per test |
| Degraded network | ~1m 25s | ~5-8 min per test |

## Test Helpers

Shared test utilities live in `integration_test/helpers/`:

- **`sync_test_helpers.dart`** - Common utilities for Matrix sync tests:
  - `createMatrixService()` - Factory for test MatrixService instances
  - `sendTestMessage()` - Send a test journal entry via Matrix
  - `createTestEntry()` - Create a test journal entry
  - `extractEmojiString()` - Extract emojis from verification flow
  - `waitUntil()` / `waitUntilAsync()` - Polling helpers with timeout
  - `TestConfig` - Test server configuration

- **`toxiproxy_controller.dart`** - Toxiproxy API client for network simulation:
  - `addLatency()` - Add network delay
  - `limitBandwidth()` - Throttle throughput
  - `disconnect()` / `reconnect()` - Toggle connectivity

## Confidence Gained

These integration tests provide confidence that:

1. **Multi-device sync works end-to-end** - Real Matrix protocol, real encryption, real database writes
2. **Sync is resilient to real-world network conditions** - Handles the messy reality of mobile networks
3. **Device verification is functional** - The security-critical emoji SAS flow works correctly
4. **Recovery mechanisms work** - Catch-up, retry, and circuit breaker logic behaves correctly
5. **No message loss under stress** - All messages eventually sync, even under adverse conditions

## See Also

- [PR #1695](https://github.com/matthiasn/lotti/pull/1695) - Original Matrix sync test implementation
- `lib/features/sync/README.md` - Sync architecture documentation
- `docs/sync_simplification_plan.md` - Recent sync pipeline simplification
