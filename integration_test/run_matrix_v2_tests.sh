#!/bin/bash
# Go to directory of script
cd "$(dirname "$0")" || exit

# Create user name
uuid1=$(uuidgen)
uuid2=$(uuidgen)
TEST_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid1")"
TEST_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid2")"

cd docker || exit
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER1" -admin -password "?Secret123@"
docker compose exec dendrite create-account -config dendrite.yaml -username "$TEST_USER2" -admin -password "?Secret123@"
cd - > /dev/null || exit
cd ..

flutter test integration_test/matrix_service_v2_test.dart \
--dart-define=TEST_USER1="@$TEST_USER1:localhost" \
--dart-define=TEST_USER2="@$TEST_USER2:localhost" \
--dart-define=SLOW_NETWORK="$SLOW_NETWORK" "$@"

