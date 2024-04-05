# Integration test for Matrix sync

Clone [dendrite](https://github.com/matrix-org/dendrite) into a sibling directory,
e.g. `~/github/dendrite`. Build it, we need the executable in order to create users for the test.

Run dendrite in a separate shell:

```shell
    $ cd integration_test/dendrite/
    $ docker-compose up
```

Run the test script:

````shell
    $ ./integration_test/run_matrix_tests.sh
````

The test script will create two users and then run a Flutter integration test that instantiates two
separate clients with these users, and then initiates device verification, which should complete
successfully. Also see [PR #1695](https://github.com/matthiasn/lotti/pull/1695) for more details.


## Testing with simulated bad network

Install [toxiproxy](https://github.com/Shopify/toxiproxy) and run server:

````shell
    $ toxiproxy-server
````

In separate shell:

````shell
    $ toxiproxy-cli create -l localhost:18008 -u localhost:8008 dendrite-proxy
    $ toxiproxy-cli toxic add -t latency -a latency=1000 dendrite-proxy
    $ toxiproxy-cli toxic add -t bandwidth -a rate=100 dendrite-proxy
````

Run the test script against `toxiproxy`;

````shell
    $ SLOW_NETWORK=true ./integration_test/run_matrix_tests.sh
````
