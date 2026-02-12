#!/bin/bash
# Go to directory of script
cd "$(dirname "$0")" || exit

uuid1=$(uuidgen)
uuid2=$(uuidgen)
TEST_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid1")"
TEST_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid2")"
TEST_PASSWORD="${TEST_PASSWORD:-?Secret123@}"

cd docker || exit
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER1" -admin -password "$TEST_PASSWORD"
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER2" -admin -password "$TEST_PASSWORD"
cd - > /dev/null || exit

cd ..

flutter test -d macos integration_test/matrix_actor_isolate_network_test.dart \
--dart-define=TEST_USER1="@$TEST_USER1:localhost" \
--dart-define=TEST_USER2="@$TEST_USER2:localhost" \
--dart-define=TEST_PASSWORD="$TEST_PASSWORD" "$@"
