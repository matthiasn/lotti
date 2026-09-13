# Integration Tests

Integration tests verify end-to-end functionality that cannot be adequately tested with unit tests alone. They exercise real infrastructure components and multi-device interactions.

## Test Suites

### 1. Matrix Sync Tests (`matrix_service_test.dart`)

The suite exercises the real Dendrite homeserver, encrypted Matrix transport,
and per-device stores:

- Room creation, joining, SAS verification and bidirectional journal exchange
  (100 entries per direction, or 10 in slow-network mode).
- Image transfer to Bob and audio transfer to Alice, checking metadata and exact
  media bytes in the receiver's own directory.
- A withheld Megolm key followed by a complete Bob restart. The durable resume
  floor survives the restart; the late key must restore the image and clear it.
- A cold restart after Alice drains 1000 entries through the production outbox
  (250 in slow-network mode), exercising bundled transfer and persisted markers.
- Bob rejoining during a 600-entry outbox drain (150 in slow-network mode),
  overlapping startup catch-up with new bundles and checking deduplication.
- Peer repair of missing image and audio files after metadata has already
  converged, checking both requests and the restored bytes.

The ordinary Matrix suite includes explicit history/retry actions in some
convergence helpers. Use the resilience suite below to check recovery without
those test-driven actions.

### 2. Sync Resilience Tests (`sync_resilience_test.dart`)

Tests automatic sync recovery under adverse network conditions using Toxiproxy.
Alice and Bob have separate documents directories, Matrix stores, journal,
settings and sync databases. Fixtures go through the real outbox, which records
sender sequence history; both devices run the production backfill request and
response services. Device host IDs match their vector-clock keys. Receiver assertions poll database state only;
there are no calls to `forceRescan()` or `retryNow()` to make delivery succeed.
Each scenario compares exact entries (including text, timestamps and vector
clocks) and the JSON attachment bytes downloaded into Bob's directory against
Alice's originals. Neither device may find attachments in the global directory.
These real-network tests use bounded wall-clock waits under the real-I/O
exception in [the fake-time policy](../test/README.md#fake-time-policy).

#### Test Cases:

| Test | Scenario | What It Verifies |
|------|----------|------------------|
| Network interruption during sync | Alice sends messages, network is cut mid-way, then restored | Messages sent while offline eventually sync after reconnection |
| High latency | 2000ms added to Bob’s downstream traffic | Sync completes correctly despite slow responses |
| Bandwidth throttling | Network limited to 50 KB/s | Large, poorly compressible JSON attachments sync without data loss or corruption |
| Multiple network interruptions | Network toggled on/off multiple times during sync | Eventual consistency after repeated disruptions |

**Problems this catches:**
- Entries missed while the receiver is offline
- Recovery that depends on a manual rescan or retry
- Stalled delivery under latency or bandwidth limits
- Corrupted payloads and accidental sharing of device files

### 3. Home Integration Test (`home_integration_test.dart`)

Basic UI smoke test that creates a journal entry through the UI.

**Problems this catches:**
- App startup crashes
- Navigation failures
- Basic widget rendering issues

### 4. Store listing screenshots (`store_screenshots_test.dart`)

Captures the store listing screenshots — Play Store and App Store — on a real
Android device or emulator, or on iOS simulators. Not a verification suite and
excluded from `make integration_test` by its `store-screenshots` tag.

It boots the production app shell on the tutorial harness — in-memory databases, a
temp documents directory, the Intergalactic Penguin Logistics world seeded with its
habits, time records and notes (`seedHistory: true`), and no demo-mode banner — then
walks the task list, one task, habits, time analysis and the logbook. On Android
each screen is captured on the device and handed to the driver as a PNG; on an
iOS simulator the test announces each capture point on stdout and waits for the
script, which takes the whole screen (status bar included) with `simctl` and
acknowledges through a file in the app's sandbox. Configuration is passed as
dart-defines
(`LOTTI_STORE_THEME`, `LOTTI_MANUAL_LOCALE`) because the test runs on the device,
whose environment is not the host's.

Run it through the platform's script (see
[knowledge/conventions/screenshots.md](../knowledge/conventions/screenshots.md)).
The Android one also pins the emulator window to a ratio Play accepts; the iOS
one boots the simulators whose native sizes are the App Store's listing sizes
and dresses the status bar to Apple's 9:41 convention:

```bash
make store_screenshots_android                 # attached emulator-5554, dark + light
make store_screenshots_android LOTTI_AVD=Medium_Phone_API_36.0 LOTTI_STORE_THEMES=dark
make store_screenshots_ios                     # iPhone 17 Pro Max + iPad Pro 13-inch, dark + light
make store_screenshots_ios LOTTI_IOS_DEVICES="iPhone 17 Pro Max" LOTTI_STORE_THEMES=dark
```

Output lands in `build/store_screenshots/android/` and
`build/store_screenshots/ios/<device>/`. CI runs the same scripts — on an emulator
in `store-screenshots-android.yml`, on simulators in `store-screenshots-ios.yml`
(manual dispatch, or a pull request that touches the capture) — and uploads the
PNGs as workflow artifacts.

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
   MCP/IDE runners can supply the same names as process environment variables;
   Dart defines take precedence. All eight users are required, so a missing
   pair cannot silently reuse shared fallback accounts.

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

### Runtime budgets

Runtime depends on native build caching, host load and the injected network
fault. The resilience cases allow five minutes each, except repeated outages
(eight minutes); their final delivery observation allows three minutes.

The Matrix baseline, late-key restart and peer-repair cases allow 15 minutes.
The individual image/audio cases allow five minutes. Cold-restart and mid-drain
convergence allow 30 minutes, with 15-minute internal convergence waits.
These are failure bounds, not expected runtimes.

## Test Helpers

Shared test utilities live in `integration_test/helpers/`:

- **`sync_test_helpers.dart`** - Common utilities for Matrix sync tests:
  - `createSyncTestDevice()` - Real Matrix, queue, outbox and backfill wiring
  - `sendTestMessage()` - Persist a fixture, enqueue it and observe outbox completion
  - `createTestEntry()` - Create a test journal entry
  - `extractEmojiString()` - Extract emojis from verification flow
  - `waitUntil()` / `waitUntilAsync()` - Polling helpers with timeout
  - `TestConfig` - Test server configuration

- **`toxiproxy_controller.dart`** - Toxiproxy API client for network simulation:
  - `addLatency()` - Add network delay
  - `limitBandwidth()` - Throttle throughput
  - `disconnect()` / `reconnect()` - Toggle connectivity

## Scope

These suites exercise encrypted transport, persistence, attachment transfer
and selected recovery paths. Toxiproxy faults simulate network conditions;
they do not simulate operating-system sleep or prove every network failure
mode. The explicit assertions in each scenario define its guarantee.

## See Also

- [PR #1695](https://github.com/matthiasn/lotti/pull/1695) - Original Matrix sync test implementation
- `lib/features/sync/README.md` - Sync architecture documentation
- `docs/implementation_plans/2025-10-11-sync_simplification_plan.md` - Recent sync pipeline simplification
