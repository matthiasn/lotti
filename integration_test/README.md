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

Install [comcast](https://github.com/tylertreat/Comcast), e.g.:

````shell
    $ GOBIN=~/bin/ go install github.com/tylertreat/comcast@latest
````

 To be continued.
