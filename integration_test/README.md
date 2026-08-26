# Integration Tests

Integration tests verify end-to-end functionality that cannot be adequately tested with unit tests alone. They exercise real infrastructure components and multi-device interactions.

## Test Suites

### 1. Matrix Sync Tests (`matrix_service_test.dart`)

This suite contains four tests:

**`Create room & join (sync v2)`** — the baseline two-device flow:
- Two-device sync flow with real Matrix homeserver (Dendrite)
- Room creation and encrypted room join
- Device discovery and SAS emoji verification
- Bidirectional message exchange (100 messages each direction, or 10 in slow network mode)
- Self-event suppression (devices don't re-apply their own messages)
- Message persistence to local database

**`Late Megolm key survives Bob restart and clears the durable floor`** —
Alice deliberately withholds a Megolm session from Bob, sends through the
production outbox, and verifies that Bob records a durable resume floor without
applying ciphertext. Bob is fully restarted on the same Matrix SDK, journal,
settings, and sync databases, and a startup bridge proves the unresolved floor
is retained. Alice then sends the real encrypted room key after Bob becomes
eligible again. The restarted production queue must recover the event exactly
once through its one-shot bootstrap re-decryption and clear the floor.

**`Large-volume convergence: Bob catches up 1000 messages after cold restart`**
(250 in slow network mode, 30-minute test timeout with a 15-minute internal
convergence-wait budget) — Alice sends a large burst while Bob's
client is closed; Bob then reopens with a fresh client/pipeline but the same
persisted Matrix SDK database, journal, settings, and queue database. The
surviving queue marker makes this a production-faithful reconnect rather than
an artificial fresh-client bootstrap.

**`Mid-burst rejoin`** — Alice pauses 40% into a 600-message burst while Bob comes online
(150 in slow network mode, 30-minute test timeout with a 15-minute internal
convergence-wait budget). Once Bob's startup bridge is in flight, Alice resumes the burst. This
deterministically overlaps bridge pagination with new sends. After the startup bridge reaches the
server's then-current end, the test runs the production full-history sweep to collect messages sent
later without relying on a second forward walk. The `event_id UNIQUE` constraint on
`inbound_event_queue` deduplicates events visited by both passes near the bridge boundary.

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
| High latency | 2000ms latency added to all network calls | Sync completes correctly despite slow responses |
| Bandwidth throttling | Network limited to 50 KB/s | Large payloads sync without data loss or corruption |
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

### 4. Store listing screenshots (`store_screenshots_test.dart`)

Captures the Play Store listing screenshots on a real Android device or emulator.
Not a verification suite and excluded from `make integration_test` by its
`store-screenshots` tag.

It boots the production app shell on the tutorial harness — in-memory databases, a
temp documents directory, the Intergalactic Penguin Logistics world seeded with its
habits, time records and notes (`seedHistory: true`), and no demo-mode banner — then
walks the task list, one task, habits, time analysis and the logbook, handing each
screen to the driver as a PNG. Configuration is passed as dart-defines
(`LOTTI_STORE_THEME`, `LOTTI_MANUAL_LOCALE`) because the test runs on the device,
whose environment is not the host's.

Run it through the script, which also pins the emulator window to a ratio Play
accepts (see [knowledge/conventions/screenshots.md](../knowledge/conventions/screenshots.md)):

```bash
make store_screenshots_android                 # attached emulator-5554, dark + light
make store_screenshots_android LOTTI_AVD=Medium_Phone_API_36.0 LOTTI_STORE_THEMES=dark
```

Output lands in `build/store_screenshots/android/`. CI runs the same script on an
emulator in `store-screenshots-android.yml` (manual dispatch, or a pull request that
touches the capture) and uploads the PNGs as a workflow artifact.

### 5. Manual Screenshots (`manual_screenshots_test.dart`)

A legacy full-shell screenshot-capture tool rather than a CI verification suite. It runs the full app shell
with an in-memory harness and a single `testWidgets` case (`captures AI provider onboarding states
in the full app shell`) that drives the AI provider onboarding UI and writes PNG screenshots via
`manual_screenshot_utils.dart` to the directory named by the `LOTTI_SCREENSHOT_DIR` dart-define /
env var.

The automated manual site catalog uses the faster opt-in widget harnesses
registered in `docs-site/metadata/screenshot-cases.json`; run it with
`make manual_screenshots`. Both paths write generated media to the sibling
`lotti-docs` checkout. See `test/README.md` for the four-variant contract.

## Infrastructure

### Docker Services

The Matrix tests require a Docker Compose environment with:

| Service | Purpose |
|---------|---------|
| [Dendrite](https://github.com/matrix-org/dendrite) | Matrix homeserver for testing |
| [PostgreSQL](https://hub.docker.com/_/postgres/) | Database backend for Dendrite |
| [Toxiproxy](https://github.com/Shopify/toxiproxy) | TCP proxy for simulating network conditions |

### Running the Tests

All run scripts live in `integration_test/`. Most (`run_matrix_tests.sh`,
`setup_toxiproxy_docker.sh`) resolve their own location and
`cd` into `integration_test/docker` as needed; `run_resilience_tests.sh` instead references the
compose file by path (`docker compose -f docker/docker-compose.yml`) and runs the test from the
project root.

1. **Start the Docker environment:**
   ```shell
   cd integration_test/docker
   docker compose up
   ```

2. **Run the Matrix sync test:**
   ```shell
   ./run_matrix_tests.sh
   ```

3. **Run the resilience tests:**
   ```shell
   ./run_resilience_tests.sh
   ```
   This script creates four temporary user pairs in docker and runs
   `sync_resilience_test.dart` with `TEST_USER1` through `TEST_USER8`.

4. **Run with simulated bad network:**
   ```shell
   # Set up Toxiproxy (applies 200ms latency and 300 KB/s bandwidth)
   ./setup_toxiproxy_docker.sh

   # Run against the degraded network
   SLOW_NETWORK=true ./run_matrix_tests.sh
   ```

### Test Users

The run scripts create dedicated test users on the Dendrite server. Each resilience test uses a separate user pair to avoid device accumulation across test runs:

- `run_resilience_tests.sh` provisions four pairs as `TEST_USER1` through `TEST_USER8`
  (one pair per resilience test, the first test using `TEST_USER1`/`TEST_USER2`).
- `run_matrix_tests.sh` independently provisions its own freshly-created users and passes
  them as `TEST_USER1`/`TEST_USER2` for the standalone Matrix sync test.

### Performance Expectations

The individual figures below describe the baseline `Create room & join` test
(which itself carries a 15-minute timeout). The complete degraded Matrix suite,
including its Linux rebuild, is expected to stay below five minutes; the
production-faithful persisted-marker run measured 4m40s locally. The
`Large-volume convergence` (1000-message cold restart) and `Mid-burst rejoin`
(600-message) tests each retain a 30-minute test timeout with a 15-minute
internal per-wait convergence budget so a real regression still has room to
produce useful diagnostics.

| Mode | Matrix Sync Test (baseline) | Resilience Tests |
|------|-----------------------------|------------------|
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
- `docs/implementation_plans/2025-10-11-sync_simplification_plan.md` - Recent sync pipeline simplification
