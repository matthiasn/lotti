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


## Testing with simulated bad network

Set up the toxiproxy server running in the docker compose environment:

````shell
    $ ./setup_toxiproxy_docker.sh
````

Run the test script against `toxiproxy`;

````shell
    $ SLOW_NETWORK=true ./run_matrix_tests.sh
````

With the simulated bad network (with added 1000 ms latency and throttled to 100 KB/s), the tests 
should still complete successfully, it'll just take a bit longer. For example on an M1 Max, it
typically takes around 1m 25s with the bad network simulation, and around 50s with non-degraded
network.
