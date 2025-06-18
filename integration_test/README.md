# Integration test for Matrix sync

For the Matrix integration tests, there's a [Docker Compose](https://docs.docker.com/compose/) setup
that starts the following services:

- [dendrite](https://github.com/matrix-org/dendrite): the Matrix homeserver we use in the test
- [postgres](https://hub.docker.com/_/postgres/): a PostgreSQL server used by dendrite
- [toxiproxy](https://github.com/Shopify/toxiproxy): a TCP proxy for simulating bad networks

Run the docker containers in a separate shell:

```shell
    $ cd docker
    $ docker-compose up
```

Run the test script:

````shell
    $ ./run_matrix_tests.sh
````

The test script will create two users and then run a Flutter integration test that instantiates two
separate clients with these users, and then initiates device verification, which should complete
successfully. Also see [PR #1695](https://github.com/matthiasn/lotti/pull/1695) for more details.

## Test Architecture

The Matrix integration tests use a modular architecture with the following components:

### Files

- **`matrix_service_test.dart`** - Main test file containing the test scenarios
- **`matrix/isolate_messages.dart`** - Message types for inter-isolate communication
- **`matrix/isolate_worker.dart`** - Worker logic that runs in separate isolates
- **`matrix/matrix_test_client.dart`** - High-level client API for test orchestration
- **`matrix/test_utils.dart`** - Utility functions for testing

### Key Features

1. **Isolate-based Architecture**: Each Matrix client runs in its own isolate with:
   - Independent GetIt instances for dependency injection
   - In-memory databases for test isolation
   - Separate SQLite connections (required for isolates)

2. **Enhanced Logging**: All debug output from isolates is captured and forwarded to the main test process, including:
   - Matrix SDK logs
   - Key verification steps and emoji codes
   - Custom debug messages

3. **Type-safe Communication**: Structured message types ensure clear communication between the test orchestrator and Matrix clients

### Test Flow

1. Two test clients (Alice and Bob) are created in separate isolates
2. Both clients authenticate with the Matrix server
3. Alice creates a room and invites Bob
4. Bob joins the room
5. Device verification is initiated and completed automatically
6. Both clients exchange test messages
7. The test verifies that all messages are received correctly


## Testing with simulated bad network

Set up the toxiproxy server running in the docker compose environment:

````shell
    $ ./setup_toxiproxy_docker.sh
````

Run the test script against `toxiproxy`;

````shell
    $ SLOW_NETWORK=true ./run_matrix_tests.sh
````

With the simulated bad network (with added 500 ms latency and throttled to 100 KB/s), the tests 
should still complete successfully, it'll just take a bit longer. For example on an M1 Max, it
typically takes around 1m 25s with the bad network simulation, and around 50s with non-degraded
network.
