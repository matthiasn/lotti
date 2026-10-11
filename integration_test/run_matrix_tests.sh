#!/bin/bash
set -euo pipefail

# Go to directory of script
cd "$(dirname "$0")"

# Create user name
uuid1=$(uuidgen)
uuid2=$(uuidgen)
TEST_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid1")"
TEST_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid2")"
# The crossing verification test needs two devices nobody has verified yet.
uuid3=$(uuidgen)
uuid4=$(uuidgen)
CROSSING_USER1="$(tr '[:upper:]' '[:lower:]' <<< "$uuid3")"
CROSSING_USER2="$(tr '[:upper:]' '[:lower:]' <<< "$uuid4")"

cd docker
docker compose up --detach --wait --wait-timeout 60
docker compose exec -T dendrite create-account -config dendrite.yaml -username "$TEST_USER1" -admin -password "?Secret123@"
docker compose exec -T dendrite create-account -config dendrite.yaml -username "$TEST_USER2" -admin -password "?Secret123@"
docker compose exec -T dendrite create-account -config dendrite.yaml -username "$CROSSING_USER1" -admin -password "?Secret123@"
docker compose exec -T dendrite create-account -config dendrite.yaml -username "$CROSSING_USER2" -admin -password "?Secret123@"
cd - > /dev/null
cd ..

flutter test integration_test/matrix_service_test.dart \
--dart-define=TEST_USER1="@$TEST_USER1:localhost" \
--dart-define=TEST_USER2="@$TEST_USER2:localhost" \
--dart-define=SLOW_NETWORK="$SLOW_NETWORK" "$@"

flutter test integration_test/verification_crossing_test.dart \
--dart-define=TEST_USER1="@$CROSSING_USER1:localhost" \
--dart-define=TEST_USER2="@$CROSSING_USER2:localhost" \
--dart-define=SLOW_NETWORK="$SLOW_NETWORK" "$@"
